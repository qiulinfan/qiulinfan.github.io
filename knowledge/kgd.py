#!/usr/bin/env python3
"""Run the pinned kgdistiller submodule against this repository."""

from __future__ import annotations

import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
ENGINE_SRC = REPO_ROOT / "vendor/kgdistiller/src"
if not ENGINE_SRC.is_dir():
    raise SystemExit(
        "kgdistiller submodule is missing; run: git submodule update --init --recursive"
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
