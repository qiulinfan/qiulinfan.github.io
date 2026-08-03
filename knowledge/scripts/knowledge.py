#!/usr/bin/env python3
"""Synchronize and query the repository-wide agentic knowledge graph."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import os
import re
import sqlite3
import sys
import tempfile
import unicodedata
from collections import Counter, defaultdict
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


GRAPH_SCHEMA = "qlkg-v2"
SOURCE_SCHEMA = "qlkg-sources-v2"
DELTA_SCHEMA = "qlkg-agent-delta-v2"
ID_RE = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
KN_RE = re.compile(r"#kn\s*\[")
REF_RE = re.compile(r"#ref\s*\[")
STATEMENT_RE = re.compile(
    r"#(?P<kind>definition|theorem|lemma|corollary|proposition|axiom|example)\s*\("
)
SEMANTIC_RELATIONS = {
    "contains",
    "prerequisite-for",
    "implies",
    "generalizes",
    "contrasts-with",
    "derived-from",
}
ACYCLIC_RELATIONS = {"contains", "prerequisite-for"}


class KnowledgeError(RuntimeError):
    """Raised when the graph contract cannot be satisfied."""


@dataclass(frozen=True)
class SourceSpec:
    id: str
    subject: str
    course: str
    root: Path
    patterns: tuple[str, ...]
    web: str
    topic_patterns: tuple[tuple[str, str, str], ...]


@dataclass(frozen=True)
class StatementRange:
    start: int
    end: int
    kind: str


@dataclass(frozen=True)
class DefinitionOccurrence:
    id: str
    label: str
    label_typst: str
    kind: str
    authority: str
    line: int
    anchor: str
    web: str
    source_id: str
    subject: str
    course: str
    topic: str | None
    position: int
    statement: StatementRange | None


@dataclass(frozen=True)
class ReferenceOccurrence:
    id: str
    target: str
    label: str
    authority: str
    line: int
    web: str
    context: str | None


@dataclass
class ScanResult:
    definitions: list[DefinitionOccurrence]
    references: list[ReferenceOccurrence]
    errors: list[dict[str, Any]]


@dataclass
class GraphState:
    nodes: dict[str, dict[str, Any]]
    edges: dict[tuple[str, str, str], dict[str, Any]]
    references: list[dict[str, Any]]
    manifest: dict[str, Any]


def diagnostic(
    code: str,
    message: str,
    *,
    source: str | None = None,
    node: str | None = None,
) -> dict[str, Any]:
    value: dict[str, Any] = {"code": code, "message": message}
    if source:
        value["source"] = source
    if node:
        value["node"] = node
    return value


def json_text(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(",", ":"))


def pretty_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2) + "\n"


def jsonl(values: Iterable[dict[str, Any]]) -> str:
    rendered = [json_text(value) for value in values]
    return "\n".join(rendered) + ("\n" if rendered else "")


def sha256_text(value: str) -> str:
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def relative_path(repo_root: Path, path: Path) -> str:
    try:
        return path.resolve().relative_to(repo_root.resolve()).as_posix()
    except ValueError as error:
        raise KnowledgeError(f"source lies outside repository: {path}") from error


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8", newline="") as handle:
            handle.write(content)
        os.replace(temporary, path)
    except BaseException:
        try:
            os.unlink(temporary)
        except FileNotFoundError:
            pass
        raise


def read_json(path: Path, default: Any) -> Any:
    if not path.is_file():
        return copy.deepcopy(default)
    return json.loads(path.read_text(encoding="utf-8"))


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    if not path.is_file():
        return []
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line]


def load_sources(repo_root: Path, registry: Path) -> list[SourceSpec]:
    payload = read_json(registry, {})
    if payload.get("schema") != SOURCE_SCHEMA:
        raise KnowledgeError(f"expected {SOURCE_SCHEMA} source registry: {registry}")
    result: list[SourceSpec] = []
    seen: set[str] = set()
    for raw in payload.get("sources", []):
        source_id = str(raw.get("id", ""))
        if not source_id or source_id in seen:
            raise KnowledgeError(f"duplicate or empty source id: {source_id!r}")
        seen.add(source_id)
        root = (repo_root / str(raw.get("root", ""))).resolve()
        if not root.is_dir():
            raise KnowledgeError(f"missing source root for {source_id}: {root}")
        patterns = tuple(str(item) for item in raw.get("files", []))
        if not patterns:
            raise KnowledgeError(f"source {source_id} has no bounded file patterns")
        topics = tuple(
            (
                str(item["glob"]),
                str(item["id"]),
                str(item["label"]),
            )
            for item in raw.get("topics", [])
        )
        result.append(
            SourceSpec(
                id=source_id,
                subject=str(raw.get("subject", "")),
                course=str(raw.get("course", "")),
                root=root,
                patterns=patterns,
                web=str(raw.get("web", "")).rstrip("/"),
                topic_patterns=topics,
            )
        )
    return result


def expand_source(spec: SourceSpec) -> list[Path]:
    files: set[Path] = set()
    for pattern in spec.patterns:
        files.update(path.resolve() for path in spec.root.glob(pattern) if path.is_file())
    return sorted(files, key=lambda item: item.as_posix())


def topic_for(spec: SourceSpec, path: Path) -> tuple[str, str] | None:
    relative = path.resolve().relative_to(spec.root).as_posix()
    for pattern, topic_id, label in spec.topic_patterns:
        if path.match(str(spec.root / pattern)) or Path(relative).match(pattern):
            return topic_id, label
    return None


def find_matching(text: str, start: int, opening: str, closing: str) -> int:
    if start >= len(text) or text[start] != opening:
        raise KnowledgeError(f"expected {opening!r} at offset {start}")
    depth = 0
    content_depth = 0
    quote = False
    escaped = False
    for index in range(start, len(text)):
        character = text[index]
        if quote:
            if escaped:
                escaped = False
            elif character == "\\":
                escaped = True
            elif character == '"':
                quote = False
            continue
        if character == '"' and (index == 0 or text[index - 1] != "\\"):
            quote = True
            continue
        if opening == "(" and character == "[" and (index == 0 or text[index - 1] != "\\"):
            content_depth += 1
            continue
        if opening == "(" and character == "]" and (index == 0 or text[index - 1] != "\\"):
            content_depth = max(0, content_depth - 1)
            continue
        if content_depth:
            continue
        if character == opening and (index == 0 or text[index - 1] != "\\"):
            depth += 1
        elif character == closing and (index == 0 or text[index - 1] != "\\"):
            depth -= 1
            if depth == 0:
                return index
    raise KnowledgeError(f"unclosed {opening!r} at offset {start}")


def statement_ranges(text: str) -> list[StatementRange]:
    result: list[StatementRange] = []
    for match in STATEMENT_RE.finditer(text):
        close = find_matching(text, match.end() - 1, "(", ")")
        cursor = close + 1
        while cursor < len(text) and text[cursor].isspace():
            cursor += 1
        end = close + 1
        if cursor < len(text) and text[cursor] == "[":
            end = find_matching(text, cursor, "[", "]") + 1
        result.append(StatementRange(match.start(), end, match.group("kind")))
    return result


def strip_typst(value: str) -> str:
    text = unicodedata.normalize("NFKC", value)
    text = re.sub(r"#(?:strong|emph|text)\[", "", text)
    text = text.replace("$", "").replace("\\", "")
    text = re.sub(r"[#\[\]{}]", " ", text)
    text = re.sub(r"\bsigma\b", "σ", text)
    text = re.sub(r"\bpi\b", "π", text)
    text = re.sub(r"\s+", " ", text).strip(" ,:;")
    return text


def identity_key(value: str) -> str:
    return re.sub(r"\s+", " ", unicodedata.normalize("NFKC", value).casefold()).strip()


def generated_id(value: str) -> str:
    normalized = unicodedata.normalize("NFKC", value).casefold()
    normalized = normalized.replace("σ", " sigma ").replace("π", " pi ").replace("λ", " lambda ")
    candidate = re.sub(r"[^a-z0-9]+", "-", normalized).strip("-")[:120].rstrip("-")
    return candidate or f"knowledge-{sha256_text(identity_key(value))[:16]}"


def build_identity_index(state: GraphState) -> dict[str, str]:
    result: dict[str, str] = {}
    for node in state.nodes.values():
        if node.get("type") != "knowledge":
            continue
        properties = node.get("properties") or {}
        names = [node.get("label", ""), *properties.get("aliases", [])]
        for raw in names:
            key = identity_key(str(raw))
            if not key:
                continue
            existing = result.get(key)
            if existing and existing != node["id"]:
                raise KnowledgeError(
                    f"ambiguous knowledge name {raw!r}: {existing!r} and {node['id']!r}"
                )
            result[key] = node["id"]
    return result


def containing_statement(ranges: list[StatementRange], position: int) -> StatementRange | None:
    candidates = [item for item in ranges if item.start <= position < item.end]
    return min(candidates, key=lambda item: item.end - item.start) if candidates else None


def scan_typst(
    repo_root: Path,
    spec: SourceSpec,
    path: Path,
    identities: dict[str, str],
) -> ScanResult:
    authority = relative_path(repo_root, path)
    text = path.read_text(encoding="utf-8")
    errors: list[dict[str, Any]] = []
    try:
        ranges = statement_ranges(text)
    except KnowledgeError as error:
        return ScanResult([], [], [diagnostic("typst-parse", str(error), source=authority)])
    topic = topic_for(spec, path)
    definitions: list[DefinitionOccurrence] = []
    for match in KN_RE.finditer(text):
        try:
            close = find_matching(text, match.end() - 1, "[", "]")
        except KnowledgeError as error:
            errors.append(diagnostic("typst-parse", str(error), source=authority))
            continue
        label_typst = text[match.end() : close]
        label = strip_typst(label_typst)
        if not label:
            errors.append(
                diagnostic(
                    "empty-knowledge-name",
                    "#kn must contain a non-empty semantic name",
                    source=authority,
                )
            )
            continue
        key = identity_key(label)
        node_id = identities.get(key) or generated_id(label)
        identities.setdefault(key, node_id)
        statement = containing_statement(ranges, match.start())
        line = text.count("\n", 0, match.start()) + 1
        anchor = f"kn-{node_id}"
        web = f"{spec.web}/#{anchor}" if spec.web else f"/knowledge/#node={node_id}"
        definitions.append(
            DefinitionOccurrence(
                id=node_id,
                label=label,
                label_typst=label_typst,
                kind=statement.kind if statement else "concept",
                authority=authority,
                line=line,
                anchor=anchor,
                web=web,
                source_id=spec.id,
                subject=spec.subject,
                course=spec.course,
                topic=topic[0] if topic else None,
                position=match.start(),
                statement=statement,
            )
        )
    statement_nodes: dict[tuple[int, int], list[str]] = defaultdict(list)
    for item in definitions:
        if item.statement:
            statement_nodes[(item.statement.start, item.statement.end)].append(item.id)
    references: list[ReferenceOccurrence] = []
    for match in REF_RE.finditer(text):
        try:
            close = find_matching(text, match.end() - 1, "[", "]")
        except KnowledgeError as error:
            errors.append(diagnostic("typst-parse", str(error), source=authority))
            continue
        label = strip_typst(text[match.end() : close])
        if not label:
            errors.append(
                diagnostic(
                    "empty-reference-name",
                    "#ref must contain a non-empty semantic name",
                    source=authority,
                )
            )
            continue
        target = identities.get(identity_key(label)) or generated_id(label)
        statement = containing_statement(ranges, match.start())
        context = None
        if statement:
            candidates = statement_nodes.get((statement.start, statement.end), [])
            if len(candidates) == 1:
                context = candidates[0]
        line = text.count("\n", 0, match.start()) + 1
        references.append(
            ReferenceOccurrence(
                id=sha256_text(f"{authority}:{line}:{target}:{context or ''}")[:20],
                target=target,
                label=label,
                authority=authority,
                line=line,
                web=spec.web,
                context=context,
            )
        )
    return ScanResult(definitions, references, errors)


def load_state(graph_dir: Path) -> GraphState:
    manifest = read_json(graph_dir / "manifest.json", {})
    if manifest.get("schema") != GRAPH_SCHEMA:
        return GraphState({}, {}, [], {})
    nodes = {item["id"]: item for item in read_jsonl(graph_dir / "nodes.jsonl")}
    edges = {
        (item["source"], item["relation"], item["target"]): item
        for item in read_jsonl(graph_dir / "edges.jsonl")
    }
    references = read_jsonl(graph_dir / "references.jsonl")
    return GraphState(nodes, edges, references, manifest)


def select_scope(
    repo_root: Path,
    specs: list[SourceSpec],
    files: list[Path],
    course: str | None,
    subject: str | None,
) -> tuple[list[tuple[SourceSpec, Path]], set[str], bool]:
    full = not files and not course and not subject
    selected_specs = [
        spec
        for spec in specs
        if (course is None or spec.course == course)
        and (subject is None or spec.subject == subject)
    ]
    if (course or subject) and not selected_specs:
        raise KnowledgeError(f"no source matched course={course!r} subject={subject!r}")
    if full:
        selected_specs = specs
    pairs: list[tuple[SourceSpec, Path]] = []
    if files:
        for raw in files:
            path = (repo_root / raw).resolve() if not raw.is_absolute() else raw.resolve()
            owner = next(
                (spec for spec in specs if path == spec.root or spec.root in path.parents),
                None,
            )
            if owner is None:
                raise KnowledgeError(f"file is outside configured source roots: {raw}")
            if path.is_file():
                pairs.append((owner, path))
            elif path.exists():
                raise KnowledgeError(f"scope path is not a file: {raw}")
            else:
                pairs.append((owner, path))
    else:
        for spec in selected_specs:
            pairs.extend((spec, path) for path in expand_source(spec))
    unique: dict[str, tuple[SourceSpec, Path]] = {}
    for spec, path in pairs:
        unique[relative_path(repo_root, path)] = (spec, path)
    return list(unique.values()), set(unique), full


def scan_scope(
    repo_root: Path,
    pairs: list[tuple[SourceSpec, Path]],
    identities: dict[str, str],
) -> ScanResult:
    definitions: list[DefinitionOccurrence] = []
    references: list[ReferenceOccurrence] = []
    errors: list[dict[str, Any]] = []
    for spec, path in pairs:
        if not path.is_file():
            continue
        result = scan_typst(repo_root, spec, path, identities)
        definitions.extend(result.definitions)
        references.extend(result.references)
        errors.extend(result.errors)
    by_id: dict[str, list[DefinitionOccurrence]] = defaultdict(list)
    for item in definitions:
        by_id[item.id].append(item)
    for node_id, items in by_id.items():
        if len(items) > 1:
            locations = ", ".join(f"{item.authority}:{item.line}" for item in items)
            errors.append(
                diagnostic(
                    "duplicate-kn",
                    f"global knowledge name {items[0].label!r} occurs more than once: {locations}",
                    node=node_id,
                )
            )
    return ScanResult(definitions, references, errors)


def edge_key(edge: dict[str, Any]) -> tuple[str, str, str]:
    return str(edge["source"]), str(edge["relation"]), str(edge["target"])


def source_node(definition: DefinitionOccurrence, existing: dict[str, Any] | None) -> dict[str, Any]:
    previous = copy.deepcopy(existing) if existing else {}
    properties = dict(previous.get("properties") or {})
    aliases = list(dict.fromkeys(str(item) for item in properties.get("aliases", [])))
    old_label = str(previous.get("label", ""))
    if old_label and old_label != definition.label and old_label not in aliases:
        aliases.append(old_label)
    properties.update(
        {
            "kind": definition.kind,
            "aliases": aliases,
            "origin": "authored",
            "source_status": "active",
            "subject": definition.subject,
            "course": definition.course,
            "typst_name": definition.label_typst,
        }
    )
    if definition.topic:
        properties["topic"] = definition.topic
    properties.pop("orphaned_from", None)
    return {
        "id": definition.id,
        "type": "knowledge",
        "label": definition.label,
        "text": str(previous.get("text", "")),
        "properties": properties,
        "provenance": {
            "authority": definition.authority,
            "line": definition.line,
            "anchor": definition.anchor,
            "web": definition.web,
            "active": True,
        },
    }


def orphan_node(node: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(node)
    properties = dict(result.get("properties") or {})
    provenance = dict(result.get("provenance") or {})
    if provenance.get("authority"):
        properties["orphaned_from"] = provenance["authority"]
    properties["source_status"] = "orphaned"
    provenance["active"] = False
    result["properties"] = properties
    if provenance:
        result["provenance"] = provenance
    return result


def reference_record(item: ReferenceOccurrence) -> dict[str, Any]:
    value: dict[str, Any] = {
        "id": item.id,
        "target": item.target,
        "label": item.label,
        "authority": item.authority,
        "line": item.line,
        "origin": "authored",
    }
    if item.web:
        value["web"] = item.web
    if item.context:
        value["context"] = item.context
    return value


def ensure_topic_nodes_and_edges(
    state: GraphState,
    specs: list[SourceSpec],
    definitions: list[DefinitionOccurrence],
) -> None:
    for spec in specs:
        for _, topic_id, label in spec.topic_patterns:
            if topic_id not in state.nodes:
                state.nodes[topic_id] = {
                    "id": topic_id,
                    "type": "topic",
                    "label": label,
                    "text": "",
                    "properties": {
                        "kind": "topic",
                        "aliases": [],
                        "origin": "agent",
                        "source_status": "meta",
                        "subject": spec.subject,
                        "course": spec.course,
                    },
                }
    for definition in definitions:
        if not definition.topic:
            continue
        edge = {
            "source": definition.topic,
            "relation": "contains",
            "target": definition.id,
            "origin": "agent-taxonomy",
            "confidence": "high",
            "evidence": f"canonical definition is authored in {definition.authority}",
        }
        state.edges[edge_key(edge)] = edge


def graph_cycles(nodes: set[str], edges: Iterable[dict[str, Any]], relation: str) -> list[list[str]]:
    adjacency: dict[str, list[str]] = defaultdict(list)
    for edge in edges:
        if edge.get("relation") == relation:
            adjacency[str(edge["source"])].append(str(edge["target"]))
    visiting: set[str] = set()
    visited: set[str] = set()
    stack: list[str] = []
    cycles: list[list[str]] = []

    def visit(node: str) -> None:
        if node in visiting:
            try:
                start = stack.index(node)
            except ValueError:
                start = 0
            cycles.append(stack[start:] + [node])
            return
        if node in visited:
            return
        visiting.add(node)
        stack.append(node)
        for target in adjacency.get(node, []):
            visit(target)
        stack.pop()
        visiting.remove(node)
        visited.add(node)

    for node in sorted(nodes):
        visit(node)
    return cycles


def validate_state(state: GraphState) -> dict[str, list[dict[str, Any]]]:
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []
    node_ids = set(state.nodes)
    for edge in state.edges.values():
        if edge.get("relation") not in SEMANTIC_RELATIONS:
            errors.append(diagnostic("unknown-relation", f"unknown relation: {edge.get('relation')}"))
        for endpoint in ("source", "target"):
            if edge.get(endpoint) not in node_ids:
                errors.append(
                    diagnostic(
                        "dangling-edge",
                        f"edge endpoint does not exist: {edge.get(endpoint)}",
                        node=str(edge.get(endpoint, "")),
                    )
                )
    for relation in ACYCLIC_RELATIONS:
        for cycle in graph_cycles(node_ids, state.edges.values(), relation):
            errors.append(
                diagnostic(
                    "graph-cycle",
                    f"{relation} cycle: {' -> '.join(cycle)}",
                    node=cycle[0],
                )
            )
    for node in state.nodes.values():
        if (node.get("properties") or {}).get("source_status") == "orphaned":
            warnings.append(
                diagnostic(
                    "orphaned-node",
                    "knowledge metadata and semantic edges are retained, but no active #kn defines this node",
                    source=(node.get("provenance") or {}).get("authority"),
                    node=node["id"],
                )
            )
    for reference in state.references:
        if reference.get("target") not in node_ids:
            warnings.append(
                diagnostic(
                    "dangling-ref",
                    f"#ref target does not exist: {reference.get('target')}",
                    source=reference.get("authority"),
                    node=reference.get("target"),
                )
            )
    return {
        "errors": sorted(errors, key=json_text),
        "warnings": sorted(warnings, key=json_text),
    }


def make_artifacts(
    state: GraphState,
    source_hashes: dict[str, str],
) -> dict[str, str]:
    nodes = sorted(state.nodes.values(), key=lambda item: item["id"])
    edges = sorted(
        state.edges.values(),
        key=lambda item: (item["source"], item["relation"], item["target"]),
    )
    references = sorted(
        state.references,
        key=lambda item: (item.get("authority", ""), item.get("line", 0), item["target"]),
    )
    diagnostics = validate_state(state)
    nodes_text = jsonl(nodes)
    edges_text = jsonl(edges)
    references_text = jsonl(references)
    diagnostics_text = pretty_json(diagnostics)
    digest = sha256_text(nodes_text + edges_text + references_text)
    node_types = Counter(item["type"] for item in nodes)
    relations = Counter(item["relation"] for item in edges)
    statuses = Counter((item.get("properties") or {}).get("source_status", "") for item in nodes)
    manifest = {
        "schema": GRAPH_SCHEMA,
        "generator": "knowledge/scripts/knowledge.py",
        "graph_sha256": digest,
        "counts": {
            "nodes": len(nodes),
            "edges": len(edges),
            "references": len(references),
        },
        "node_types": dict(sorted(node_types.items())),
        "relations": dict(sorted(relations.items())),
        "statuses": dict(sorted(statuses.items())),
        "source_hashes": dict(sorted(source_hashes.items())),
    }
    return {
        "manifest.json": pretty_json(manifest),
        "nodes.jsonl": nodes_text,
        "edges.jsonl": edges_text,
        "references.jsonl": references_text,
        "diagnostics.json": diagnostics_text,
    }


def write_artifacts(graph_dir: Path, artifacts: dict[str, str]) -> None:
    graph_dir.mkdir(parents=True, exist_ok=True)
    for name, content in artifacts.items():
        atomic_write(graph_dir / name, content)


def typst_string(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")


def write_registry(path: Path, state: GraphState) -> None:
    lines = ["// Generated by knowledge/scripts/knowledge.py. Do not edit by hand.", "#let knowledge-registry = ("]
    for node in sorted(state.nodes.values(), key=lambda item: item["id"]):
        node_id = node["id"]
        properties = node.get("properties") or {}
        typst_name = properties.get("typst_name")
        if node.get("type") != "knowledge" or not typst_name:
            continue
        provenance = node.get("provenance") or {}
        if properties.get("source_status") == "active" and provenance.get("web"):
            url = str(provenance["web"])
        else:
            url = f"https://qiulinfan.github.io/qlblog/knowledge/#node={node_id}"
        lines.extend(
            [
                "  (",
                f"    name: [{typst_name}],",
                f'    id: "{typst_string(node_id)}",',
                f'    title: "{typst_string(str(node.get("label", node_id)))}",',
                f'    url: "{typst_string(url)}",',
                "  ),",
            ]
        )
    lines.append(")")
    atomic_write(path, "\n".join(lines) + "\n")


def write_database(path: Path, state: GraphState) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists():
        path.unlink()
    connection = sqlite3.connect(path)
    try:
        connection.execute(
            "CREATE TABLE nodes (id TEXT PRIMARY KEY, type TEXT, label TEXT, text TEXT, properties TEXT, provenance TEXT)"
        )
        connection.execute("CREATE VIRTUAL TABLE node_fts USING fts5(id, label, text, aliases)")
        for node in sorted(state.nodes.values(), key=lambda item: item["id"]):
            properties = node.get("properties") or {}
            aliases = " ".join(str(item) for item in properties.get("aliases", []))
            connection.execute(
                "INSERT INTO nodes VALUES (?, ?, ?, ?, ?, ?)",
                (
                    node["id"],
                    node["type"],
                    node.get("label", ""),
                    node.get("text", ""),
                    json_text(properties),
                    json_text(node.get("provenance") or {}),
                ),
            )
            connection.execute(
                "INSERT INTO node_fts VALUES (?, ?, ?, ?)",
                (node["id"], node.get("label", ""), node.get("text", ""), aliases),
            )
        connection.commit()
    finally:
        connection.close()


def synchronize(
    repo_root: Path,
    registry: Path,
    graph_dir: Path,
    database: Path,
    typst_registry: Path,
    *,
    files: list[Path],
    course: str | None,
    subject: str | None,
    write: bool,
) -> tuple[GraphState, dict[str, str], dict[str, Any]]:
    specs = load_sources(repo_root, registry)
    pairs, selected_keys, full = select_scope(repo_root, specs, files, course, subject)
    previous = load_state(graph_dir)
    state = copy.deepcopy(previous)
    scan = scan_scope(repo_root, pairs, build_identity_index(previous))
    if scan.errors:
        raise KnowledgeError("\n".join(item["message"] for item in scan.errors))
    outside = {
        node_id: node
        for node_id, node in state.nodes.items()
        if (node.get("provenance") or {}).get("active")
        and (node.get("provenance") or {}).get("authority") not in selected_keys
    }
    for definition in scan.definitions:
        if definition.id in outside:
            old = outside[definition.id].get("provenance") or {}
            raise KnowledgeError(
                f"global knowledge name {definition.label!r} occurs more than once: "
                f"{old.get('authority')} and {definition.authority}"
            )
    found_ids = {item.id for item in scan.definitions}
    orphaned: list[str] = []
    for node_id, node in list(state.nodes.items()):
        provenance = node.get("provenance") or {}
        if provenance.get("active") and provenance.get("authority") in selected_keys and node_id not in found_ids:
            state.nodes[node_id] = orphan_node(node)
            orphaned.append(node_id)
    for definition in scan.definitions:
        state.nodes[definition.id] = source_node(definition, state.nodes.get(definition.id))
    state.references = [
        item for item in state.references if item.get("authority") not in selected_keys
    ] + [reference_record(item) for item in scan.references]
    ensure_topic_nodes_and_edges(state, specs, scan.definitions)
    source_hashes = dict(previous.manifest.get("source_hashes") or {})
    if full:
        source_hashes = {}
    for _, path in pairs:
        key = relative_path(repo_root, path)
        if path.is_file():
            source_hashes[key] = sha256_file(path)
        else:
            source_hashes.pop(key, None)
    artifacts = make_artifacts(state, source_hashes)
    diagnostics = json.loads(artifacts["diagnostics.json"])
    if diagnostics["errors"]:
        raise KnowledgeError("\n".join(item["message"] for item in diagnostics["errors"]))
    old_counts = previous.manifest.get("counts") or {"nodes": 0, "edges": 0, "references": 0}
    new_manifest = json.loads(artifacts["manifest.json"])
    new_counts = new_manifest["counts"]
    report = {
        "scope": "repository" if full else "incremental",
        "files": len(pairs),
        "definitions": len(scan.definitions),
        "references": len(scan.references),
        "orphaned": sorted(orphaned),
        "delta": {
            key: int(new_counts.get(key, 0)) - int(old_counts.get(key, 0))
            for key in ("nodes", "edges", "references")
        },
        "counts": new_counts,
        "warnings": len(diagnostics["warnings"]),
    }
    if write:
        write_artifacts(graph_dir, artifacts)
        write_registry(typst_registry, state)
        write_database(database, state)
    return state, artifacts, report


def apply_delta(
    graph_dir: Path,
    database: Path,
    typst_registry: Path,
    delta_path: Path,
) -> dict[str, Any]:
    delta = read_json(delta_path, {})
    if delta.get("schema") != DELTA_SCHEMA:
        raise KnowledgeError(f"expected {DELTA_SCHEMA} delta: {delta_path}")
    state = load_state(graph_dir)
    before = dict(state.manifest.get("counts") or {})
    for raw in delta.get("nodes", []):
        node_id = str(raw.get("id", ""))
        if not ID_RE.fullmatch(node_id):
            raise KnowledgeError(f"invalid delta node id: {node_id!r}")
        existing = copy.deepcopy(state.nodes.get(node_id) or {})
        properties = dict(existing.get("properties") or {})
        properties.update(raw.get("properties") or {})
        properties.setdefault("aliases", [])
        properties.setdefault("origin", "agent")
        properties.setdefault("source_status", "meta")
        node = {
            "id": node_id,
            "type": str(raw.get("type") or existing.get("type") or "knowledge"),
            "label": str(raw.get("label") or existing.get("label") or node_id.replace("-", " ")),
            "text": str(raw.get("text") if "text" in raw else existing.get("text", "")),
            "properties": properties,
        }
        if existing.get("provenance"):
            node["provenance"] = existing["provenance"]
        state.nodes[node_id] = node
    for raw in delta.get("remove_edges", []):
        state.edges.pop(
            (str(raw["source"]), str(raw["relation"]), str(raw["target"])),
            None,
        )
    for raw in delta.get("edges", []):
        edge = {
            "source": str(raw["source"]),
            "relation": str(raw["relation"]),
            "target": str(raw["target"]),
            "origin": str(raw.get("origin", "agent")),
            "confidence": str(raw.get("confidence", "high")),
            "evidence": str(raw.get("evidence", "agent semantic extraction")),
        }
        state.edges[edge_key(edge)] = edge
    artifacts = make_artifacts(state, dict(state.manifest.get("source_hashes") or {}))
    diagnostics = json.loads(artifacts["diagnostics.json"])
    if diagnostics["errors"]:
        raise KnowledgeError("\n".join(item["message"] for item in diagnostics["errors"]))
    write_artifacts(graph_dir, artifacts)
    write_registry(typst_registry, state)
    write_database(database, state)
    after = json.loads(artifacts["manifest.json"])["counts"]
    return {
        "nodes_upserted": len(delta.get("nodes", [])),
        "edges_upserted": len(delta.get("edges", [])),
        "edges_removed": len(delta.get("remove_edges", [])),
        "delta": {
            key: int(after.get(key, 0)) - int(before.get(key, 0))
            for key in ("nodes", "edges", "references")
        },
        "counts": after,
        "warnings": len(diagnostics["warnings"]),
    }


def search_graph(state: GraphState, query: str, limit: int) -> list[dict[str, Any]]:
    terms = [item for item in unicodedata.normalize("NFKC", query).lower().split() if item]
    scored: list[tuple[int, dict[str, Any]]] = []
    for node in state.nodes.values():
        properties = node.get("properties") or {}
        aliases = " ".join(str(item) for item in properties.get("aliases", []))
        label = str(node.get("label", ""))
        haystack = " ".join((node["id"], label, str(node.get("text", "")), aliases)).lower()
        if not all(term in haystack for term in terms):
            continue
        score = 20 if all(term in label.lower() for term in terms) else 0
        score += 10 if node.get("type") == "knowledge" else 0
        scored.append((score, node))
    return [item for _, item in sorted(scored, key=lambda pair: (-pair[0], pair[1]["label"]))[:limit]]


def show_node(state: GraphState, node_id_or_name: str) -> dict[str, Any]:
    node_id = node_id_or_name
    if node_id not in state.nodes:
        node_id = build_identity_index(state).get(identity_key(node_id_or_name), "")
    if not node_id or node_id not in state.nodes:
        raise KnowledgeError(f"unknown knowledge node: {node_id_or_name}")
    return {
        "node": state.nodes[node_id],
        "incoming": sorted(
            [item for item in state.edges.values() if item["target"] == node_id],
            key=json_text,
        ),
        "outgoing": sorted(
            [item for item in state.edges.values() if item["source"] == node_id],
            key=json_text,
        ),
        "backlinks": sorted(
            [item for item in state.references if item["target"] == node_id],
            key=json_text,
        ),
    }


def defaults(repo_root: Path, value: str) -> Path:
    return (repo_root / value).resolve()


def add_scope_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--file", action="append", default=[], type=Path)
    parser.add_argument("--course")
    parser.add_argument("--subject")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo-root", type=Path, default=Path.cwd())
    parser.add_argument("--registry", default="knowledge/sources.json")
    parser.add_argument("--graph", default="knowledge/graph")
    parser.add_argument("--database", default="knowledge/build/knowledge.sqlite")
    parser.add_argument(
        "--typst-registry",
        default="notes/math/toolchain/generated/knowledge-registry.typ",
    )
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("sync", "build", "scan"):
        command = commands.add_parser(name)
        add_scope_arguments(command)
    apply_command = commands.add_parser("apply")
    apply_command.add_argument("delta", type=Path)
    commands.add_parser("check")
    search_command = commands.add_parser("search")
    search_command.add_argument("query")
    search_command.add_argument("--limit", type=int, default=20)
    show_command = commands.add_parser("show")
    show_command.add_argument("id")
    commands.add_parser("stats")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    registry = defaults(repo_root, args.registry)
    graph_dir = defaults(repo_root, args.graph)
    database = defaults(repo_root, args.database)
    typst_registry = defaults(repo_root, args.typst_registry)
    try:
        if args.command in {"sync", "build", "scan"}:
            pairs_files = list(args.file)
            if args.command == "scan":
                specs = load_sources(repo_root, registry)
                pairs, selected, full = select_scope(
                    repo_root, specs, pairs_files, args.course, args.subject
                )
                state = load_state(graph_dir)
                result = scan_scope(repo_root, pairs, build_identity_index(state))
                found = {item.id for item in result.definitions}
                orphaned = sorted(
                    node_id
                    for node_id, node in state.nodes.items()
                    if (node.get("provenance") or {}).get("active")
                    and (node.get("provenance") or {}).get("authority") in selected
                    and node_id not in found
                )
                print(
                    pretty_json(
                        {
                            "scope": "repository" if full else "incremental",
                            "files": [relative_path(repo_root, path) for _, path in pairs],
                            "definitions": [item.__dict__ | {"statement": None} for item in result.definitions],
                            "references": [item.__dict__ for item in result.references],
                            "would_orphan": orphaned,
                            "errors": result.errors,
                        }
                    ),
                    end="",
                )
                return 1 if result.errors else 0
            _, _, report = synchronize(
                repo_root,
                registry,
                graph_dir,
                database,
                typst_registry,
                files=pairs_files,
                course=args.course,
                subject=args.subject,
                write=True,
            )
            print(pretty_json(report), end="")
            return 0
        if args.command == "apply":
            delta = args.delta if args.delta.is_absolute() else (repo_root / args.delta)
            print(pretty_json(apply_delta(graph_dir, database, typst_registry, delta)), end="")
            return 0
        if args.command == "check":
            _, artifacts, report = synchronize(
                repo_root,
                registry,
                graph_dir,
                database,
                typst_registry,
                files=[],
                course=None,
                subject=None,
                write=False,
            )
            stale = [
                name
                for name, content in artifacts.items()
                if not (graph_dir / name).is_file()
                or (graph_dir / name).read_text(encoding="utf-8") != content
            ]
            if stale:
                raise KnowledgeError(f"stale graph artifacts: {', '.join(stale)}")
            print(f"OK: {GRAPH_SCHEMA}; {json_text(report['counts'])}; warnings={report['warnings']}")
            return 0
        state = load_state(graph_dir)
        if args.command == "search":
            print(pretty_json(search_graph(state, args.query, args.limit)), end="")
        elif args.command == "show":
            print(pretty_json(show_node(state, args.id)), end="")
        elif args.command == "stats":
            print(pretty_json(state.manifest), end="")
        return 0
    except (KnowledgeError, OSError, UnicodeError, json.JSONDecodeError, sqlite3.Error) as error:
        print(f"knowledge command failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
