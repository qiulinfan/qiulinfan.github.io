#!/bin/sh

set -eu

skills_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
codex_root=${CODEX_HOME:-"$HOME/.codex"}
codex_skills_dir="$codex_root/skills"
repo_system_dir="$skills_repo_dir/.system"
codex_system_dir="$codex_root/system-skills"
lock_store="$codex_root/skills-store-lock.json"
backup_stamp=$(date '+%Y%m%d-%H%M%S')
backup_dir="$codex_root/skill-layout-backups/$backup_stamp"

mkdir -p "$codex_root"

repo_dir_for_name() {
  requested_name=$1
  for skill_file in "$skills_repo_dir"/*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    candidate_name=$(sed -n 's/^name:[[:space:]]*//p' "$skill_file" | head -n 1)
    if [ "$candidate_name" = "$requested_name" ]; then
      printf '%s\n' "${skill_file%/SKILL.md}"
      return 0
    fi
  done
  return 1
}

ensure_system_store_link() {
  if [ -L "$repo_system_dir" ]; then
    repo_system_target=$(realpath "$repo_system_dir" 2>/dev/null || true)
    codex_system_target=$(realpath "$codex_system_dir" 2>/dev/null || true)
    [ -n "$repo_system_target" ] && [ "$repo_system_target" = "$codex_system_target" ] || {
      printf 'conflict: %s points outside %s\n' "$repo_system_dir" "$codex_system_dir" >&2
      exit 1
    }
    [ -d "$codex_system_dir" ] && [ ! -L "$codex_system_dir" ] || {
      printf 'conflict: cannot migrate %s because %s is not a real directory\n' "$repo_system_dir" "$codex_system_dir" >&2
      exit 1
    }

    mkdir -p "$backup_dir"
    cp -a "$codex_system_dir" "$backup_dir/system-skills-before"
    rm "$repo_system_dir"
    mv "$codex_system_dir" "$repo_system_dir"
    printf 'migrated: %s is now repository-managed\n' "$repo_system_dir"
    printf 'backup: %s\n' "$backup_dir"
  elif [ -e "$repo_system_dir" ]; then
    [ -d "$repo_system_dir" ] || {
      printf 'conflict: %s exists and is not a directory\n' "$repo_system_dir" >&2
      exit 1
    }
  elif [ -d "$codex_system_dir" ] && [ ! -L "$codex_system_dir" ]; then
    mkdir -p "$backup_dir"
    cp -a "$codex_system_dir" "$backup_dir/system-skills-before"
    mv "$codex_system_dir" "$repo_system_dir"
    printf 'migrated: %s is now repository-managed\n' "$repo_system_dir"
    printf 'backup: %s\n' "$backup_dir"
  else
    printf 'conflict: repository system skill store is missing: %s\n' "$repo_system_dir" >&2
    exit 1
  fi

  if [ -L "$codex_system_dir" ]; then
    [ "$(realpath "$codex_system_dir")" = "$(realpath "$repo_system_dir")" ] || {
      printf 'conflict: %s points to the wrong system skill store\n' "$codex_system_dir" >&2
      exit 1
    }
  elif [ -e "$codex_system_dir" ]; then
    [ -d "$codex_system_dir" ] || {
      printf 'conflict: %s exists and is not a directory\n' "$codex_system_dir" >&2
      exit 1
    }
    mkdir -p "$backup_dir"
    mv "$codex_system_dir" "$backup_dir/system-skills-replaced"
    ln -s "$repo_system_dir" "$codex_system_dir"
    if ! diff -qr "$backup_dir/system-skills-replaced" "$repo_system_dir" >/dev/null 2>&1; then
      printf 'notice: replaced divergent local system skills with the repository version\n'
    fi
    printf 'linked: %s -> %s\n' "$codex_system_dir" "$repo_system_dir"
    printf 'backup: %s\n' "$backup_dir"
  else
    ln -s "$repo_system_dir" "$codex_system_dir"
    printf 'linked: %s -> %s\n' "$codex_system_dir" "$repo_system_dir"
  fi
}

