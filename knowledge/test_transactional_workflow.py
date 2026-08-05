from __future__ import annotations

import copy
import json
import subprocess
import tempfile
import unittest
from pathlib import Path

from kgdistiller.agent import compare_graph, sha256_json
from kgdistiller.alignment import load_alignment_set
from kgdistiller.candidate import build_candidate_snapshot
from kgdistiller.cli import (
    apply_delta,
    curation_report,
    load_state,
    sha256_file,
    sha256_text,
    synchronize,
)
from kgdistiller.ingest import (
    CAPABILITY,
    IngestError,
    IngestPaths,
    apply_ingest,
    finalize_request,
    plan_ingest,
)


class MultiFormatTransactionalWorkflowTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="qlblog-transaction-e2e-")
        self.repo = Path(self.temporary.name)
        self.notes = self.repo / "notes/demo"
        self.notes.mkdir(parents=True)
        self.alpha = self.notes / "alpha.md"
        self.typst = self.notes / "typst.typ"
        self.latex = self.notes / "latex.tex"
        self.rename_old = self.notes / "rename-old.md"
        self.ambiguity = self.notes / "ambiguity.md"
        self.alpha.write_text(
            "> **Definition: --[[Alpha]]--**\n>\n> Alpha is the baseline concept.\n",
            encoding="utf-8",
        )
        self.typst.write_text(
            "#definition(title: [#kn[Typst Base]])[Typst baseline.]\n",
            encoding="utf-8",
        )
        self.latex.write_text(
            "\\begin{definition}\\kn{Latex Base} Latex baseline.\\end{definition}\n",
            encoding="utf-8",
        )
        self.rename_old.write_text(
            "> **Definition: --[[Rename Base]]--**\n>\n> Rename baseline.\n",
            encoding="utf-8",
        )
        self.ambiguity.write_text(
            "> **Definition: --[[Absolutely continuous]]--**\n>\n"
            "> Absolutely continuous (AC) is the analytic sense.\n\n"
            "> **Definition: --[[Alternating current]]--**\n>\n"
            "> Alternating current (AC) is the electrical sense.\n",
            encoding="utf-8",
        )
        self.registry = self.repo / "knowledge/sources.json"
        self.registry.parent.mkdir(parents=True)
        self.registry.write_text(
            json.dumps(
                {
                    "schema": "qlkg-sources-v2",
                    "fields": [
                        {"id": "demo", "label": "Demo", "text": "Test field."}
                    ],
                    "sources": [
                        {
                            "id": "demo:notes",
                            "subject": "demo",
                            "course": "demo",
                            "knowledge_origin": "personal-note",
                            "fields": ["demo"],
                            "root": "notes/demo",
                            "files": ["*.md", "*.typ", "*.tex"],
                            "web": "https://example.test/notes/demo",
                            "topics": [],
                        }
                    ],
                }
            ),
            encoding="utf-8",
        )
        self.graph = self.repo / "knowledge/graph"
        self.identities = self.repo / "knowledge/identities.json"
        self.alignments = self.repo / "knowledge/alignments.json"
        self.alignments.write_text(
            json.dumps({"schema": "qlkg-alignments-v1", "mappings": []}),
            encoding="utf-8",
        )
        self.database = self.repo / "knowledge/build/knowledge.sqlite"
        self.typst_registry = self.repo / "knowledge/build/knowledge-registry.typ"
        self.paths = IngestPaths(
            repo_root=self.repo,
            registry=self.registry,
            graph_dir=self.graph,
            identities=self.identities,
            alignments=self.alignments,
            database=self.database,
            typst_registry=self.typst_registry,
        )
        synchronize(
            self.repo,
            self.registry,
            self.graph,
            self.database,
            self.typst_registry,
            identities=self.identities,
            alignments=self.alignments,
            files=[],
            course=None,
            subject=None,
            write=True,
        )
        baseline_delta = self.repo / "knowledge/build/baseline.delta.json"
        baseline_delta.write_text(
            json.dumps(
                {
                    "schema": "qlkg-agent-delta-v2",
                    "remove_nodes": [],
                    "nodes": [
                        {
                            "id": "alpha",
                            "entry": {
                                "summary": "Alpha is the baseline concept.",
                                "claims": {"definition": "baseline-alpha"},
                            },
                        },
                        {"id": "typst-base", "text": "Typst baseline."},
                        {"id": "latex-base", "text": "Latex baseline."},
                        {"id": "rename-base", "text": "Rename baseline."},
                        {
                            "id": "absolutely-continuous",
                            "text": "Absolutely continuous (AC) is the analytic sense.",
                        },
                        {
                            "id": "alternating-current",
                            "text": "Alternating current (AC) is the electrical sense.",
                        },
                    ],
                    "edges": [],
                    "remove_edges": [],
                }
            ),
            encoding="utf-8",
        )
        apply_delta(
            self.graph,
            self.database,
            self.typst_registry,
            baseline_delta,
            self.alignments,
        )
        synchronize(
            self.repo,
            self.registry,
            self.graph,
            self.database,
            self.typst_registry,
            identities=self.identities,
            alignments=self.alignments,
            files=[],
            course=None,
            subject=None,
            write=True,
        )
        (self.repo / ".gitignore").write_text("knowledge/build/\n", encoding="utf-8")
        self.git("init", "-q")
        self.git("config", "user.name", "kgdistiller fixture")
        self.git("config", "user.email", "fixture@example.test")
        self.commit("baseline")

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def git(self, *arguments: str) -> str:
        return subprocess.run(
            ["git", *arguments],
            cwd=self.repo,
            check=True,
            capture_output=True,
            text=True,
        ).stdout

    def commit(self, message: str) -> None:
        self.git("add", "-A")
        self.git("commit", "-q", "-m", message)

    def candidate(
        self,
        name: str,
        nodes: list[dict],
        edges: list[dict] | None = None,
    ) -> tuple[Path, dict, Path, dict]:
        source = {
            "schema": "qlkg-candidate-graph-v1",
            "namespace": f"paper:{name}",
            "nodes": [
                {
                    "id": node["id"],
                    "type": "knowledge",
                    "label": node["label"],
                    "text": node.get("text", ""),
                    **({"entry": node["entry"]} if node.get("entry") else {}),
                    "properties": {"aliases": node.get("aliases", [])},
                    "provenance": {
                        "authority": f"{name}.md",
                        "line": index + 1,
                        "source_format": "markdown",
                    },
                }
                for index, node in enumerate(nodes)
            ],
            "edges": edges or [],
            "references": [],
            "diagnostics": {"errors": [], "warnings": []},
        }
        snapshot = build_candidate_snapshot(source)
        snapshot_path = self.repo / f"knowledge/build/{name}.snapshot.json"
        snapshot_path.parent.mkdir(parents=True, exist_ok=True)
        snapshot_path.write_text(json.dumps(snapshot), encoding="utf-8")
        report = compare_graph(self.database, snapshot)
        report_path = self.repo / f"knowledge/build/{name}.comparison.json"
        report_path.write_text(json.dumps(report), encoding="utf-8")
        return snapshot_path, snapshot, report_path, report

    def request(
        self,
        request_id: str,
        candidate: tuple[Path, dict, Path, dict],
        *,
        patches: list[dict],
        decisions: list[dict],
        delta: dict,
        mode: str = "apply",
    ) -> dict:
        snapshot_path, snapshot, report_path, report = candidate
        state = load_state(self.graph)
        return finalize_request(
            {
                "schema": "qlkg-ingest-request-v1",
                "request_id": request_id,
                "mode": mode,
                "capabilities": [CAPABILITY],
                "base_graph_sha256": state.manifest["graph_sha256"],
                "base_alignment_sha256": sha256_json(
                    load_alignment_set(self.alignments)
                ),
                "candidate_snapshot": {
                    "path": snapshot_path.relative_to(self.repo).as_posix(),
                    "sha256": snapshot["snapshot_sha256"],
                },
                "query_report": {
                    "path": report_path.relative_to(self.repo).as_posix(),
                    "sha256": sha256_json(report),
                },
                "authority_patches": patches,
                "decisions": decisions,
                "delta": delta,
                "alignment_decisions": [],
                "review": {
                    "status": "reviewed",
                    "reviewer": "isolated-agent-fixture",
                    "evidence": ["Candidate, comparison, and native source patch reviewed."],
                    "provenance": [{"kind": "fixture", "request": request_id}],
                },
            }
        )

    def write_patch(
        self,
        path: Path,
        definitions: list[str],
        references: list[str],
    ) -> dict:
        content = path.read_text(encoding="utf-8")
        return {
            "path": path.relative_to(self.repo).as_posix(),
            "operation": "write",
            "expected_sha256": sha256_file(path),
            "content": content,
            "content_sha256": sha256_text(content),
            "expected_markers": {
                "definitions": definitions,
                "references": references,
            },
        }

    def delete_patch(self, path: Path) -> dict:
        return {
            "path": path.relative_to(self.repo).as_posix(),
            "operation": "delete",
            "expected_sha256": None,
            "expected_markers": {"definitions": [], "references": []},
        }

    @staticmethod
    def delta(*, nodes: list[dict] | None = None, edges: list[dict] | None = None) -> dict:
        return {
            "schema": "qlkg-agent-delta-v2",
            "remove_nodes": [],
            "nodes": nodes or [],
            "edges": edges or [],
            "remove_edges": [],
        }

    def test_markdown_typst_latex_partial_rename_delete_and_review_stops(self) -> None:
        markdown = self.notes / "markdown-new.md"
        markdown.write_text(
            "[[Alpha]] is required.\n\n"
            "> **Definition: --[[Markdown New]]--**\n>\n> A new Markdown concept.\n",
            encoding="utf-8",
        )
        self.assertIn("?? notes/demo/markdown-new.md", self.git("status", "--porcelain"))
        before_state = load_state(self.graph)
        unrelated = copy.deepcopy(before_state.nodes["latex-base"])
        typst_hash = sha256_file(self.typst)
        markdown_candidate = self.candidate(
            "markdown",
            [
                {"id": "paper-alpha", "label": "Alpha", "text": "Known prerequisite."},
                {"id": "markdown-new", "label": "Markdown New", "text": "A new Markdown concept."},
            ],
        )
        self.assertEqual(
            {"paper-alpha": "known", "markdown-new": "new"},
            {
                item["candidate"]["id"]: item["status"]
                for item in markdown_candidate[3]["results"]
            },
        )
        receipt = apply_ingest(
            self.paths,
            self.request(
                "markdown-untracked",
                markdown_candidate,
                patches=[self.write_patch(markdown, ["markdown-new"], ["alpha"])],
                decisions=[
                    {"candidate_id": "paper-alpha", "action": "reuse", "target_id": "alpha", "evidence": "Exact canonical label."},
                    {"candidate_id": "markdown-new", "action": "add", "target_id": "markdown-new", "evidence": "No personal identity exists."},
                ],
                delta=self.delta(nodes=[{"id": "markdown-new", "text": "A new Markdown concept."}]),
            ),
        )
        self.assertEqual("committed", receipt["status"])
        state = load_state(self.graph)
        self.assertEqual(unrelated, state.nodes["latex-base"])
        self.assertEqual(typst_hash, sha256_file(self.typst))
        self.assertTrue(
            any(
                reference["authority"] == "notes/demo/markdown-new.md"
                and reference["target"] == "alpha"
                for reference in state.references
            )
        )
        self.commit("markdown transaction")

        self.typst.write_text(
            self.typst.read_text(encoding="utf-8")
            + "#ref[Alpha]\n#definition(title: [#kn[Omega Construction]])[A new Typst concept.]\n",
            encoding="utf-8",
        )
        self.git("add", self.typst.relative_to(self.repo).as_posix())
        self.assertIn("M  notes/demo/typst.typ", self.git("status", "--porcelain"))
        typst_candidate = self.candidate(
            "typst",
            [
                {"id": "paper-alpha", "label": "Alpha", "text": "Known prerequisite."},
                {"id": "omega-construction", "label": "Omega Construction", "text": "A new Typst concept."},
            ],
        )
        typst_receipt = apply_ingest(
            self.paths,
            self.request(
                "typst-staged",
                typst_candidate,
                patches=[self.write_patch(self.typst, ["omega-construction", "typst-base"], ["alpha"])],
                decisions=[
                    {"candidate_id": "paper-alpha", "action": "reuse", "target_id": "alpha", "evidence": "Exact canonical label."},
                    {"candidate_id": "omega-construction", "action": "add", "target_id": "omega-construction", "evidence": "No personal identity exists."},
                ],
                delta=self.delta(nodes=[{"id": "omega-construction", "text": "A new Typst concept."}]),
            ),
        )
        self.assertEqual(["omega-construction"], typst_receipt["changes"]["nodes"]["added"])
        self.commit("typst transaction")

        self.latex.write_text(
            self.latex.read_text(encoding="utf-8")
            + "By \\knref{Alpha}, this follows.\n"
            + "\\begin{definition}\\kn{Gamma Principle} A new LaTeX concept.\\end{definition}\n",
            encoding="utf-8",
        )
        self.assertIn(" M notes/demo/latex.tex", self.git("status", "--porcelain"))
        latex_candidate = self.candidate(
            "latex",
            [
                {"id": "paper-alpha", "label": "Alpha", "text": "Known prerequisite."},
                {"id": "gamma-principle", "label": "Gamma Principle", "text": "A new LaTeX concept."},
            ],
        )
        latex_receipt = apply_ingest(
            self.paths,
            self.request(
                "latex-unstaged",
                latex_candidate,
                patches=[self.write_patch(self.latex, ["gamma-principle", "latex-base"], ["alpha"])],
                decisions=[
                    {"candidate_id": "paper-alpha", "action": "reuse", "target_id": "alpha", "evidence": "Exact canonical label."},
                    {"candidate_id": "gamma-principle", "action": "add", "target_id": "gamma-principle", "evidence": "No personal identity exists."},
                ],
                delta=self.delta(nodes=[{"id": "gamma-principle", "text": "A new LaTeX concept."}]),
            ),
        )
        self.assertEqual(["gamma-principle"], latex_receipt["changes"]["nodes"]["added"])
        self.commit("latex transaction")

        partial_candidate = self.candidate(
            "partial",
            [
                {"id": "paper-alpha", "label": "Alpha", "text": "Known prerequisite."},
                {"id": "paper-typst", "label": "Typst Base", "text": "Known target."},
            ],
            [
                {
                    "source": "paper-alpha",
                    "relation": "prerequisite-for",
                    "target": "paper-typst",
                    "origin": "paper-extraction",
                    "confidence": "high",
                    "evidence": "The paper directly requires Alpha before Typst Base.",
                }
            ],
        )
        by_id = {
            item["candidate"]["id"]: item["status"]
            for item in partial_candidate[3]["results"]
        }
        self.assertEqual("partial", by_id["paper-alpha"])
        partial_receipt = apply_ingest(
            self.paths,
            self.request(
                "partial-edge",
                partial_candidate,
                patches=[],
                decisions=[
                    {"candidate_id": "paper-alpha", "action": "update", "target_id": "alpha", "evidence": "Only the direct edge is missing."},
                    {"candidate_id": "paper-typst", "action": "reuse", "target_id": "typst-base", "evidence": "Exact canonical label."},
                ],
                delta=self.delta(
                    edges=[
                        {
                            "source": "alpha",
                            "relation": "prerequisite-for",
                            "target": "typst-base",
                            "origin": "agent-note-extraction",
                            "confidence": "high",
                            "evidence": "The Typst authority directly references Alpha as its prerequisite.",
                        }
                    ]
                ),
            ),
        )
        self.assertIn(
            "alpha|prerequisite-for|typst-base",
            partial_receipt["changes"]["edges"]["added"],
        )
        self.assertEqual([], curation_report(load_state(self.graph), {"notes/demo/typst.typ"})["errors"])
        self.commit("partial transaction")

        conflict_candidate = self.candidate(
            "conflict",
            [
                {
                    "id": "paper-alpha",
                    "label": "Alpha",
                    "text": "A conflicting Alpha claim.",
                    "entry": {"claims": {"definition": "contradictory-alpha"}},
                }
            ],
        )
        self.assertEqual("conflict", conflict_candidate[3]["results"][0]["status"])
        conflict_request = self.request(
            "conflict-stop",
            conflict_candidate,
            patches=[],
            decisions=[
                {"candidate_id": "paper-alpha", "action": "add", "target_id": "paper-alpha", "evidence": "Unsafe automatic choice."}
            ],
            delta=self.delta(nodes=[{"id": "paper-alpha", "text": "Unsafe."}]),
            mode="plan",
        )
        with self.assertRaises(IngestError) as conflict_error:
            plan_ingest(self.paths, conflict_request)
        self.assertEqual("unresolved-identity", conflict_error.exception.code)

        uncertain_candidate = self.candidate(
            "uncertain",
            [{"id": "ac", "label": "AC", "text": "AC is used without expansion."}],
        )
        self.assertEqual("uncertain", uncertain_candidate[3]["results"][0]["status"])
        uncertain_request = self.request(
            "uncertain-stop",
            uncertain_candidate,
            patches=[],
            decisions=[
                {"candidate_id": "ac", "action": "add", "target_id": "ac", "evidence": "Unsafe abbreviation merge."}
            ],
            delta=self.delta(nodes=[{"id": "ac", "text": "Unsafe."}]),
            mode="plan",
        )
        with self.assertRaises(IngestError) as uncertain_error:
            plan_ingest(self.paths, uncertain_request)
        self.assertEqual("unresolved-identity", uncertain_error.exception.code)

        rename_new = self.notes / "rename-new.md"
        self.git("mv", self.rename_old.relative_to(self.repo).as_posix(), rename_new.relative_to(self.repo).as_posix())
        self.assertIn("R  notes/demo/rename-old.md -> notes/demo/rename-new.md", self.git("status", "--porcelain"))
        rename_candidate = self.candidate(
            "rename",
            [{"id": "rename-base", "label": "Rename Base", "text": "Rename baseline."}],
        )
        rename_receipt = apply_ingest(
            self.paths,
            self.request(
                "rename-authority",
                rename_candidate,
                patches=[
                    self.delete_patch(self.rename_old),
                    self.write_patch(rename_new, ["rename-base"], []),
                ],
                decisions=[
                    {"candidate_id": "rename-base", "action": "reuse", "target_id": "rename-base", "evidence": "Stable explicit identity is unchanged."}
                ],
                delta=self.delta(),
            ),
        )
        self.assertEqual("committed", rename_receipt["status"])
        self.assertEqual(
            "notes/demo/rename-new.md",
            load_state(self.graph).nodes["rename-base"]["provenance"]["authority"],
        )
        self.commit("rename transaction")

        delete_candidate = self.candidate(
            "delete",
            [{"id": "rename-base", "label": "Rename Base", "text": "Rename baseline."}],
        )
        self.git("rm", "-q", rename_new.relative_to(self.repo).as_posix())
        self.assertIn("D  notes/demo/rename-new.md", self.git("status", "--porcelain"))
        delete_receipt = apply_ingest(
            self.paths,
            self.request(
                "delete-authority",
                delete_candidate,
                patches=[self.delete_patch(rename_new)],
                decisions=[
                    {"candidate_id": "rename-base", "action": "reuse", "target_id": "rename-base", "evidence": "Deletion orphans but does not invent identity."}
                ],
                delta=self.delta(),
            ),
        )
        self.assertIn("rename-base", delete_receipt["changes"]["nodes"]["orphaned"])
        self.assertEqual(
            "orphaned",
            load_state(self.graph).nodes["rename-base"]["properties"]["source_status"],
        )


if __name__ == "__main__":
    unittest.main()
