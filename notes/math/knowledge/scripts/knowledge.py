#!/usr/bin/env python3
"""Build and query the repository-owned QLNotes knowledge graph."""

from __future__ import annotations

import argparse
import collections
import dataclasses
import glob
import hashlib
import json
import re
import shutil
import sqlite3
import subprocess
import sys
from pathlib import Path
from typing import Any, Iterable
from urllib.parse import quote


GRAPH_SCHEMA = "qlkg-v1"
SOURCE_SCHEMA = "qlkg-sources-v1"
DIAGNOSTIC_SCHEMA = "qlkg-diagnostics-v1"
PANDOC_READER = (
    "markdown+yaml_metadata_block+tex_math_dollars+fenced_divs+"
    "pipe_tables+link_attributes"
)
STATEMENT_KINDS = {
    "definition",
    "theorem",
    "lemma",
    "corollary",
    "proposition",
    "example",
}
ATTACHED_SUPPORT_KINDS = {"proof", "solution"}
STABLE_ID_RE = re.compile(r"^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$")
GENERIC_CONCEPT_RE = re.compile(
    r"^(?:definition|theorem|lemma|corollary|proposition|example)-\d+$"
)


class KnowledgeError(RuntimeError):
    """Raised when the graph cannot be built or queried."""


@dataclasses.dataclass(frozen=True)
class SourceSpec:
    id: str
    authority: Path
    markdown: tuple[Path, ...]


@dataclasses.dataclass
class Diagnostic:
    code: str
    message: str
    source: str | None = None
    node: str | None = None

    def as_dict(self) -> dict[str, str]:
        result = {"code": self.code, "message": self.message}
        if self.source is not None:
            result["source"] = self.source
        if self.node is not None:
            result["node"] = self.node
        return result


def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def pretty_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n"


