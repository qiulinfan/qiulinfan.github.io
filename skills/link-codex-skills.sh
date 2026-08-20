#!/bin/sh

set -eu

skills_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$skills_repo_dir/.." && pwd)
codex_root=${CODEX_HOME:-"$HOME/.codex"}
codex_skills_dir="$codex_root/skills"
codex_agents_file="$codex_root/AGENTS.md"
global_agents_source="$repo_root/install/codex/AGENTS.md"
legacy_lock_bridge="$skills_repo_dir/.skills_store_lock.json"
backup_stamp=$(date '+%Y%m%d-%H%M%S')
backup_dir="$codex_root/skill-layout-backups/$backup_stamp"
backup_ready=false

mkdir -p "$codex_root"
[ -f "$global_agents_source" ] || {
  printf 'missing tracked global guidance: %s\n' "$global_agents_source" >&2
  exit 1
}

ensure_backup_dir() {
  if [ "$backup_ready" = true ]; then
    return
  fi
  if [ -e "$backup_dir" ]; then
    backup_dir="$backup_dir-$$"
  fi
  mkdir -p "$backup_dir"
  backup_ready=true
}

backup_entry() {
  source_path=$1
  backup_name=$2
  ensure_backup_dir
  mv "$source_path" "$backup_dir/$backup_name"
  printf 'backup: %s -> %s\n' "$source_path" "$backup_dir/$backup_name"
}

ensure_real_codex_skills_dir() {
  if [ -L "$codex_skills_dir" ]; then
    linked_target=$(realpath "$codex_skills_dir" 2>/dev/null || true)
    [ "$linked_target" = "$(realpath "$skills_repo_dir")" ] || {
      printf 'conflict: %s points to %s\n' "$codex_skills_dir" "$(readlink "$codex_skills_dir")" >&2
      exit 1
    }
    unlink "$codex_skills_dir"
    mkdir "$codex_skills_dir"
    printf 'migrated: %s is now a Codex-owned directory\n' "$codex_skills_dir"
  elif [ -e "$codex_skills_dir" ]; then
    [ -d "$codex_skills_dir" ] || {
      printf 'conflict: %s exists and is not a directory\n' "$codex_skills_dir" >&2
      exit 1
    }
  else
    mkdir "$codex_skills_dir"
    printf 'created: %s\n' "$codex_skills_dir"
  fi

}

reject_repository_system_skills() {
  { [ ! -L "$skills_repo_dir/.system" ] && [ ! -e "$skills_repo_dir/.system" ]; } || {
    printf 'conflict: Codex-generated .system must not exist in this repository: %s\n' "$skills_repo_dir/.system" >&2
    exit 1
  }
}

remove_legacy_lock_bridge() {
  if [ -L "$legacy_lock_bridge" ]; then
    unlink "$legacy_lock_bridge"
    printf 'removed legacy link: %s\n' "$legacy_lock_bridge"
  elif [ -e "$legacy_lock_bridge" ]; then
    printf 'conflict: %s exists and is not a symlink\n' "$legacy_lock_bridge" >&2
    exit 1
  fi
}

ensure_global_agents_link() {
  if [ -L "$codex_agents_file" ]; then
    [ "$(realpath "$codex_agents_file")" = "$(realpath "$global_agents_source")" ] || {
      printf 'conflict: %s points to %s\n' "$codex_agents_file" "$(readlink "$codex_agents_file")" >&2
      exit 1
    }
  elif [ -e "$codex_agents_file" ]; then
    [ -f "$codex_agents_file" ] && cmp -s "$codex_agents_file" "$global_agents_source" || {
      printf 'conflict: existing global guidance differs: %s\n' "$codex_agents_file" >&2
      exit 1
    }
    backup_entry "$codex_agents_file" AGENTS.md-before-link
    ln -s "$global_agents_source" "$codex_agents_file"
  else
    ln -s "$global_agents_source" "$codex_agents_file"
  fi
  printf 'ok: %s -> %s\n' "$codex_agents_file" "$global_agents_source"
}

skill_manifests() {
  (
    cd "$skills_repo_dir"
    find . -type f -name SKILL.md ! -path '*/.*/*' -print | LC_ALL=C sort
  )
}

