#!/usr/bin/env bash
set -euo pipefail

ROOT="${SKILLS_GIT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
STAMP="$(date +%Y%m%d-%H%M%S)"
DRY_RUN=0

if [ "${1:-}" = "--dry-run" ]; then
  DRY_RUN=1
fi

say() {
  printf '%s\n' "$*"
}

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] %q' "$1"
    shift || true
    for arg in "$@"; do
      printf ' %q' "$arg"
    done
    printf '\n'
  else
    "$@"
  fi
}

ensure_dir() {
  local dir="$1"
  if [ "$DRY_RUN" -eq 1 ]; then
    [ -d "$dir" ] || say "[dry-run] mkdir -p $dir"
  else
    mkdir -p "$dir"
  fi
}

archive_runtime_backups() {
  local runtime_dir="$1"
  local backup_root="$HOME/.agent-skill-backups/$STAMP$(printf '%s' "$runtime_dir" | tr '/' '_')"
  [ -d "$runtime_dir" ] || return 0

  for backup in "$runtime_dir"/*.backup-*; do
    [ -e "$backup" ] || continue
    ensure_dir "$backup_root"
    run mv "$backup" "$backup_root/$(basename "$backup")"
    say "[ARCHIVE] $backup -> $backup_root/$(basename "$backup")"
  done
}

link_skill() {
  local src="$1"
  local dest_dir="$2"
  local name
  local dest
  name="$(basename "$src")"
  dest="$dest_dir/$name"

  [ -d "$src" ] || return 0
  ensure_dir "$dest_dir"

  if [ -L "$dest" ]; then
    local current
    current="$(readlink "$dest")"
    if [ "$current" = "$src" ]; then
      say "[OK] $dest -> $src"
      return 0
    fi
    run rm "$dest"
  elif [ -e "$dest" ]; then
    run mv "$dest" "$dest.backup-$STAMP"
  fi

  run ln -s "$src" "$dest"
  say "[LINK] $dest -> $src"
}

link_group() {
  local src_dir="$1"
  local dest_dir="$2"
  [ -d "$src_dir" ] || return 0
  for src in "$src_dir"/*; do
    [ -d "$src" ] || continue
    link_skill "$src" "$dest_dir"
  done
}

copy_skill() {
  local src="$1"
  local dest_dir="$2"
  local name
  local dest
  name="$(basename "$src")"
  dest="$dest_dir/$name"

  [ -d "$src" ] || return 0
  ensure_dir "$dest_dir"

  if [ -L "$dest" ] || [ -e "$dest" ]; then
    run rm -rf "$dest"
  fi

  run cp -R "$src" "$dest"
  say "[COPY] $dest <- $src"
}

copy_group() {
  local src_dir="$1"
  local dest_dir="$2"
  [ -d "$src_dir" ] || return 0
  for src in "$src_dir"/*; do
    [ -d "$src" ] || continue
    copy_skill "$src" "$dest_dir"
  done
}

COMMON="$ROOT/.agents/skills"
CLAUDE_ONLY="$ROOT/.claude/skills"
CODEX_ONLY="$ROOT/.codex/skills"

say "Skill source: $ROOT"

archive_runtime_backups "$HOME/.agents/skills"
archive_runtime_backups "$HOME/.claude/skills"
archive_runtime_backups "$HOME/.codex/skills"
archive_runtime_backups "$HOME/.cc-switch/skills"

# Hermes Agent does not recognize symlinked skills under ~/.agents/skills, so
# keep that runtime folder as real directories copied from the git source.
copy_group "$COMMON" "$HOME/.agents/skills"

link_group "$COMMON" "$HOME/.claude/skills"
link_group "$CLAUDE_ONLY" "$HOME/.claude/skills"

link_group "$COMMON" "$HOME/.codex/skills"
link_group "$CODEX_ONLY" "$HOME/.codex/skills"

link_group "$COMMON" "$HOME/.cc-switch/skills"
link_group "$CLAUDE_ONLY" "$HOME/.cc-switch/skills"
link_group "$CODEX_ONLY" "$HOME/.cc-switch/skills"

say "Done."
