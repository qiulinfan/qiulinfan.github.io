#!/bin/sh

set -eu

skills_repo_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=$(CDPATH= cd -- "$skills_repo_dir/.." && pwd)
claude_root=${CLAUDE_CONFIG_DIR:-"$HOME/.claude"}
claude_skills_dir="$claude_root/skills"
claude_guidance_file="$claude_root/CLAUDE.md"
global_guidance_source="$repo_root/install/claude/CLAUDE.md"
linked_repositories_file=${QLBLOG_LINKED_SKILL_REPOSITORIES_FILE:-"$skills_repo_dir/linked-skill-repositories.tsv"}
linked_state_file="$claude_root/.qlblog-linked-skill-targets"
legacy_private_state_file="$claude_root/.qlblog-private-skill-targets"
backup_stamp=$(date '+%Y%m%d-%H%M%S')
backup_dir="$claude_root/skill-layout-backups/$backup_stamp"
backup_ready=false

mkdir -p "$claude_root"
[ -f "$global_guidance_source" ] || {
  printf 'missing tracked global guidance: %s\n' "$global_guidance_source" >&2
  printf 'run install/agents/build-guidance.sh first\n' >&2
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

ensure_real_claude_skills_dir() {
  if [ -L "$claude_skills_dir" ]; then
    linked_target=$(realpath "$claude_skills_dir" 2>/dev/null || true)
    [ "$linked_target" = "$(realpath "$skills_repo_dir")" ] || {
      printf 'conflict: %s points to %s\n' "$claude_skills_dir" "$(readlink "$claude_skills_dir")" >&2
      exit 1
    }
    unlink "$claude_skills_dir"
    mkdir "$claude_skills_dir"
    printf 'migrated: %s is now a Claude Code-owned directory\n' "$claude_skills_dir"
  elif [ -e "$claude_skills_dir" ]; then
    [ -d "$claude_skills_dir" ] || {
      printf 'conflict: %s exists and is not a directory\n' "$claude_skills_dir" >&2
      exit 1
    }
  else
    mkdir "$claude_skills_dir"
    printf 'created: %s\n' "$claude_skills_dir"
  fi
}

reject_repository_system_skills() {
  { [ ! -L "$skills_repo_dir/.system" ] && [ ! -e "$skills_repo_dir/.system" ]; } || {
    printf 'conflict: generated .system must not exist in this repository: %s\n' "$skills_repo_dir/.system" >&2
    exit 1
  }
}

ensure_global_guidance_link() {
  if [ -L "$claude_guidance_file" ]; then
    [ "$(realpath "$claude_guidance_file")" = "$(realpath "$global_guidance_source")" ] || {
      printf 'conflict: %s points to %s\n' "$claude_guidance_file" "$(readlink "$claude_guidance_file")" >&2
      exit 1
    }
  elif [ -e "$claude_guidance_file" ]; then
    [ -f "$claude_guidance_file" ] && cmp -s "$claude_guidance_file" "$global_guidance_source" || {
      printf 'conflict: existing global guidance differs: %s\n' "$claude_guidance_file" >&2
      exit 1
    }
    backup_entry "$claude_guidance_file" CLAUDE.md-before-link
    ln -s "$global_guidance_source" "$claude_guidance_file"
  else
    ln -s "$global_guidance_source" "$claude_guidance_file"
  fi
  printf 'ok: %s -> %s\n' "$claude_guidance_file" "$global_guidance_source"
}

# Runtime scope is declared by directory, not by name: Skills under
# skills/codex-only/ depend on Codex-only capabilities (Codex-native subagents
# or Codex-selected external runtimes) and stay linked into Codex only.
is_codex_only_relative_dir() {
  case "$1" in
    codex-only/*) return 0 ;;
  esac
  return 1
}

skill_relative_dirs() {
  (
    cd "$skills_repo_dir"
    find . -type f -name SKILL.md ! -path '*/.*/*' -print |
      LC_ALL=C sort |
      while IFS= read -r manifest; do
        relative_dir=${manifest#./}
        printf '%s\n' "${relative_dir%/SKILL.md}"
      done
  )
}

eligible_relative_dirs=$(
  skill_relative_dirs | while IFS= read -r relative_dir; do
    if is_codex_only_relative_dir "$relative_dir"; then
      continue
    fi
    printf '%s\n' "$relative_dir"
  done
)
skipped_relative_dirs=$(
  skill_relative_dirs | while IFS= read -r relative_dir; do
    if is_codex_only_relative_dir "$relative_dir"; then
      printf '%s\n' "$relative_dir"
    fi
  done
)

count_lines() {
  if [ -z "$1" ]; then
    printf '0\n'
  else
    printf '%s\n' "$1" | wc -l | tr -d ' '
  fi
}

eligible_targets() {
  [ -n "$eligible_relative_dirs" ] || return 0
  printf '%s\n' "$eligible_relative_dirs" | while IFS= read -r relative_dir; do
    printf '%s/%s\n' "$skills_repo_dir" "$relative_dir"
  done
}

linked_skill_roots() {
  [ -f "$linked_repositories_file" ] || {
    printf 'missing linked-only Skill repository registry: %s\n' "$linked_repositories_file" >&2
    exit 1
  }

  tab=$(printf '\t')
  while IFS="$tab" read -r repository_name clone_url checkout_path skill_root extra ||
    [ -n "$repository_name$clone_url$checkout_path$skill_root$extra" ]; do
    repository_name=$(printf '%s' "$repository_name" | sed -e 's/\r$//' -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    case "$repository_name" in
      ''|'#'*) continue ;;
    esac
    [ -n "$clone_url" ] && [ -n "$checkout_path" ] && [ -n "$skill_root" ] && [ -z "$extra" ] || {
      printf 'invalid linked-only Skill registry row for %s: expected four tab-separated fields\n' "$repository_name" >&2
      exit 1
    }
    case "$checkout_path" in
      /*|'~'|'~/'*)
        printf 'linked-only Skill checkout must be relative to qlblog: %s\n' "$checkout_path" >&2
        exit 1
        ;;
    esac
    checkout_root="$repo_root/$checkout_path"
    candidate_root="$checkout_root/$skill_root"
    [ -d "$candidate_root" ] || {
      printf 'linked-only Skill repository is not checked out: %s\n' "$repository_name" >&2
      printf 'clone %s into %s, then rerun this linker\n' "$clone_url" "$checkout_root" >&2
      exit 1
    }
    resolved_root=$(CDPATH= cd -- "$candidate_root" && pwd -P)
    case "$resolved_root" in
      "$skills_repo_dir"|"$skills_repo_dir"/*)
        printf 'linked-only Skill root must be outside qlblog skills/: %s\n' "$resolved_root" >&2
        exit 1
        ;;
    esac
    printf '%s\n' "$resolved_root"
  done < "$linked_repositories_file"
}

linked_eligible_targets() {
  linked_skill_roots | while IFS= read -r linked_root; do
    [ -n "$linked_root" ] || continue
    (
      cd "$linked_root"
      find . -type f -name SKILL.md ! -path '*/.*/*' -print | LC_ALL=C sort
    ) | while IFS= read -r relative_manifest; do
      relative_dir=${relative_manifest#./}
      relative_dir=${relative_dir%/SKILL.md}
      case "$relative_dir" in
        codex-only/*) continue ;;
      esac
      if [ -n "$relative_dir" ]; then
        printf '%s/%s\n' "$linked_root" "$relative_dir"
      else
        printf '%s\n' "$linked_root"
      fi
    done
  done
}

all_eligible_targets() {
  eligible_targets
  linked_eligible_targets
}

check_flat_skill_names() {
  all_targets=$(all_eligible_targets)
  [ -n "$all_targets" ] || return 0

  duplicate_names=$(
    printf '%s\n' "$all_targets" |
      sed 's|.*/||' |
      LC_ALL=C sort |
      uniq -d
  )
  [ -z "$duplicate_names" ] || {
    printf 'conflict: duplicate Skill directory names cannot be flattened:\n%s\n' "$duplicate_names" >&2
    exit 1
  }

  duplicate_metadata_names=$(
    printf '%s\n' "$all_targets" | while IFS= read -r source_dir; do
      metadata_name=$(sed -n 's/^name:[[:space:]]*//p' "$source_dir/SKILL.md" | head -n 1)
      [ -n "$metadata_name" ] || {
        printf 'conflict: Skill is missing frontmatter name: %s\n' "$source_dir/SKILL.md" >&2
        exit 1
      }
      printf '%s\n' "$metadata_name"
    done | LC_ALL=C sort | uniq -d
  )
  [ -z "$duplicate_metadata_names" ] || {
    printf 'conflict: duplicate Skill names are ambiguous:\n%s\n' "$duplicate_metadata_names" >&2
    exit 1
  }
}

