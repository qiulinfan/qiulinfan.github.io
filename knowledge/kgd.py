#!/usr/bin/env python3
"""Run the active kgdistiller checkout against this repository."""

from __future__ import annotations

import os
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
configured_source = os.environ.get("KGDISTILLER_SRC")
engine_candidates: list[Path] = []
if configured_source:
    engine_candidates.append(Path(configured_source).expanduser().resolve())
engine_candidates.extend(
    [
        REPO_ROOT.parent / "kgdistiller/src",
        REPO_ROOT / "vendor/kgdistiller/src",
    ]
)
ENGINE_SRC = next(
    (candidate for candidate in engine_candidates if (candidate / "kgdistiller").is_dir()),
    None,
)
if ENGINE_SRC is None:
    raise SystemExit(
        "kgdistiller is missing; set KGDISTILLER_SRC or run: "
        "git submodule update --init --remote --merge"
    )
sys.path.insert(0, str(ENGINE_SRC))

from kgdistiller.cli import main  # noqa: E402


if __name__ == "__main__":
    sys.argv[1:1] = [
        "--repo-root",
        str(REPO_ROOT),
        "--typst-registry",
        "notes/math/toolchain/generated/knowledge-registry.typ",
    ]
    raise SystemExit(main())
