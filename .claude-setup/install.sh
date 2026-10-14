#!/usr/bin/env bash
# Install or update the shared Claude Code setup into the CIAS workspace root
# (the folder that contains cias-api/ and cias-web/).
#
#   cias-api/.claude-setup/install.sh              add missing files, never overwrite
#   cias-api/.claude-setup/install.sh --overwrite  also replace files that differ from the repo
#   add --dry-run to either to only list what would change
#   add --skip-mods to leave the Claude Code mods (cias-api/.claude-setup/mods/) alone
set -euo pipefail

usage() {
  echo "usage: $0 [--overwrite] [--dry-run] [--skip-mods]" >&2
  exit "${1:-0}"
}

overwrite=0
dry_run=0
skip_mods=0
for arg in "$@"; do
  case "$arg" in
    --overwrite) overwrite=1 ;;
    --dry-run) dry_run=1 ;;
    --skip-mods) skip_mods=1 ;;
    -h | --help) usage 0 ;;
    *) usage 2 ;;
  esac
done

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
src="$here/workspace"
root="$(cd "$here/../.." && pwd)" # .claude-setup -> cias-api -> workspace root

if [ "$(basename "$(dirname "$here")")" != "cias-api" ]; then
  echo "error: expected this script at <workspace>/cias-api/.claude-setup/" >&2
  exit 1
fi
[ -d "$root/cias-web" ] || echo "note: $root/cias-web not found — clone it next to cias-api"

opts=(-a --itemize-changes --exclude .DS_Store --exclude '.claude/')
[ "$overwrite" -eq 1 ] || opts+=(--ignore-existing)
[ "$dry_run" -eq 1 ] && opts+=(--dry-run)

echo "workspace root: $root"
rsync "${opts[@]}" --exclude dot-claude "$src/" "$root/"
rsync "${opts[@]}" "$src/dot-claude/" "$root/.claude/"

[ "$dry_run" -eq 1 ] || mkdir -p "$root/.claude/jira-tasks" "$root/.claude/knowledge-pills/_inbox"

# Mods: a folder marketplace read in place from this repo, so `git pull` + /reload-plugins
# updates them. Declared at local scope (.claude/settings.local.json of this workspace only).
install_mods() {
  local mods="$here/mods"
  local plugin="interlay-status"

  if [ "$dry_run" -eq 1 ]; then
    echo "would run: claude plugin marketplace add $mods --scope local"
    echo "would run: claude plugin install $plugin@cias-mods --scope local"
    return
  fi
  if ! command -v claude >/dev/null 2>&1; then
    echo "note: 'claude' not on PATH — install the mods later, from $root:"
    echo "  claude plugin marketplace add $mods --scope local"
    echo "  claude plugin install $plugin@cias-mods --scope local"
    return
  fi

  local other
  other="$(claude plugin list --json 2>/dev/null | grep -o "\"$plugin@[^\"]*\"" | tr -d '"' | grep -v "@cias-mods$" | head -1 || true)"
  if [ -n "$other" ]; then
    echo "note: $other is already installed — skipping $plugin@cias-mods so the status line isn't shown twice"
    return
  fi

  (
    cd "$root"
    claude plugin marketplace add "$mods" --scope local
    claude plugin install "$plugin@cias-mods" --scope local
  )
}

[ "$skip_mods" -eq 1 ] || install_mods

[ "$dry_run" -eq 1 ] || echo "done. Next: see cias-api/.claude-setup/README.md (prerequisites + first run)."
