from __future__ import annotations

import importlib.util
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[4]
MODULE_PATH = REPO_ROOT / "notes/math/knowledge/scripts/knowledge.py"
SPEC = importlib.util.spec_from_file_location("ql_knowledge", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
knowledge = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = knowledge
SPEC.loader.exec_module(knowledge)


class KnowledgeGraphTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="qlkg-test-")
        self.repo = Path(self.temporary.name)
        authority = self.repo / "notes/math/demo/typst/main.typ"
        markdown = self.repo / "notes/math/demo/exports/main/markdown/main.md"
        authority.parent.mkdir(parents=True)
        markdown.parent.mkdir(parents=True)
        authority.write_text("= fixture\n", encoding="utf-8")
        shutil.copyfile(
            REPO_ROOT / "notes/math/knowledge/tests/fixtures/roundtrip.md",
            markdown,
        )
        self.source = knowledge.SourceSpec("math:demo:main", authority, (markdown,))

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_roundtrip_fixture_builds_typed_graph(self) -> None:
        compiler = knowledge.compile_graph(self.repo, [self.source])
        self.assertEqual([], compiler.errors)
        counts = {}
        for node in compiler.nodes.values():
            counts[node["type"]] = counts.get(node["type"], 0) + 1
        self.assertEqual(3, counts["statement"])
        self.assertEqual(7, counts["concept"])
        self.assertEqual(1, counts["figure"])
        self.assertEqual(1, counts["citation"])
        self.assertIn(
            (
                "concept:random-variable",
                "prerequisite-for",
                "concept:joint-distribution",
                "derived-authored",
                "statement:math:demo:main#def-joint-support",
            ),
            compiler.edges,
        )

    def test_artifacts_are_deterministic_and_searchable(self) -> None:
        first = knowledge.compile_graph(self.repo, [self.source])
        second = knowledge.compile_graph(self.repo, [self.source])
        self.assertEqual(knowledge.graph_artifacts(first), knowledge.graph_artifacts(second))

        database = self.repo / "notes/math/knowledge/build/knowledge.sqlite"
        knowledge.write_database(database, first)
        results = knowledge.search_database(database, "joint support", limit=5)
        ids = {item["id"] for item in results}
        self.assertIn("statement:math:demo:main#def-joint-support", ids)

    def test_search_index_rebuilds_from_committed_graph(self) -> None:
        compiler = knowledge.compile_graph(self.repo, [self.source])
        output = self.repo / "notes/math/knowledge/graph"
        database = self.repo / "notes/math/knowledge/build/knowledge.sqlite"
        knowledge.write_artifacts(output, knowledge.graph_artifacts(compiler))
        knowledge.ensure_database(output, database)
        results = knowledge.search_database(database, "probability bound", limit=5)
        self.assertTrue(any(item["id"] == "concept:probability-bound" for item in results))

    def test_semantic_count_mismatch_is_rejected(self) -> None:
        text = self.source.markdown[0].read_text(encoding="utf-8")
        self.source.markdown[0].write_text(
            text.replace("semantic-node-count: 3", "semantic-node-count: 4"),
            encoding="utf-8",
        )
        compiler = knowledge.compile_graph(self.repo, [self.source])
        codes = {error.code for error in compiler.errors}
        self.assertIn("semantic-count-mismatch", codes)

    def test_manifest_has_content_hash_and_no_timestamp(self) -> None:
        compiler = knowledge.compile_graph(self.repo, [self.source])
        manifest = json.loads(knowledge.graph_artifacts(compiler)["manifest.json"])
        self.assertEqual("qlkg-v1", manifest["schema"])
        self.assertRegex(manifest["graph_sha256"], r"^[0-9a-f]{64}$")
        self.assertNotIn("generated_at", manifest)

    def test_source_registry_expands_bounded_markdown_glob(self) -> None:
        registry = self.repo / "notes/math/knowledge/sources.json"
        registry.parent.mkdir(parents=True)
        registry.write_text(
            json.dumps(
                {
                    "schema": "qlkg-sources-v1",
                    "sources": [
                        {
                            "id": "math:demo:main",
                            "authority": "notes/math/demo/typst/main.typ",
                            "markdown": "notes/math/demo/exports/main/markdown/*.md",
                        }
                    ],
                }
            ),
            encoding="utf-8",
        )
        sources = knowledge.load_sources(self.repo, registry)
        self.assertEqual(
            (self.source.markdown[0].resolve(),),
            tuple(path.resolve() for path in sources[0].markdown),
        )


if __name__ == "__main__":
    unittest.main()