ensure_managed_bridges() {
  ensure_system_store_link

  if [ -f "$lock_store" ]; then
    if [ -L "$skills_repo_dir/.skills_store_lock.json" ]; then
      [ "$(realpath "$skills_repo_dir/.skills_store_lock.json")" = "$(realpath "$lock_store")" ] || {
        printf 'conflict: %s points to the wrong lock store\n' "$skills_repo_dir/.skills_store_lock.json" >&2
        exit 1
      }
    elif [ -e "$skills_repo_dir/.skills_store_lock.json" ]; then
      printf 'conflict: %s is not a symlink\n' "$skills_repo_dir/.skills_store_lock.json" >&2
      exit 1
    else
      ln -s "$lock_store" "$skills_repo_dir/.skills_store_lock.json"
    fi
  fi
}

if [ -L "$codex_skills_dir" ]; then
  if [ "$(realpath "$codex_skills_dir")" != "$(realpath "$skills_repo_dir")" ]; then
    printf 'conflict: %s points to %s\n' "$codex_skills_dir" "$(readlink "$codex_skills_dir")" >&2
    exit 1
  fi
  ensure_managed_bridges
  printf 'ok: %s -> %s\n' "$codex_skills_dir" "$skills_repo_dir"
  exit 0
fi

if [ -e "$codex_skills_dir" ]; then
  [ -d "$codex_skills_dir" ] || {
    printf 'conflict: %s exists and is not a directory\n' "$codex_skills_dir" >&2
    exit 1
  }

  had_conflict=false
  find "$codex_skills_dir" -mindepth 1 -maxdepth 1 -print | while IFS= read -r existing; do
    entry_name=$(basename "$existing")
    case "$entry_name" in
      .system|.skills_store_lock.json) continue ;;
    esac

    if [ -L "$existing" ]; then
      resolved=$(realpath "$existing" 2>/dev/null || true)
      case "$resolved" in
        "$skills_repo_dir"/*) continue ;;
      esac
      printf 'conflict: external skill link %s -> %s\n' "$existing" "$(readlink "$existing")" >&2
      exit 20
    fi

    if [ -d "$existing" ] && [ -f "$existing/SKILL.md" ]; then
      skill_name=$(sed -n 's/^name:[[:space:]]*//p' "$existing/SKILL.md" | head -n 1)
      repo_skill=$(repo_dir_for_name "$skill_name" || true)
      if [ -n "$repo_skill" ] && diff -qr "$existing" "$repo_skill" >/dev/null 2>&1; then
        continue
      fi
    fi

    printf 'conflict: untracked or divergent entry %s\n' "$existing" >&2
    exit 20
  done || had_conflict=true

  [ "$had_conflict" = false ] || exit 1

  mkdir -p "$backup_dir"
  cp -a "$codex_skills_dir" "$backup_dir/skills-before"

  if [ -d "$codex_skills_dir/.system" ] && [ ! -L "$codex_skills_dir/.system" ]; then
    if [ -e "$repo_system_dir" ]; then
      diff -qr "$codex_skills_dir/.system" "$repo_system_dir" >/dev/null 2>&1 || {
        printf 'conflict: legacy system skills differ from %s\n' "$repo_system_dir" >&2
        exit 1
      }
    else
      cp -a "$codex_skills_dir/.system" "$repo_system_dir"
    fi
  fi

  if [ -f "$codex_skills_dir/.skills_store_lock.json" ] && [ ! -L "$codex_skills_dir/.skills_store_lock.json" ]; then
    if [ -e "$lock_store" ]; then
      cmp -s "$codex_skills_dir/.skills_store_lock.json" "$lock_store" || {
        printf 'conflict: skill store lock differs from %s\n' "$lock_store" >&2
        exit 1
      }
    else
      mv "$codex_skills_dir/.skills_store_lock.json" "$lock_store"
    fi
  fi

  mv "$codex_skills_dir" "$backup_dir/skills-old-layout"
  printf 'backup: %s\n' "$backup_dir"
fi

ensure_managed_bridges
ln -s "$skills_repo_dir" "$codex_skills_dir"
printf 'linked: %s -> %s\n' "$codex_skills_dir" "$skills_repo_dir"