def sha256_bytes(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def file_sha256(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def repository_path(repo_root: Path, value: str, *, field: str) -> Path:
    candidate = Path(value)
    if candidate.is_absolute():
        raise KnowledgeError(f"{field} must be repository-relative: {value}")
    resolved = (repo_root / candidate).resolve()
    if not resolved.is_relative_to(repo_root.resolve()):
        raise KnowledgeError(f"{field} escapes the repository: {value}")
    return resolved


def relative_path(repo_root: Path, path: Path) -> str:
    return path.resolve().relative_to(repo_root.resolve()).as_posix()


def load_sources(repo_root: Path, config_path: Path) -> list[SourceSpec]:
    try:
        raw = json.loads(config_path.read_text(encoding="utf-8"))
    except FileNotFoundError as error:
        raise KnowledgeError(f"missing source registry: {config_path}") from error
    except json.JSONDecodeError as error:
        raise KnowledgeError(f"invalid source registry JSON: {error}") from error

    if raw.get("schema") != SOURCE_SCHEMA:
        raise KnowledgeError(
            f"source registry schema must be {SOURCE_SCHEMA!r}, got {raw.get('schema')!r}"
        )
    entries = raw.get("sources")
    if not isinstance(entries, list) or not entries:
        raise KnowledgeError("source registry must contain a non-empty `sources` list")

    sources: list[SourceSpec] = []
    ids: set[str] = set()
    markdown_paths: set[Path] = set()
    for index, entry in enumerate(entries):
        if not isinstance(entry, dict):
            raise KnowledgeError(f"sources[{index}] must be an object")
        source_id = entry.get("id")
        authority = entry.get("authority")
        markdown = entry.get("markdown")
        if not all(isinstance(value, str) and value for value in (source_id, authority)):
            raise KnowledgeError(
                f"sources[{index}] requires non-empty id and authority strings"
            )
        markdown_values = markdown if isinstance(markdown, list) else [markdown]
        if not markdown_values or not all(
            isinstance(value, str) and value for value in markdown_values
        ):
            raise KnowledgeError(
                f"sources[{index}].markdown must be a non-empty string or string list"
            )
        if source_id in ids:
            raise KnowledgeError(f"duplicate source id: {source_id}")
        authority_path = repository_path(repo_root, authority, field="authority")
        resolved_markdown: list[Path] = []
        for value in markdown_values:
            if glob.has_magic(value):
                pattern = Path(value)
                if pattern.is_absolute() or ".." in pattern.parts:
                    raise KnowledgeError(
                        f"markdown glob must stay inside the repository: {value}"
                    )
                matches = sorted(
                    path.resolve()
                    for path in repo_root.glob(value)
                    if path.is_file()
                )
                if not matches:
                    raise KnowledgeError(f"markdown glob matched no files: {value}")
                resolved_markdown.extend(matches)
            else:
                resolved_markdown.append(
                    repository_path(repo_root, value, field="markdown")
                )
        resolved_markdown = list(dict.fromkeys(resolved_markdown))
        for markdown_path in resolved_markdown:
            if markdown_path in markdown_paths:
                raise KnowledgeError(
                    f"duplicate Markdown source: {relative_path(repo_root, markdown_path)}"
                )
            markdown_paths.add(markdown_path)
        ids.add(source_id)
        sources.append(SourceSpec(source_id, authority_path, tuple(resolved_markdown)))
    return sorted(sources, key=lambda source: source.id)


def run_pandoc(path: Path) -> dict[str, Any]:
    if shutil.which("pandoc") is None:
        raise KnowledgeError("pandoc is required to compile the knowledge graph")
    result = subprocess.run(
        ["pandoc", path.name, "--from", PANDOC_READER, "--to", "json"],
        cwd=path.parent,
        check=False,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise KnowledgeError(f"pandoc could not parse {path}:\n{detail}")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as error:
        raise KnowledgeError(f"pandoc returned invalid JSON for {path}: {error}") from error


def normalize_text(value: str) -> str:
    value = re.sub(r"[ \t\r\f\v]+", " ", value)
    value = re.sub(r" *\n *", "\n", value)
    value = re.sub(r"\n{3,}", "\n\n", value)
    return value.strip()


def inline_text(value: Any) -> str:
    if isinstance(value, list):
        return "".join(inline_text(item) for item in value)
    if not isinstance(value, dict):
        return ""
    kind = value.get("t")
    content = value.get("c")
    if kind == "Str":
        return str(content)
    if kind in {"Space", "SoftBreak", "LineBreak"}:
        return " "
    if kind == "Math" and isinstance(content, list) and len(content) == 2:
        delimiter = "$$" if content[0].get("t") == "DisplayMath" else "$"
        return f"{delimiter}{content[1]}{delimiter}"
    if kind in {"Code", "RawInline"} and isinstance(content, list) and content:
        return str(content[-1])
    if kind in {"Link", "Image"} and isinstance(content, list) and len(content) >= 2:
        return inline_text(content[1])
    if kind == "Cite" and isinstance(content, list) and len(content) == 2:
        return inline_text(content[1])
    if kind == "Quoted" and isinstance(content, list) and len(content) == 2:
        return inline_text(content[1])
    if kind == "Span" and isinstance(content, list) and len(content) == 2:
        return inline_text(content[1])
    if kind in {"Emph", "Underline", "Strong", "Strikeout", "SmallCaps", "Superscript", "Subscript"}:
        return inline_text(content)
    if kind == "Note":
        return block_text(content)
    return inline_text(content)


def block_text(value: Any) -> str:
    if isinstance(value, list):
        return normalize_text("\n".join(filter(None, (block_text(item) for item in value))))
    if not isinstance(value, dict):
        return ""
    kind = value.get("t")
    content = value.get("c")
    if kind in {"Plain", "Para"}:
        return normalize_text(inline_text(content))
    if kind == "Header" and isinstance(content, list) and len(content) == 3:
        return normalize_text(inline_text(content[2]))
    if kind in {"CodeBlock", "RawBlock"} and isinstance(content, list) and content:
        return normalize_text(str(content[-1]))
    if kind == "Div" and isinstance(content, list) and len(content) == 2:
        return block_text(content[1])
    if kind == "Figure" and isinstance(content, list):
        return block_text(content[1:])
    if kind == "BlockQuote":
        return block_text(content)
    if kind == "BulletList" and isinstance(content, list):
        return normalize_text("\n".join(f"- {block_text(item)}" for item in content))
    if kind == "OrderedList" and isinstance(content, list) and len(content) == 2:
        return normalize_text(
            "\n".join(f"{index}. {block_text(item)}" for index, item in enumerate(content[1], 1))
        )
    if kind == "DefinitionList" and isinstance(content, list):
        parts: list[str] = []
        for term, definitions in content:
            parts.append(inline_text(term))
            parts.extend(block_text(definition) for definition in definitions)
        return normalize_text("\n".join(parts))
    if kind == "HorizontalRule":
        return ""
    if kind == "Table":
        return normalize_text(inline_text(content))
    return normalize_text(inline_text(content))


def meta_value(value: Any) -> Any:
    if not isinstance(value, dict):
        return value
    kind = value.get("t")
    content = value.get("c")
    if kind == "MetaString":
        return content
    if kind == "MetaBool":
        return bool(content)
    if kind == "MetaInlines":
        return normalize_text(inline_text(content))
    if kind == "MetaBlocks":
        return block_text(content)
    if kind == "MetaList":
        return [meta_value(item) for item in content]
    if kind == "MetaMap":
        return {key: meta_value(item) for key, item in content.items()}
    return content


def metadata(document: dict[str, Any]) -> dict[str, Any]:
    return {key: meta_value(value) for key, value in document.get("meta", {}).items()}


def attributes(value: Any) -> tuple[str, list[str], dict[str, str]]:
    if not isinstance(value, list) or len(value) != 3:
        return "", [], {}
    identifier = str(value[0])
    classes = [str(item) for item in value[1]]
    attrs = {str(key): str(item) for key, item in value[2]}
    return identifier, classes, attrs


def split_csv(value: str | None) -> list[str]:
    if not value:
        return []
    return list(dict.fromkeys(part.strip() for part in value.split(",") if part.strip()))


def concept_id(value: str) -> str:
    return f"concept:{quote(value, safe='-._~')}"


def source_node_id(source_id: str) -> str:
    return f"document:{source_id}"


def statement_node_id(source_id: str, local_id: str) -> str:
    return f"statement:{source_id}#{quote(local_id, safe='-._~')}"


def section_node_id(source_id: str, local_id: str) -> str:
    return f"section:{source_id}#{quote(local_id, safe='-._~')}"


def figure_node_id(source_id: str, local_id: str) -> str:
    return f"figure:{source_id}#{quote(local_id, safe='-._~')}"


def semantic_div(value: Any) -> tuple[str, str, dict[str, str], list[Any]] | None:
    if not isinstance(value, dict) or value.get("t") != "Div":
        return None
    content = value.get("c")
    if not isinstance(content, list) or len(content) != 2:
        return None
    identifier, classes, attrs = attributes(content[0])
    kind = next((name for name in classes if name in STATEMENT_KINDS), "")
    if not identifier or not kind:
        return None
    return identifier, kind, attrs, content[1]


def find_semantic_divs(value: Any) -> Iterable[tuple[str, str, dict[str, str], list[Any]]]:
    parsed = semantic_div(value)
    if parsed is not None:
        yield parsed
        # A semantic statement may contain another authored statement (for
        # example a lemma inside a worked example). Keep both stable nodes.
        yield from find_semantic_divs(parsed[3])
        return
    if isinstance(value, dict):
        for child in value.values():
            yield from find_semantic_divs(child)
    elif isinstance(value, list):
        for child in value:
            yield from find_semantic_divs(child)


def unidentified_statement_count(value: Any) -> int:
    count = 0
    if isinstance(value, dict):
        if value.get("t") == "Div":
            content = value.get("c")
            if isinstance(content, list) and len(content) == 2:
                identifier, classes, _ = attributes(content[0])
                if not identifier and any(name in STATEMENT_KINDS for name in classes):
                    count += 1
        count += sum(unidentified_statement_count(child) for child in value.values())
    elif isinstance(value, list):
        count += sum(unidentified_statement_count(child) for child in value)
    return count


def find_figures(value: Any) -> Iterable[tuple[str, str, list[Any]]]:
    if isinstance(value, dict):
        if value.get("t") == "Figure":
            content = value.get("c")
            if isinstance(content, list) and len(content) == 3:
                identifier, _, _ = attributes(content[0])
                if identifier:
                    caption = block_text(content[1])
                    yield identifier, caption, content[2]
                    return
        for child in value.values():
            yield from find_figures(child)
    elif isinstance(value, list):
        for child in value:
            yield from find_figures(child)


def references(value: Any) -> tuple[set[str], set[str]]:
    citations: set[str] = set()
    links: set[str] = set()

    def visit(item: Any) -> None:
        if isinstance(item, dict):
            kind = item.get("t")
            content = item.get("c")
            if kind == "Cite" and isinstance(content, list) and content:
                for citation in content[0]:
                    citation_id = citation.get("citationId")
                    if citation_id:
                        citations.add(str(citation_id))
            elif kind == "Link" and isinstance(content, list) and len(content) == 3:
                target = content[2][0]
                if isinstance(target, str) and target.startswith("#") and len(target) > 1:
                    links.add(target[1:])
            for child in item.values():
                visit(child)
        elif isinstance(item, list):
            for child in item:
                visit(child)

    visit(value)
    return citations, links


def statement_label(kind: str, content: list[Any], fallback: str) -> str:
    for block in content:
        if isinstance(block, dict) and block.get("t") in {"Para", "Plain"}:
            label = normalize_text(inline_text(block.get("c")))
            if label:
                prefix = re.compile(rf"^{re.escape(kind)}\s*:\s*", re.IGNORECASE)
                cleaned = prefix.sub("", label).strip()
                return cleaned or label
    return fallback


class GraphCompiler:
    def __init__(self, repo_root: Path) -> None:
        self.repo_root = repo_root.resolve()
        self.nodes: dict[str, dict[str, Any]] = {}
        self.edges: dict[tuple[str, str, str, str, str], dict[str, str]] = {}
        self.errors: list[Diagnostic] = []
        self.warnings: list[Diagnostic] = []
        self.source_manifests: list[dict[str, Any]] = []
        self.source_stats: dict[str, dict[str, int | float]] = {}
        self.concepts: dict[str, dict[str, set[str]]] = collections.defaultdict(
            lambda: {
                "aliases": set(),
                "about": set(),
                "required_by": set(),
            }
        )
        self.pending_links: list[tuple[str, str, str]] = []
        self.anchor_maps: dict[str, dict[str, str]] = {}
        self.provenance_markdown: dict[tuple[str, str], Path] = {}

    def error(self, code: str, message: str, *, source: str | None = None, node: str | None = None) -> None:
        self.errors.append(Diagnostic(code, message, source, node))

    def warn(self, code: str, message: str, *, source: str | None = None, node: str | None = None) -> None:
        self.warnings.append(Diagnostic(code, message, source, node))

    def add_node(self, node: dict[str, Any], *, source: str | None = None) -> None:
        node_id = node["id"]
        if node_id in self.nodes:
            self.error("duplicate-node", f"duplicate graph node {node_id}", source=source, node=node_id)
            return
        self.nodes[node_id] = node

    def add_edge(
        self,
        source: str,
        relation: str,
        target: str,
        provenance: str,
        evidence: str = "",
    ) -> None:
        key = (source, relation, target, provenance, evidence)
        self.edges[key] = {
            "source": source,
            "relation": relation,
            "target": target,
            "provenance": provenance,
            **({"evidence": evidence} if evidence else {}),
        }

    def provenance(self, source: SourceSpec, anchor: str = "") -> dict[str, str]:
        markdown = self.provenance_markdown.get(
            (source.id, anchor),
            source.markdown[0],
        )
        result = {
            "authority": relative_path(self.repo_root, source.authority),
            "markdown": relative_path(self.repo_root, markdown),
        }
        if anchor:
            result["anchor"] = anchor
        return result

    def add_references(self, owner: str, value: Any, source_id: str) -> None:
        citation_keys, link_targets = references(value)
        for key in sorted(citation_keys):
            citation_id = f"citation:{quote(key, safe='-._~:')}"
            if citation_id not in self.nodes:
                self.add_node(
                    {
                        "id": citation_id,
                        "type": "citation",
                        "label": key,
                        "text": "",
                        "properties": {"key": key},
                    }
                )
            self.add_edge(owner, "cites", citation_id, "authored", owner)
        for anchor in sorted(link_targets):
            self.pending_links.append((owner, source_id, anchor))

    def compile_source(self, source: SourceSpec) -> None:
        authority_rel = relative_path(self.repo_root, source.authority)
        if not source.authority.is_file():
            self.error("missing-authority", f"missing authority {authority_rel}", source=source.id)
            return
        missing = [path for path in source.markdown if not path.is_file()]
        if missing:
            for path in missing:
                markdown_rel = relative_path(self.repo_root, path)
                self.error(
                    "missing-markdown",
                    f"missing Markdown snapshot {markdown_rel}",
                    source=source.id,
                )
            return

        documents: list[tuple[Path, dict[str, Any], dict[str, Any]]] = []
        combined_blocks: list[Any] = []
        expected_count = 0
        expected_count_valid = True
        for markdown_path in source.markdown:
            page = run_pandoc(markdown_path)
            page_meta = metadata(page)
            documents.append((markdown_path, page, page_meta))
            combined_blocks.extend(page.get("blocks", []))
            if page_meta.get("authority") != "typst":
                self.error(
                    "invalid-authority",
                    f"Markdown authority must be 'typst', got {page_meta.get('authority')!r}",
                    source=source.id,
                )
            if page_meta.get("qlnotes-schema") != "qlnotes-v1":
                self.error(
                    "invalid-source-schema",
                    f"Markdown schema must be 'qlnotes-v1', got {page_meta.get('qlnotes-schema')!r}",
                    source=source.id,
                )
            try:
                expected_count += int(str(page_meta.get("semantic-node-count", "")))
            except ValueError:
                expected_count_valid = False
                self.error(
                    "invalid-semantic-count",
                    "semantic-node-count must be an integer",
                    source=source.id,
                )

            for block in page.get("blocks", []):
                if isinstance(block, dict) and block.get("t") == "Header":
                    content = block.get("c")
                    if isinstance(content, list) and len(content) == 3:
                        local_id, _, _ = attributes(content[1])
                        if local_id:
                            self.provenance_markdown.setdefault(
                                (source.id, local_id), markdown_path
                            )
                for local_id, _, _, _ in find_semantic_divs(block):
                    self.provenance_markdown.setdefault(
                        (source.id, local_id), markdown_path
                    )
                for local_id, _, _ in find_figures(block):
                    self.provenance_markdown.setdefault(
                        (source.id, local_id), markdown_path
                    )

        document = {"blocks": combined_blocks}
        meta = documents[0][2]
        if not expected_count_valid:
            expected_count = -1

        document_id = source_node_id(source.id)
        document_text_parts = [
            str(meta.get(name, ""))
            for name in ("title", "subtitle", "description", "course")
            if meta.get(name)
        ]
        keywords = meta.get("keywords", [])
        if isinstance(keywords, list):
            document_text_parts.extend(str(item) for item in keywords)
        self.add_node(
            {
                "id": document_id,
                "type": "document",
                "label": str(meta.get("title") or source.id),
                "text": normalize_text("\n".join(document_text_parts)),
                "properties": {
                    "source_id": source.id,
                    "course": meta.get("course", ""),
                    "source": meta.get("source", ""),
                    "semantic_node_count": expected_count,
                },
                "provenance": self.provenance(source),
            },
            source=source.id,
        )

        anchors: dict[str, str] = {}
        self.anchor_maps[source.id] = anchors
        heading_stack: list[tuple[int, str, str]] = []
        section_chunks: dict[str, list[str]] = collections.defaultdict(list)
        statement_ids: set[str] = set()
        statement_nodes: list[str] = []
        statements_with_dependencies = 0
        last_statement: str | None = None
        last_statement_section: str | None = None

        blocks = document.get("blocks", [])
        for block in blocks:
            if isinstance(block, dict) and block.get("t") == "Header":
                content = block.get("c")
                if not isinstance(content, list) or len(content) != 3:
                    continue
                level = int(content[0])
                local_id, _, _ = attributes(content[1])
                label = normalize_text(inline_text(content[2]))
                if not local_id:
                    local_id = f"section-{len(anchors) + 1}"
                while heading_stack and heading_stack[-1][0] >= level:
                    heading_stack.pop()
                section_id = section_node_id(source.id, local_id)
                parent = heading_stack[-1][1] if heading_stack else document_id
                path = [item[2] for item in heading_stack] + [label]
                self.add_node(
                    {
                        "id": section_id,
                        "type": "section",
                        "label": label or local_id,
                        "text": "",
                        "properties": {
                            "level": level,
                            "heading_path": path,
                            "structural": True,
                        },
                        "provenance": self.provenance(source, local_id),
                    },
                    source=source.id,
                )
                self.add_edge(parent, "contains", section_id, "structural")
                if local_id in anchors:
                    self.warn(
                        "duplicate-anchor",
                        f"duplicate Markdown anchor {local_id}",
                        source=source.id,
                        node=section_id,
                    )
                else:
                    anchors[local_id] = section_id
                heading_stack.append((level, section_id, label or local_id))
                last_statement = None
                last_statement_section = None
                continue

            current_section = heading_stack[-1][1] if heading_stack else document_id
            figures = list(find_figures(block))
            for local_id, caption, content in figures:
                node_id = figure_node_id(source.id, local_id)
                if node_id not in self.nodes:
                    self.add_node(
                        {
                            "id": node_id,
                            "type": "figure",
                            "label": caption or local_id,
                            "text": block_text(content),
                            "properties": {"local_id": local_id},
                            "provenance": self.provenance(source, local_id),
                        },
                        source=source.id,
                    )
                    self.add_edge(current_section, "contains", node_id, "structural")
                    anchors.setdefault(local_id, node_id)
                    self.add_references(node_id, content, source.id)
            parsed_statements = list(find_semantic_divs(block))
            if parsed_statements:
                for local_id, kind, attrs, content in parsed_statements:
                    node_id = statement_node_id(source.id, local_id)
                    if local_id in statement_ids:
                        self.error(
                            "duplicate-statement-id",
                            f"duplicate semantic ID {local_id}",
                            source=source.id,
                            node=node_id,
                        )
                        continue
                    statement_ids.add(local_id)
                    statement_nodes.append(node_id)
                    concepts = split_csv(attrs.get("concepts"))
                    dependencies = split_csv(attrs.get("depends"))
                    aliases = split_csv(attrs.get("aliases"))
                    if dependencies:
                        statements_with_dependencies += 1
                    if not concepts:
                        self.warn(
                            "missing-concepts",
                            "semantic statement has no explicit concepts",
                            source=source.id,
                            node=node_id,
                        )
                    if not STABLE_ID_RE.fullmatch(local_id):
                        self.warn(
                            "noncanonical-statement-id",
                            f"semantic ID is not canonical kebab-case: {local_id}",
                            source=source.id,
                            node=node_id,
                        )
                    label = statement_label(kind, content, local_id)
                    self.add_node(
                        {
                            "id": node_id,
                            "type": "statement",
                            "label": label,
                            "text": block_text(content),
                            "properties": {
                                "kind": kind,
                                "local_id": local_id,
                                "concepts": concepts,
                                "depends": dependencies,
                                "aliases": aliases,
                                "section": current_section if current_section != document_id else "",
                                "supporting_blocks": [],
                            },
                            "provenance": self.provenance(source, local_id),
                        },
                        source=source.id,
                    )
                    self.add_edge(current_section, "contains", node_id, "structural")
                    if local_id in anchors:
                        self.warn(
                            "duplicate-anchor",
                            f"duplicate Markdown anchor {local_id}",
                            source=source.id,
                            node=node_id,
                        )
                    else:
                        anchors[local_id] = node_id
                    for concept in concepts:
                        target = concept_id(concept)
                        self.concepts[concept]["about"].add(node_id)
                        self.add_edge(node_id, "about", target, "authored", node_id)
                    for dependency in dependencies:
                        target = concept_id(dependency)
                        self.concepts[dependency]["required_by"].add(node_id)
                        self.add_edge(node_id, "requires", target, "authored", node_id)
                        for concept in concepts:
                            self.add_edge(
                                target,
                                "prerequisite-for",
                                concept_id(concept),
                                "derived-authored",
                                node_id,
                            )
                    if len(concepts) == 1:
                        self.concepts[concepts[0]]["aliases"].update(aliases)
                    self.add_references(node_id, content, source.id)
                    last_statement = node_id
                    last_statement_section = current_section
                continue

            support_kind = ""
            if isinstance(block, dict) and block.get("t") == "Div":
                content = block.get("c")
                if isinstance(content, list) and len(content) == 2:
                    _, classes, _ = attributes(content[0])
                    support_kind = next(
                        (name for name in classes if name in ATTACHED_SUPPORT_KINDS), ""
                    )
            if (
                support_kind
                and last_statement is not None
                and last_statement_section == current_section
            ):
                support_text = block_text(block)
                statement = self.nodes[last_statement]
                statement["properties"]["supporting_blocks"].append(
                    {"kind": support_kind, "text": support_text}
                )
                if support_text:
                    statement["text"] = normalize_text(
                        f"{statement['text']}\n\n{support_text}"
                    )
                self.add_references(last_statement, block, source.id)
                continue

            if figures:
                last_statement = None
                last_statement_section = None
                continue

            prose = block_text(block)
            if prose and current_section != document_id:
                section_chunks[current_section].append(prose)
            self.add_references(current_section, block, source.id)
            last_statement = None
            last_statement_section = None

        for section_id, chunks in section_chunks.items():
            self.nodes[section_id]["text"] = normalize_text("\n\n".join(chunks))

        parsed_count = len(statement_ids)
        if expected_count >= 0 and parsed_count != expected_count:
            self.error(
                "semantic-count-mismatch",
                f"semantic-node-count is {expected_count}, Pandoc parsed {parsed_count} stable statements",
                source=source.id,
            )
        unidentified = unidentified_statement_count(blocks)
        if unidentified:
            self.warn(
                "unidentified-statements",
                f"{unidentified} statement block(s) have no stable semantic ID",
                source=source.id,
            )
        dependency_coverage = (
            statements_with_dependencies / parsed_count if parsed_count else 0.0
        )
        if parsed_count >= 20 and dependency_coverage < 0.05:
            self.warn(
                "low-dependency-coverage",
                f"only {statements_with_dependencies}/{parsed_count} statements declare prerequisites",
                source=source.id,
            )
        self.source_stats[source.id] = {
            "statements": parsed_count,
            "statements_with_dependencies": statements_with_dependencies,
            "dependency_coverage": round(dependency_coverage, 6),
            "unidentified_statements": unidentified,
        }
        self.source_manifests.append(
            {
                "id": source.id,
                "authority": authority_rel,
                "authority_sha256": file_sha256(source.authority),
                "markdown": [
                    {
                        "path": relative_path(self.repo_root, markdown),
                        "sha256": file_sha256(markdown),
                    }
                    for markdown in source.markdown
                ],
                "semantic_nodes": parsed_count,
            }
        )

    def materialize_concepts(self) -> None:
        for name in sorted(self.concepts):
            record = self.concepts[name]
            node_id = concept_id(name)
            self.add_node(
                {
                    "id": node_id,
                    "type": "concept",
                    "label": name,
                    "text": "",
                    "properties": {
                        "key": name,
                        "aliases": sorted(record["aliases"]),
                        "evidence_count": len(record["about"]),
                    },
                }
            )
            if GENERIC_CONCEPT_RE.fullmatch(name):
                self.warn(
                    "generic-concept",
                    f"placeholder-like concept key should be refined: {name}",
                    node=node_id,
                )
            if record["required_by"] and not record["about"]:
                self.warn(
                    "prerequisite-without-evidence",
                    f"prerequisite concept has no statement that is explicitly about it: {name}",
                    node=node_id,
                )

    def resolve_links(self) -> None:
        for owner, source_id, anchor in sorted(set(self.pending_links)):
            target = self.anchor_maps.get(source_id, {}).get(anchor)
            if target is None:
                self.warn(
                    "unresolved-internal-link",
                    f"internal link target #{anchor} is not a graph node",
                    source=source_id,
                    node=owner,
                )
                continue
            self.add_edge(owner, "links-to", target, "authored", owner)

    def detect_prerequisite_cycles(self) -> None:
        adjacency: dict[str, set[str]] = collections.defaultdict(set)
        for edge in self.edges.values():
            if edge["relation"] == "prerequisite-for":
                adjacency[edge["source"]].add(edge["target"])

        visiting: set[str] = set()
        visited: set[str] = set()
        cyclic: set[str] = set()

        def visit(node: str, path: list[str]) -> None:
            if node in visiting:
                start = path.index(node) if node in path else 0
                cyclic.update(path[start:])
                return
            if node in visited:
                return
            visiting.add(node)
            path.append(node)
            for target in sorted(adjacency.get(node, ())):
                visit(target, path)
            path.pop()
            visiting.remove(node)
            visited.add(node)

        for node in sorted(adjacency):
            visit(node, [])
        if cyclic:
            self.warn(
                "prerequisite-cycle",
                "prerequisite projection contains a cycle: " + ", ".join(sorted(cyclic)),
            )

    def validate_endpoints(self) -> None:
        for edge in self.edges.values():
            for endpoint in (edge["source"], edge["target"]):
                if endpoint not in self.nodes:
                    self.error(
                        "dangling-edge",
                        f"{edge['relation']} edge has missing endpoint {endpoint}",
                        node=endpoint,
                    )

    def finish(self) -> None:
        self.materialize_concepts()
        self.resolve_links()
        self.detect_prerequisite_cycles()
        self.validate_endpoints()
        self.errors.sort(key=lambda item: canonical_json(item.as_dict()))
        self.warnings.sort(key=lambda item: canonical_json(item.as_dict()))


def compile_graph(repo_root: Path, sources: list[SourceSpec]) -> GraphCompiler:
    compiler = GraphCompiler(repo_root)
    for source in sources:
        compiler.compile_source(source)
    compiler.finish()
    return compiler


def graph_artifacts(compiler: GraphCompiler) -> dict[str, str]:
    nodes = sorted(compiler.nodes.values(), key=lambda node: (node["type"], node["id"]))
    edges = sorted(
        compiler.edges.values(),
        key=lambda edge: (
            edge["source"],
            edge["relation"],
            edge["target"],
            edge.get("evidence", ""),
        ),
    )
    nodes_text = "".join(canonical_json(node) + "\n" for node in nodes)
    edges_text = "".join(canonical_json(edge) + "\n" for edge in edges)
    graph_digest = sha256_bytes((nodes_text + "\0" + edges_text).encode("utf-8"))
    node_types = collections.Counter(node["type"] for node in nodes)
    relations = collections.Counter(edge["relation"] for edge in edges)
    manifest = {
        "schema": GRAPH_SCHEMA,
        "generator": "notes/math/knowledge/scripts/knowledge.py",
        "graph_sha256": graph_digest,
        "counts": {"nodes": len(nodes), "edges": len(edges)},
        "node_types": dict(sorted(node_types.items())),
        "relations": dict(sorted(relations.items())),
        "sources": sorted(compiler.source_manifests, key=lambda source: source["id"]),
    }
    diagnostics = {
        "schema": DIAGNOSTIC_SCHEMA,
        "errors": [item.as_dict() for item in compiler.errors],
        "warnings": [item.as_dict() for item in compiler.warnings],
        "stats": {
            "sources": dict(sorted(compiler.source_stats.items())),
            "warning_count": len(compiler.warnings),
        },
    }
    return {
        "nodes.jsonl": nodes_text,
        "edges.jsonl": edges_text,
        "manifest.json": pretty_json(manifest),
        "diagnostics.json": pretty_json(diagnostics),
    }


def write_artifacts(output_dir: Path, artifacts: dict[str, str]) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    for name, content in artifacts.items():
        destination = output_dir / name
        temporary = output_dir / f".{name}.tmp"
        temporary.write_text(content, encoding="utf-8")
        temporary.replace(destination)


def graph_delta(output_dir: Path, compiler: GraphCompiler) -> dict[str, int]:
    old_nodes: dict[str, str] = {}
    node_path = output_dir / "nodes.jsonl"
    if node_path.is_file():
        for line in node_path.read_text(encoding="utf-8").splitlines():
            if line:
                node = json.loads(line)
                old_nodes[node["id"]] = canonical_json(node)
    new_nodes = {node_id: canonical_json(node) for node_id, node in compiler.nodes.items()}

    old_edges: set[str] = set()
    edge_path = output_dir / "edges.jsonl"
    if edge_path.is_file():
        old_edges = {line for line in edge_path.read_text(encoding="utf-8").splitlines() if line}
    new_edges = {canonical_json(edge) for edge in compiler.edges.values()}

    shared = old_nodes.keys() & new_nodes.keys()
    return {
        "nodes_added": len(new_nodes.keys() - old_nodes.keys()),
        "nodes_removed": len(old_nodes.keys() - new_nodes.keys()),
        "nodes_changed": sum(old_nodes[node] != new_nodes[node] for node in shared),
        "edges_added": len(new_edges - old_edges),
        "edges_removed": len(old_edges - new_edges),
    }


def write_database(path: Path, compiler: GraphCompiler) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    if temporary.exists():
        temporary.unlink()
    connection = sqlite3.connect(temporary)
    try:
        connection.executescript(
            """
            PRAGMA journal_mode = DELETE;
            CREATE TABLE nodes (
                id TEXT PRIMARY KEY,
                type TEXT NOT NULL,
                label TEXT NOT NULL,
                text TEXT NOT NULL,
                data_json TEXT NOT NULL
            );
            CREATE TABLE edges (
                source TEXT NOT NULL,
                relation TEXT NOT NULL,
                target TEXT NOT NULL,
                provenance TEXT NOT NULL,
                evidence TEXT NOT NULL DEFAULT '',
                PRIMARY KEY (source, relation, target, provenance, evidence)
            );
            CREATE INDEX edges_source ON edges(source, relation);
            CREATE INDEX edges_target ON edges(target, relation);
            CREATE TABLE metadata (
                key TEXT PRIMARY KEY,
                value TEXT NOT NULL
            );
            CREATE VIRTUAL TABLE node_fts USING fts5(
                id UNINDEXED,
                type UNINDEXED,
                label,
                text,
                aliases,
                tokenize = 'unicode61'
            );
            """
        )
        artifacts = graph_artifacts(compiler)
        graph_sha256 = json.loads(artifacts["manifest.json"])["graph_sha256"]
        connection.execute(
            "INSERT INTO metadata VALUES ('graph_sha256', ?)",
            (graph_sha256,),
        )
        for node in sorted(compiler.nodes.values(), key=lambda item: item["id"]):
            properties = node.get("properties", {})
            aliases = properties.get("aliases", [])
            alias_text = " ".join(aliases) if isinstance(aliases, list) else str(aliases)
            connection.execute(
                "INSERT INTO nodes VALUES (?, ?, ?, ?, ?)",
                (
                    node["id"],
                    node["type"],
                    node.get("label", ""),
                    node.get("text", ""),
                    canonical_json(node),
                ),
            )
            connection.execute(
                "INSERT INTO node_fts VALUES (?, ?, ?, ?, ?)",
                (
                    node["id"],
                    node["type"],
                    node.get("label", ""),
                    node.get("text", ""),
                    alias_text,
                ),
            )
        for edge in sorted(compiler.edges.values(), key=canonical_json):
            connection.execute(
                "INSERT INTO edges VALUES (?, ?, ?, ?, ?)",
                (
                    edge["source"],
                    edge["relation"],
                    edge["target"],
                    edge["provenance"],
                    edge.get("evidence", ""),
                ),
            )
        connection.commit()
    finally:
        connection.close()
    temporary.replace(path)


def ensure_database(output_dir: Path, database: Path) -> None:
    manifest_path = output_dir / "manifest.json"
    nodes_path = output_dir / "nodes.jsonl"
    edges_path = output_dir / "edges.jsonl"
    if not all(path.is_file() for path in (manifest_path, nodes_path, edges_path)):
        raise KnowledgeError(
            f"missing committed graph under {output_dir}; run `knowledge.py build`"
        )
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    expected_digest = manifest.get("graph_sha256")
    if database.is_file():
        connection: sqlite3.Connection | None = None
        try:
            connection = sqlite3.connect(database)
            row = connection.execute(
                "SELECT value FROM metadata WHERE key = 'graph_sha256'"
            ).fetchone()
            if row is not None and row[0] == expected_digest:
                return
        except sqlite3.Error:
            pass
        finally:
            if connection is not None:
                connection.close()

    nodes = [
        json.loads(line)
        for line in nodes_path.read_text(encoding="utf-8").splitlines()
        if line
    ]
    edges = [
        json.loads(line)
        for line in edges_path.read_text(encoding="utf-8").splitlines()
        if line
    ]
    nodes_text = "".join(canonical_json(node) + "\n" for node in nodes)
    edges_text = "".join(canonical_json(edge) + "\n" for edge in edges)
    actual_digest = sha256_bytes((nodes_text + "\0" + edges_text).encode("utf-8"))
    if actual_digest != expected_digest:
        raise KnowledgeError(
            "committed graph content hash does not match manifest; run `knowledge.py check`"
        )
    compiler = GraphCompiler(output_dir)
    compiler.nodes = {node["id"]: node for node in nodes}
    compiler.edges = {
        (
            edge["source"],
            edge["relation"],
            edge["target"],
            edge["provenance"],
            edge.get("evidence", ""),
        ): edge
        for edge in edges
    }
    write_database(database, compiler)


def fts_query(value: str) -> str:
    tokens = re.findall(r"[^\s\-_:/.]+", value, flags=re.UNICODE)
    if not tokens:
        raise KnowledgeError("search query must contain text")
    return " AND ".join('"' + token.replace('"', '""') + '"' for token in tokens)


def search_database(
    path: Path,
    query: str,
    *,
    limit: int = 10,
    node_type: str | None = None,
) -> list[dict[str, Any]]:
    if not path.is_file():
        raise KnowledgeError(f"missing search index: {path}; run `knowledge.py build` first")
    connection = sqlite3.connect(path)
    connection.row_factory = sqlite3.Row
    try:
        sql = (
            "SELECT n.data_json, bm25(node_fts) AS rank "
            "FROM node_fts JOIN nodes n ON n.id = node_fts.id "
            "WHERE node_fts MATCH ?"
        )
        parameters: list[Any] = [fts_query(query)]
        if node_type:
            sql += " AND n.type = ?"
            parameters.append(node_type)
        sql += " ORDER BY rank, n.id LIMIT ?"
        parameters.append(limit)
        rows = connection.execute(sql, parameters).fetchall()
        return [
            {**json.loads(row["data_json"]), "rank": round(float(row["rank"]), 6)}
            for row in rows
        ]
    finally:
        connection.close()


def show_database(path: Path, node_id: str) -> dict[str, Any]:
    if not path.is_file():
        raise KnowledgeError(f"missing search index: {path}; run `knowledge.py build` first")
    connection = sqlite3.connect(path)
    connection.row_factory = sqlite3.Row
    try:
        row = connection.execute("SELECT data_json FROM nodes WHERE id = ?", (node_id,)).fetchone()
        if row is None:
            raise KnowledgeError(f"unknown graph node: {node_id}")
        outgoing = connection.execute(
            "SELECT source, relation, target, provenance, evidence FROM edges "
            "WHERE source = ? ORDER BY relation, target, evidence",
            (node_id,),
        ).fetchall()
        incoming = connection.execute(
            "SELECT source, relation, target, provenance, evidence FROM edges "
            "WHERE target = ? ORDER BY relation, source, evidence",
            (node_id,),
        ).fetchall()
        return {
            "node": json.loads(row["data_json"]),
            "outgoing": [dict(item) for item in outgoing],
            "incoming": [dict(item) for item in incoming],
        }
    finally:
        connection.close()


def resolve_cli_paths(args: argparse.Namespace) -> tuple[Path, Path, Path, Path]:
    repo_root = Path(args.repo_root).expanduser().resolve()
    config = repository_path(repo_root, args.config, field="config")
    output = repository_path(repo_root, args.output, field="output")
    database = repository_path(repo_root, args.database, field="database")
    return repo_root, config, output, database


def compile_from_args(args: argparse.Namespace) -> tuple[GraphCompiler, Path, Path]:
    repo_root, config, output, database = resolve_cli_paths(args)
    sources = load_sources(repo_root, config)
    compiler = compile_graph(repo_root, sources)
    return compiler, output, database


def print_errors(compiler: GraphCompiler) -> None:
    for error in compiler.errors:
        location = f" [{error.source}]" if error.source else ""
        print(f"ERROR {error.code}{location}: {error.message}", file=sys.stderr)


def command_build(args: argparse.Namespace) -> int:
    compiler, output, database = compile_from_args(args)
    if compiler.errors:
        print_errors(compiler)
        return 1
    delta = graph_delta(output, compiler)
    artifacts = graph_artifacts(compiler)
    write_artifacts(output, artifacts)
    write_database(database, compiler)
    manifest = json.loads(artifacts["manifest.json"])
    print(
        f"OK: {manifest['counts']['nodes']} nodes, {manifest['counts']['edges']} edges, "
        f"{len(compiler.warnings)} warning(s)"
    )
    print(
        "delta: "
        f"nodes +{delta['nodes_added']} ~{delta['nodes_changed']} -{delta['nodes_removed']}; "
        f"edges +{delta['edges_added']} -{delta['edges_removed']}"
    )
    print(f"graph: {output}")
    print(f"search index: {database}")
    return 0


def command_check(args: argparse.Namespace) -> int:
    compiler, output, _ = compile_from_args(args)
    if compiler.errors:
        print_errors(compiler)
        return 1
    artifacts = graph_artifacts(compiler)
    stale: list[str] = []
    for name, expected in artifacts.items():
        path = output / name
        if not path.is_file() or path.read_text(encoding="utf-8") != expected:
            stale.append(name)
    if stale:
        print(
            "ERROR stale knowledge graph artifacts: " + ", ".join(stale),
            file=sys.stderr,
        )
        print("run `knowledge.py build` after exporting Markdown", file=sys.stderr)
        return 1
    print(
        f"OK: graph is current ({len(compiler.nodes)} nodes, "
        f"{len(compiler.edges)} edges, {len(compiler.warnings)} warning(s))"
    )
    return 0


def command_search(args: argparse.Namespace) -> int:
    _, _, output, database = resolve_cli_paths(args)
    ensure_database(output, database)
    results = search_database(
        database,
        args.query,
        limit=args.limit,
        node_type=args.type,
    )
    print(pretty_json(results), end="")
    return 0


def command_show(args: argparse.Namespace) -> int:
    _, _, output, database = resolve_cli_paths(args)
    ensure_database(output, database)
    print(pretty_json(show_database(database, args.node_id)), end="")
    return 0


def add_repository_arguments(parser: argparse.ArgumentParser) -> None:
    default_root = Path(__file__).resolve().parents[4]
    parser.add_argument("--repo-root", default=str(default_root))
    parser.add_argument(
        "--config",
        default="notes/math/knowledge/sources.json",
        help="repository-relative source registry",
    )
    parser.add_argument(
        "--output",
        default="notes/math/knowledge/graph",
        help="repository-relative committed graph directory",
    )
    parser.add_argument(
        "--database",
        default="notes/math/knowledge/build/knowledge.sqlite",
        help="repository-relative local SQLite index",
    )


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)

    build = subparsers.add_parser("build", help="rebuild JSONL graph and SQLite index")
    add_repository_arguments(build)
    build.set_defaults(handler=command_build)

    check = subparsers.add_parser("check", help="verify committed graph matches sources")
    add_repository_arguments(check)
    check.set_defaults(handler=command_check)

    search = subparsers.add_parser("search", help="full-text search graph nodes")
    add_repository_arguments(search)
    search.add_argument("query")
    search.add_argument("--limit", type=int, default=10)
    search.add_argument("--type", choices=["concept", "statement", "section", "document", "figure", "citation"])
    search.set_defaults(handler=command_search)

    show = subparsers.add_parser("show", help="show one node and its graph neighbors")
    add_repository_arguments(show)
    show.add_argument("node_id")
    show.set_defaults(handler=command_show)

    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        return int(args.handler(args))
    except (KnowledgeError, OSError, sqlite3.Error) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
