#!/bin/sh

set -eu

skills_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
codex_root=${CODEX_HOME:-"$HOME/.codex"}
codex_skills_dir="$codex_root/skills"
backup_stamp=$(date '+%Y%m%d-%H%M%S')
backup_dir="$codex_root/skill-link-backups/$backup_stamp"
created_backup=false
had_conflict=false

mkdir -p "$codex_skills_dir"

for skill_file in "$skills_repo_dir"/*/SKILL.md; do
  [ -f "$skill_file" ] || continue

  repo_skill_dir=${skill_file%/SKILL.md}
  skill_name=$(sed -n 's/^name:[[:space:]]*//p' "$skill_file" | head -n 1)

  if [ -z "$skill_name" ]; then
    printf 'skip: missing name in %s\n' "$skill_file" >&2
    had_conflict=true
    continue
  fi

  link_path="$codex_skills_dir/$skill_name"

  if [ -L "$link_path" ]; then
    current_target=$(readlink "$link_path")
    if [ "$current_target" = "$repo_skill_dir" ]; then
      printf 'ok: %s\n' "$skill_name"
    else
      printf 'conflict: %s points to %s\n' "$link_path" "$current_target" >&2
      had_conflict=true
    fi
    continue
  fi

  if [ -e "$link_path" ]; then
    if ! diff -qr "$link_path" "$repo_skill_dir" >/dev/null 2>&1; then
      printf 'conflict: %s differs from %s\n' "$link_path" "$repo_skill_dir" >&2
      had_conflict=true
      continue
    fi

    if [ "$created_backup" = false ]; then
      mkdir -p "$backup_dir"
      created_backup=true
    fi
    mv "$link_path" "$backup_dir/$skill_name"
  fi

  ln -s "$repo_skill_dir" "$link_path"
  printf 'linked: %s -> %s\n' "$link_path" "$repo_skill_dir"
done

if [ "$created_backup" = true ]; then
  printf 'identical pre-link copies backed up at: %s\n' "$backup_dir"
fi

if [ "$had_conflict" = true ]; then
  exit 1
fi
