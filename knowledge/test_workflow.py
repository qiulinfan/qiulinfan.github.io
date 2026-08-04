from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from knowledge.workflow import POLICY_SCHEMA, WorkflowError, evaluate_workflow, load_policy
from kgdistiller.cli import load_sources


class KnowledgeWorkflowTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory(prefix="qlblog-workflow-test-")
        self.root = Path(self.temporary.name)
        source = self.root / "notes/demo"
        source.mkdir(parents=True)
        self.registered = source / "chapter.md"
        self.registered.write_text("--[[Known]]--", encoding="utf-8")
        self.legacy = self.root / "notes/legacy.md"
        self.legacy.write_text("legacy", encoding="utf-8")
        self.ignored = self.root / "notes/toolchain/runtime.typ"
        self.ignored.parent.mkdir(parents=True)
        self.ignored.write_text("runtime", encoding="utf-8")
        self.registry = self.root / "knowledge/sources.json"
        self.registry.parent.mkdir(parents=True)
        self.registry.write_text(
            json.dumps(
                {
                    "schema": "qlkg-sources-v2",
                    "fields": [{"id": "demo", "label": "Demo", "text": ""}],
                    "sources": [
                        {
                            "id": "demo:notes",
                            "subject": "demo",
                            "course": "notes",
                            "fields": ["demo"],
                            "root": "notes/demo",
                            "files": ["*.md"],
                            "web": "",
                            "topics": [],
                        }
                    ],
                }
            ),
            encoding="utf-8",
        )
        self.policy_path = self.root / "knowledge/workflow-policy.json"
        self.policy_path.write_text(
            json.dumps(
                {
                    "schema": POLICY_SCHEMA,
                    "ignored": [
                        {"glob": "notes/toolchain/**", "reason": "test runtime"}
                    ],
                    "legacy_unregistered": ["notes/legacy.md"],
                    "legacy_pending_authorities": ["notes/demo/chapter.md"],
                }
            ),
            encoding="utf-8",
        )
        self.policy = load_policy(self.policy_path)
        self.specs = load_sources(self.root, self.registry)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def evaluate(self, candidates: list[str], changed: list[str]) -> dict:
        return evaluate_workflow(
            self.root,
            self.specs,
            self.policy,
            candidates,
            changed,
        )

    def test_each_supported_file_has_one_explicit_classification(self) -> None:
        report = self.evaluate(
            [
                "notes/demo/chapter.md",
                "notes/legacy.md",
                "notes/toolchain/runtime.typ",
            ],
            [],
        )

        self.assertEqual([], report["errors"])
        self.assertEqual([], report["curate"])
        self.assertEqual(1, report["registered"])
        self.assertEqual(1, report["ignored"])

    def test_new_unregistered_note_is_rejected(self) -> None:
        report = self.evaluate(
            ["notes/demo/chapter.md", "notes/legacy.md", "notes/new.md"],
            ["notes/new.md"],
        )

        self.assertTrue(any("unregistered authority candidate" in item for item in report["errors"]))

    def test_changed_legacy_note_must_enter_registered_workflow(self) -> None:
        report = self.evaluate(
            ["notes/demo/chapter.md", "notes/legacy.md"],
            ["notes/legacy.md"],
        )

        self.assertTrue(any("changed legacy note" in item for item in report["errors"]))

    def test_changed_pending_authority_is_forced_through_curation(self) -> None:
        report = self.evaluate(
            ["notes/demo/chapter.md", "notes/legacy.md"],
            ["notes/demo/chapter.md"],
        )

        self.assertEqual(["notes/demo/chapter.md"], report["curate"])

    def test_policy_rejects_unsafe_paths(self) -> None:
        payload = json.loads(self.policy_path.read_text(encoding="utf-8"))
        payload["legacy_unregistered"] = ["../outside.md"]
        self.policy_path.write_text(json.dumps(payload), encoding="utf-8")

        with self.assertRaises(WorkflowError):
            load_policy(self.policy_path)


if __name__ == "__main__":
    unittest.main()
