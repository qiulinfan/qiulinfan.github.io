from __future__ import annotations

import importlib.util
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = REPO_ROOT / "knowledge/scripts/knowledge.py"
SPEC = importlib.util.spec_from_file_location("ql_knowledge", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
knowledge = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = knowledge
SPEC.loader.exec_module(knowledge)


class KnowledgeGraphTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="qlkg-v2-test-")
        self.repo = Path(self.temporary.name)
        self.source_root = self.repo / "notes/math/demo"
        self.chapter = self.source_root / "chapters/01-foundations.typ"
        self.chapter.parent.mkdir(parents=True)
        shutil.copyfile(
            REPO_ROOT / "knowledge/tests/fixtures/roundtrip.typ",
            self.chapter,
        )
        self.registry = self.repo / "knowledge/sources.json"
        self.registry.parent.mkdir(parents=True)
        self.registry.write_text(
            json.dumps(
                {
                    "schema": "qlkg-sources-v2",
                    "sources": [
                        {
                            "id": "math:demo",
                            "subject": "math",
                            "course": "demo",
                            "root": "notes/math/demo",
                            "files": [
                                "chapters/*.typ",
                                "chapters/*.md",
                                "chapters/*.tex",
                                "appendix/*.md",
                            ],
                            "web": "https://example.test/demo",
                            "topics": [
                                {
                                    "glob": "chapters/*.typ",
                                    "id": "demo-foundations",
                                    "label": "Demo Foundations",
                                }
                            ],
                        }
                    ],
                }
            ),
            encoding="utf-8",
        )
        self.graph = self.repo / "knowledge/graph"
        self.database = self.repo / "knowledge/build/knowledge.sqlite"
        self.typst_registry = self.repo / "notes/math/toolchain/generated/knowledge-registry.typ"

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def sync(self, *, files: list[Path] | None = None):
        return knowledge.synchronize(
            self.repo,
            self.registry,
            self.graph,
            self.database,
            self.typst_registry,
            files=files or [],
            course=None,
            subject=None,
            write=True,
        )

    def test_only_explicit_kn_becomes_knowledge_and_ref_is_backlink(self) -> None:
        state, _, report = self.sync()
        self.assertEqual(2, report["definitions"])
        self.assertEqual(1, report["references"])
        self.assertEqual({"sigma-algebra", "measure-space"}, {
            node_id for node_id, node in state.nodes.items() if node["type"] == "knowledge"
        })
        self.assertNotIn("worked-example", state.nodes)
        self.assertEqual("measure-space", state.references[0]["target"])
        self.assertIn(("demo-foundations", "contains", "sigma-algebra"), state.edges)
        self.assertEqual("sigma-algebra", knowledge.show_node(state, "σ-algebra")["node"]["id"])
        registry = self.typst_registry.read_text(encoding="utf-8")
        self.assertIn("name: [$sigma$-algebra]", registry)
        self.assertIn('id: "sigma-algebra"', registry)
        self.assertIn("<math>", state.nodes["sigma-algebra"]["properties"]["label_html"])

    def test_artifacts_are_deterministic(self) -> None:
        _, first, _ = self.sync()
        _, second, report = self.sync()
        self.assertEqual(first, second)
        self.assertEqual({"nodes": 0, "edges": 0, "references": 0}, report["delta"])
        manifest = json.loads(first["manifest.json"])
        self.assertEqual("qlkg-v2", manifest["schema"])
        self.assertRegex(manifest["graph_sha256"], r"^[0-9a-f]{64}$")
        self.assertNotIn("generated_at", manifest)

    def test_changed_file_orphans_without_erasing_meta_or_edges_then_rehomes(self) -> None:
        self.sync()
        delta = self.repo / "knowledge/build/delta.json"
        delta.write_text(
            json.dumps(
                {
                    "schema": "qlkg-agent-delta-v2",
                    "nodes": [
                        {
                            "id": "sigma-algebra",
                            "type": "knowledge",
                            "text": "Durable agent summary.",
                            "properties": {"reviewed": True},
                        }
                    ],
                    "edges": [
                        {
                            "source": "sigma-algebra",
                            "relation": "prerequisite-for",
                            "target": "measure-space",
                            "evidence": "measure spaces are built on sigma-algebras",
                        }
                    ],
                }
            ),
            encoding="utf-8",
        )
        knowledge.apply_delta(self.graph, self.database, self.typst_registry, delta)

        self.chapter.write_text(
            self.chapter.read_text(encoding="utf-8").replace(
                "#kn[$sigma$-algebra]", "σ-algebra"
            ),
            encoding="utf-8",
        )
        state, _, report = self.sync(files=[Path("notes/math/demo/chapters/01-foundations.typ")])
        node = state.nodes["sigma-algebra"]
        self.assertEqual(["sigma-algebra"], report["orphaned"])
        self.assertEqual("orphaned", node["properties"]["source_status"])
        self.assertEqual("Durable agent summary.", node["text"])
        self.assertTrue(node["properties"]["reviewed"])
        self.assertIn(("sigma-algebra", "prerequisite-for", "measure-space"), state.edges)

        new_chapter = self.source_root / "chapters/02-rehomed.typ"
        new_chapter.write_text(
            "= Rehomed\n#definition(title: [#kn[$sigma$-algebra]])[New authority.]\n",
            encoding="utf-8",
        )
        state, _, _ = self.sync(files=[Path("notes/math/demo/chapters/02-rehomed.typ")])
        node = state.nodes["sigma-algebra"]
        self.assertEqual("active", node["properties"]["source_status"])
        self.assertEqual("notes/math/demo/chapters/02-rehomed.typ", node["provenance"]["authority"])
        self.assertEqual("Durable agent summary.", node["text"])
        self.assertIn(("sigma-algebra", "prerequisite-for", "measure-space"), state.edges)

    def test_multiple_explicit_kn_markers_in_one_title_create_multiple_nodes(self) -> None:
        self.chapter.write_text(
            "= Foundations\n"
            "#definition(title: [#kn[norm] and #kn[seminorm]])[Two related definitions.]\n",
            encoding="utf-8",
        )

        state, _, report = self.sync()

        self.assertEqual(2, report["definitions"])
        self.assertEqual(
            {"norm", "seminorm"},
            {node_id for node_id, node in state.nodes.items() if node["type"] == "knowledge"},
        )
        self.assertEqual(
            state.nodes["norm"]["provenance"]["line"],
            state.nodes["seminorm"]["provenance"]["line"],
        )

    def test_typst_registry_includes_authored_reference_spellings(self) -> None:
        self.chapter.write_text(
            "#definition(title: [#kn[concept #strong[one,\ntwo]]])[Authority.]\n"
            "By #ref[concept #strong[one, two]], continue.\n",
            encoding="utf-8",
        )

        self.sync()

        registry = self.typst_registry.read_text(encoding="utf-8")
        self.assertIn("names: (", registry)
        self.assertIn("[concept #strong[one,\ntwo]]", registry)
        self.assertIn("[concept #strong[one, two]]", registry)

    def test_mixed_markdown_and_latex_sources_share_one_graph(self) -> None:
        markdown = self.source_root / "chapters/02-cache.md"
        markdown.write_text(
            "# Cache\n\n"
            "> **Definition: --[[cache line]]--**\n>\n"
            "> A cache line is the transfer unit. It may depend on [[σ-algebra]].\n\n"
            "An ordinary [[cache line|line]] occurrence is a backlink, not a definition.\n",
            encoding="utf-8",
        )
        latex = self.source_root / "chapters/03-cache.tex"
        latex.write_text(
            "\\begin{theorem}\n"
            "\\kn{cache locality theorem}\n"
            "By \\knref{cache line}, nearby accesses are cheaper.\n"
            "\\end{theorem}\n",
            encoding="utf-8",
        )

        state, _, report = self.sync()

        self.assertEqual(4, report["definitions"])
        self.assertEqual(4, report["references"])
        self.assertEqual("markdown", state.nodes["cache-line"]["properties"]["source_format"])
        self.assertEqual("latex", state.nodes["cache-locality-theorem"]["properties"]["source_format"])
        self.assertNotIn("typst_name", state.nodes["cache-line"]["properties"])
        self.assertEqual(
            "https://example.test/demo/chapters/02-cache/#kn-cache-line",
            state.nodes["cache-line"]["provenance"]["web"],
        )
        cache_refs = [item for item in state.references if item["target"] == "cache-line"]
        self.assertEqual(2, len(cache_refs))
        self.assertEqual({"markdown", "latex"}, {item["source_format"] for item in cache_refs})
        registry = self.typst_registry.read_text(encoding="utf-8")
        self.assertIn('name: [#text("cache line")]', registry)

    def test_markdown_requires_explicit_authority_dashes(self) -> None:
        markdown = self.source_root / "chapters/02-links.md"
        markdown.write_text(
            "# Links\n\n[[new reference]] and --[[canonical concept]]--.\n",
            encoding="utf-8",
        )

        state, _, report = self.sync()

        self.assertEqual(3, report["definitions"])
        self.assertNotIn("new-reference", state.nodes)
        self.assertIn("canonical-concept", state.nodes)
        self.assertEqual("new-reference", next(
            item["target"] for item in state.references if item["label"] == "new reference"
        ))

    def test_markdown_escaped_double_brackets_are_literal_text(self) -> None:
        markdown = self.source_root / "chapters/02-escaped.md"
        markdown.write_text(
            "# Literal syntax\n\n"
            "\\--[[not an authority]]-- and \\[[not a reference]].\n",
            encoding="utf-8",
        )

        state, _, report = self.sync()

        self.assertEqual(2, report["definitions"])
        self.assertEqual(1, report["references"])
        self.assertNotIn("not-an-authority", state.nodes)
        self.assertFalse(any(item["label"].startswith("not a") for item in state.references))

    def test_directory_scope_expands_configured_mixed_sources_only(self) -> None:
        markdown = self.source_root / "chapters/02-cache.md"
        markdown.write_text("--[[cache line]]--\n", encoding="utf-8")
        latex = self.source_root / "chapters/03-locality.tex"
        latex.write_text("\\kn{locality theorem}\n", encoding="utf-8")
        outside = self.source_root / "appendix/01-outside.md"
        outside.parent.mkdir(parents=True)
        outside.write_text("--[[outside concept]]--\n", encoding="utf-8")
        self.sync()

        outside.write_text("The authority marker was removed.\n", encoding="utf-8")
        state, _, report = self.sync(files=[Path("notes/math/demo/chapters")])

        self.assertEqual(4, report["definitions"])
        self.assertEqual("active", state.nodes["outside-concept"]["properties"]["source_status"])
        self.assertIn("cache-line", state.nodes)
        self.assertIn("locality-theorem", state.nodes)

    def test_global_audit_reports_topology_and_file_curation_coverage(self) -> None:
        state, _, _ = self.sync()
        report = knowledge.audit_report(state)

        self.assertEqual("qlkg-audit-v1", report["schema"])
        self.assertEqual(2, report["counts"]["active_knowledge"])
        self.assertEqual(0, report["counts"]["entries"])
        self.assertEqual(2, report["topology"]["isolated_nodes"])
        self.assertEqual(
            ["notes/math/demo/chapters/01-foundations.typ"],
            report["curation"]["pending_authorities"],
        )

        delta = self.repo / "knowledge/build/audit.json"
        delta.parent.mkdir(parents=True, exist_ok=True)
        delta.write_text(
            json.dumps(
                {
                    "schema": "qlkg-agent-delta-v2",
                    "nodes": [
                        {"id": "sigma-algebra", "text": "Closed under the defining operations."},
                        {"id": "measure-space", "text": "A measurable space with a measure."},
                    ],
                    "edges": [
                        {
                            "source": "sigma-algebra",
                            "relation": "prerequisite-for",
                            "target": "measure-space",
                            "evidence": "a measure space is built on a sigma-algebra",
                        }
                    ],
                }
            ),
            encoding="utf-8",
        )
        knowledge.apply_delta(self.graph, self.database, self.typst_registry, delta)
        report = knowledge.audit_report(knowledge.load_state(self.graph))

        self.assertEqual(2, report["counts"]["entries"])
        self.assertEqual(0, report["topology"]["isolated_nodes"])
        self.assertEqual(2, report["topology"]["largest_component"])
        self.assertEqual(
            ["notes/math/demo/chapters/01-foundations.typ"],
            report["curation"]["complete_authorities"],
        )

    def test_duplicate_active_kn_is_rejected(self) -> None:
        duplicate = self.source_root / "chapters/02-duplicate.typ"
        duplicate.write_text(
            "= Duplicate\n#theorem(title: [#kn[$sigma$-algebra]])[No.]\n",
            encoding="utf-8",
        )
        with self.assertRaisesRegex(knowledge.KnowledgeError, "global knowledge name"):
            self.sync()

    def test_semantic_cycle_is_rejected(self) -> None:
        self.sync()
        delta = self.repo / "knowledge/build/cycle.json"
        delta.write_text(
            json.dumps(
                {
                    "schema": "qlkg-agent-delta-v2",
                    "edges": [
                        {"source": "sigma-algebra", "relation": "prerequisite-for", "target": "measure-space"},
                        {"source": "measure-space", "relation": "prerequisite-for", "target": "sigma-algebra"},
                    ],
                }
            ),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(knowledge.KnowledgeError, "prerequisite-for cycle"):
            knowledge.apply_delta(self.graph, self.database, self.typst_registry, delta)

    def test_file_curation_requires_entries_and_cross_file_refs(self) -> None:
        state, _, _ = self.sync()
        authority = "notes/math/demo/chapters/01-foundations.typ"
        report = knowledge.curation_report(state, {authority})
        self.assertEqual(2, report["nodes"])
        self.assertEqual(0, report["entries"])
        self.assertEqual(
            ["missing-node-entry", "missing-node-entry"],
            [item["code"] for item in report["errors"]],
        )

        entries = self.repo / "knowledge/build/entries.json"
        entries.parent.mkdir(parents=True, exist_ok=True)
        entries.write_text(
            json.dumps(
                {
                    "schema": "qlkg-agent-delta-v2",
                    "nodes": [
                        {"id": "sigma-algebra", "text": "A family of sets closed under the required operations."},
                        {"id": "measure-space", "text": "A measurable space equipped with a measure."},
                    ],
                }
            ),
            encoding="utf-8",
        )
        knowledge.apply_delta(self.graph, self.database, self.typst_registry, entries)

        application = self.source_root / "chapters/02-application.typ"
        application.write_text(
            "= Application\n#theorem(title: [#kn[completion theorem]])[A completion exists.]\n",
            encoding="utf-8",
        )
        self.sync(files=[Path("notes/math/demo/chapters/02-application.typ")])
        relation = self.repo / "knowledge/build/relation.json"
        relation.write_text(
            json.dumps(
                {
                    "schema": "qlkg-agent-delta-v2",
                    "nodes": [
                        {"id": "completion-theorem", "text": "Every object in scope admits a completion."},
                    ],
                    "edges": [
                        {
                            "source": "sigma-algebra",
                            "relation": "prerequisite-for",
                            "target": "completion-theorem",
                            "evidence": "the completion is constructed from the sigma-algebra",
                        }
                    ],
                }
            ),
            encoding="utf-8",
        )
        knowledge.apply_delta(self.graph, self.database, self.typst_registry, relation)

        application_authority = "notes/math/demo/chapters/02-application.typ"
        state = knowledge.load_state(self.graph)
        report = knowledge.curation_report(state, {application_authority})
        self.assertEqual(
            ["missing-cross-file-ref"],
            [item["code"] for item in report["errors"]],
        )
        self.assertFalse(report["required_refs"][0]["covered"])

        application.write_text(
            "= Application\n#theorem(title: [#kn[completion theorem]])["
            "By #ref[$sigma$-algebra], a completion exists.]\n",
            encoding="utf-8",
        )
        state, _, _ = self.sync(files=[Path(application_authority)])
        report = knowledge.curation_report(state, {application_authority})
        self.assertEqual([], report["errors"])
        self.assertTrue(report["required_refs"][0]["covered"])


if __name__ == "__main__":
    unittest.main()