# Runtime scope is declared by directory, not by name: Skills under
# skills/claude-only/ depend on Claude Code-only capabilities and stay linked
# into Claude Code only.
is_claude_only_relative_manifest() {
  case "${1#./}" in
    claude-only/*) return 0 ;;
  esac
  return 1
}

eligible_manifests() {
  skill_manifests | while IFS= read -r relative_manifest; do
    if is_claude_only_relative_manifest "$relative_manifest"; then
      continue
    fi
    printf '%s\n' "$relative_manifest"
  done
}

skipped_manifests() {
  skill_manifests | while IFS= read -r relative_manifest; do
    if is_claude_only_relative_manifest "$relative_manifest"; then
      printf '%s\n' "$relative_manifest"
    fi
  done
}

check_flat_skill_names() {
  duplicate_names=$(
    eligible_manifests |
      awk -F/ '{ print $(NF - 1) }' |
      LC_ALL=C sort |
      uniq -d
  )
  [ -z "$duplicate_names" ] || {
    printf 'conflict: duplicate Skill directory names cannot be flattened:\n%s\n' "$duplicate_names" >&2
    exit 1
  }

  duplicate_metadata_names=$(
    eligible_manifests | while IFS= read -r relative_manifest; do
      sed -n 's/^name:[[:space:]]*//p' "$skills_repo_dir/${relative_manifest#./}" | head -n 1
    done | LC_ALL=C sort | uniq -d
  )
  [ -z "$duplicate_metadata_names" ] || {
    printf 'conflict: duplicate Skill names are ambiguous:\n%s\n' "$duplicate_metadata_names" >&2
    exit 1
  }
}

remove_stale_repository_skill_links() {
  for existing in "$codex_skills_dir"/*; do
    [ -L "$existing" ] || continue
    link_target=$(readlink "$existing")
    case "$link_target" in
      "$skills_repo_dir"/*)
        relative_target=${link_target#"$skills_repo_dir"/}
        if [ ! -f "$link_target/SKILL.md" ] ||
          is_claude_only_relative_manifest "$relative_target/SKILL.md"; then
          unlink "$existing"
          printf 'removed stale repository Skill link: %s\n' "$existing"
        fi
        ;;
    esac
  done
}

link_visible_skills() {
  linked_count=$(eligible_manifests | wc -l | tr -d ' ')
  eligible_manifests | while IFS= read -r relative_manifest; do
    [ -n "$relative_manifest" ] || continue
    manifest="$skills_repo_dir/${relative_manifest#./}"
    source_dir=${manifest%/SKILL.md}
    entry_name=$(basename "$source_dir")
    destination="$codex_skills_dir/$entry_name"

    if [ -L "$destination" ]; then
      [ "$(realpath "$destination")" = "$(realpath "$source_dir")" ] || {
        printf 'conflict: %s points to %s\n' "$destination" "$(readlink "$destination")" >&2
        exit 1
      }
    elif [ -e "$destination" ]; then
      [ -d "$destination" ] && diff -qr "$destination" "$source_dir" >/dev/null 2>&1 || {
        printf 'conflict: existing Skill differs from repository authority: %s\n' "$destination" >&2
        exit 1
      }
      backup_entry "$destination" "skill-$entry_name-before-link"
      ln -s "$source_dir" "$destination"
    else
      ln -s "$source_dir" "$destination"
    fi
  done

  printf 'ok: linked %s eligible repository Skills into %s\n' "$linked_count" "$codex_skills_dir"
}

report_skipped_skills() {
  skipped_list=$(skipped_manifests)
  [ -n "$skipped_list" ] || return 0
  skipped_count=$(printf '%s\n' "$skipped_list" | wc -l | tr -d ' ')
  printf 'skipped %s Claude Code-only Skill(s), linked into Claude Code only:\n' "$skipped_count"
  printf '%s\n' "$skipped_list" | sed -e 's|^\./||' -e 's|/SKILL.md$||' -e 's|^|  |'
}

reject_repository_system_skills
ensure_real_codex_skills_dir
remove_legacy_lock_bridge
ensure_global_agents_link
check_flat_skill_names
remove_stale_repository_skill_links
link_visible_skills
report_skipped_skills
