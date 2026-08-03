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
                            "files": ["chapters/*.typ"],
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


if __name__ == "__main__":
    unittest.main()
