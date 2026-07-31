#!/bin/sh
set -eu

missing_formulae=""

if ! command -v python3 >/dev/null 2>&1; then
  missing_formulae="$missing_formulae python"
fi
if ! command -v typst >/dev/null 2>&1; then
  missing_formulae="$missing_formulae typst"
fi
if ! command -v pandoc >/dev/null 2>&1; then
  missing_formulae="$missing_formulae pandoc"
fi
if ! command -v rsvg-convert >/dev/null 2>&1; then
  missing_formulae="$missing_formulae librsvg"
fi
if ! command -v lualatex >/dev/null 2>&1 ||
  ! command -v latexmk >/dev/null 2>&1 ||
  ! command -v biber >/dev/null 2>&1; then
  missing_formulae="$missing_formulae texlive"
fi
if ! command -v rg >/dev/null 2>&1; then
  missing_formulae="$missing_formulae ripgrep"
fi

if [ -z "$missing_formulae" ]; then
  echo "QLNotes dependencies are already installed."
  exit 0
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Missing:$missing_formulae" >&2
  echo "Automatic setup currently supports Homebrew; install these commands with your system package manager." >&2
  exit 1
fi

# shellcheck disable=SC2086
brew install $missing_formulae
