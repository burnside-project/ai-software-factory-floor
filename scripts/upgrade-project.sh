#!/usr/bin/env bash
# Sync the method (agents/workflows/skills/prompts/templates + the .claude layer)
# from THIS ai-software-factory checkout into an existing project's .ai/ (+ .claude/),
# then bump the project's pinned METHOD_VERSION.
#
# Re-runnable. Overwrites METHOD files only — it NEVER touches the project's
# specs/, tickets/, verification/, prs/, knowledge/, docs/ or code.
#
#   ./scripts/upgrade-project.sh /path/to/<project>-delivery
set -euo pipefail

# Resolve the factory root (the SOURCE of the method) from this script's own location
# (scripts/ -> ..), not $PWD, so upgrade works from any directory. Run from scripts/,
# the old $PWD-relative reads silently skipped every method dir (`[ -d "$d" ] || continue`)
# and still bumped METHOD_VERSION — an install that copies nothing but claims success.
# PROJECT_DIR (the TARGET) stays the operator-supplied path. Read-only `cd` subshell.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PROJECT_DIR="${1:-}"
[ -z "$PROJECT_DIR" ] && { echo "Usage: ./scripts/upgrade-project.sh /path/to/project"; exit 1; }
[ -d "$PROJECT_DIR/.ai" ] || { echo "error: $PROJECT_DIR/.ai not found — run bootstrap-project.sh first"; exit 1; }

TO="$(cat "$ROOT/VERSION" 2>/dev/null || echo '?')"
PIN="$PROJECT_DIR/.ai/METHOD_VERSION"
HAVE="$( [ -f "$PIN" ] && cat "$PIN" || echo 'none')"
echo "Upgrading $PROJECT_DIR  (method $HAVE -> $TO)"

# Method dirs are overwrite-safe (regenerated from this repo). Project artifacts
# are deliberately excluded from this list.
for d in agents workflows skills prompts templates; do
  [ -d "$ROOT/$d" ] || continue
  rm -rf "${PROJECT_DIR:?}/.ai/$d"
  cp -R "$ROOT/$d" "$PROJECT_DIR/.ai/"
done

# Native Claude Code layer (subagents + slash commands)
if [ -d "$ROOT/.claude" ]; then
  mkdir -p "$PROJECT_DIR/.claude"
  # agents ship whole (recursive, overwrite-safe).
  if [ -d "$ROOT/.claude/agents" ]; then
    rm -rf "${PROJECT_DIR:?}/.claude/agents"
    cp -R "$ROOT/.claude/agents" "$PROJECT_DIR/.claude/"
  fi
  # commands: rm -rf then rebuild from the TOP-LEVEL *.md set ONLY (ADR-0004 filter).
  # The rm -rf drops any previously-leaked provisioning command; the filtered rebuild
  # ships only the delivery pair (the provisioning/ subdir is never copied). Do NOT
  # cp -R the source commands dir — that would re-copy provisioning/.
  if [ -d "$ROOT/.claude/commands" ]; then
    rm -rf "${PROJECT_DIR:?}/.claude/commands"
    mkdir -p "$PROJECT_DIR/.claude/commands"
    for f in "$ROOT"/.claude/commands/*.md; do
      [ -e "$f" ] || continue
      cp "$f" "$PROJECT_DIR/.claude/commands/"
    done
  fi
fi

[ -f "$ROOT/VERSION" ] && cp "$ROOT/VERSION" "$PIN"
echo "done — .ai/ method synced; METHOD_VERSION now $TO"
echo "review the diff in $PROJECT_DIR before committing (method changes can alter agent/workflow behavior)."