remove_stale_linked_skill_links() {
  [ -f "$linked_state_file" ] || return 0
  current_targets=$(linked_eligible_targets)
  while IFS= read -r old_target || [ -n "$old_target" ]; do
    [ -n "$old_target" ] || continue
    if printf '%s\n' "$current_targets" | grep -qxF -- "$old_target"; then
      continue
    fi
    destination="$claude_skills_dir/$(basename "$old_target")"
    [ -L "$destination" ] || continue
    raw_target=$(readlink "$destination")
    if [ "$raw_target" = "$old_target" ]; then
      unlink "$destination"
      printf 'removed stale registered linked-only Skill link: %s\n' "$destination"
    fi
  done < "$linked_state_file"
}

migrate_legacy_private_state() {
  if [ ! -e "$linked_state_file" ] && [ -f "$legacy_private_state_file" ]; then
    mv "$legacy_private_state_file" "$linked_state_file"
    printf 'migrated legacy private Skill link state: %s\n' "$linked_state_file"
  fi
}

# Drops links this repository owns that are stale, newly excluded by the
# codex-only filter, or renamed. Links owned by independent product checkouts
# and anything that is not a link are left untouched.
remove_unmanaged_repository_skill_links() {
  current_targets=$(eligible_targets)
  for existing in "$claude_skills_dir"/*; do
    [ -L "$existing" ] || continue
    link_target=$(readlink "$existing")
    case "$link_target" in
      "$skills_repo_dir"/*) ;;
      *) continue ;;
    esac
    if [ -f "$link_target/SKILL.md" ] &&
      [ "$(basename "$link_target")" = "$(basename "$existing")" ] &&
      printf '%s\n' "$current_targets" | grep -qxF -- "$link_target"; then
      continue
    fi
    unlink "$existing"
    printf 'removed qlblog Skill link that is no longer linked here: %s\n' "$existing"
  done
}

link_eligible_skills() {
  all_targets=$(all_eligible_targets)
  [ -n "$all_targets" ] || {
    printf 'ok: no eligible repository Skills to link into %s\n' "$claude_skills_dir"
    return
  }

  printf '%s\n' "$all_targets" | while IFS= read -r source_dir; do
    entry_name=$(basename "$source_dir")
    destination="$claude_skills_dir/$entry_name"

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

  printf 'ok: linked %s eligible repository Skills into %s\n' \
    "$(count_lines "$all_targets")" "$claude_skills_dir"
}

write_linked_skill_state() {
  temporary_state="$linked_state_file.tmp.$$"
  linked_eligible_targets > "$temporary_state"
  mv "$temporary_state" "$linked_state_file"
}

report_skipped_skills() {
  skipped_count=$(count_lines "$skipped_relative_dirs")
  [ "$skipped_count" != 0 ] || return 0
  printf 'skipped %s Codex-only Skill(s), still linked into Codex:\n' "$skipped_count"
  printf '%s\n' "$skipped_relative_dirs" | sed 's|^|  |'
}

linked_skill_roots >/dev/null
reject_repository_system_skills
ensure_real_claude_skills_dir
ensure_global_guidance_link
check_flat_skill_names
remove_unmanaged_repository_skill_links
migrate_legacy_private_state
remove_stale_linked_skill_links
link_eligible_skills
write_linked_skill_state
report_skipped_skills
