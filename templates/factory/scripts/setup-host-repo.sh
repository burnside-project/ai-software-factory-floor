#!/usr/bin/env bash
# Step 0 of the factory rollout: give the delivery workspace a backed-up home and
# create the cross-cutting host repo (Epics/Briefs + the .ai method + the Project).
#
# This is the ONLY outward-facing step that publishes the workspace. It is
# idempotent-ish and prints what it will do; pass --apply to actually run.
#
#   scripts/setup-host-repo.sh            # dry run (prints the plan)
#   scripts/setup-host-repo.sh --apply    # create repo + push workspace
#
# Requires: gh (auth), git. Run from the workspace root or anywhere — paths are absolute.
set -euo pipefail

# SPEC-019 (TICKET-099): ORG comes from the compiled .factory/factory.env, never a home
# default. Source the runtime-env helper (sibling lib/), fill from config, then fail closed.
# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/factory-runtime-env.sh"
factory_load_config
factory_require ORG
HOST_REPO="${HOST_REPO:-roadmap}"
# Workspace root = the git top-level (the workspace is its own repo — step 3 pushes it).
# Derived from git, not fixed `../../../..` depth, so it survives layout changes and
# symlinks (audit finding N3). Override with WS=... if the script lives outside the repo.
WS="${WS:-$(git -C "$(dirname "$0")" rev-parse --show-toplevel 2>/dev/null || true)}"
[ -n "$WS" ] || { echo "error: not inside a git repo — cd into the delivery workspace, or set WS=/path/to/workspace" >&2; exit 1; }
APPLY="${1:-}"

say(){ printf '  %s\n' "$*"; }
echo "Host-repo bootstrap plan ($ORG/$HOST_REPO):"
say "workspace root : $WS"
say "1. create PRIVATE repo $ORG/$HOST_REPO (if absent)"
say "2. add it as git remote 'origin' on the workspace (currently: $(git -C "$WS" remote get-url origin 2>/dev/null || echo NONE))"
say "3. push all branches + tags  (backs up $(git -C "$WS" rev-list --count HEAD 2>/dev/null || echo '?') commits)"
say "4. cross-repo Epics + Briefs and the .ai/ method now live here; the org Project tracks across repos"

if [ "$APPLY" != "--apply" ]; then
  echo; echo "(dry run) re-run with --apply to execute."; exit 0
fi

# 1. create the repo if it doesn't exist
if ! gh repo view "$ORG/$HOST_REPO" >/dev/null 2>&1; then
  gh repo create "$ORG/$HOST_REPO" --private \
    --description "Burnside delivery: cross-repo Epics/Briefs, the .ai factory method, and the org Project."
  echo "created $ORG/$HOST_REPO"
else
  echo "$ORG/$HOST_REPO already exists"
fi

# 2/3. wire remote + push (does not overwrite an existing different origin)
cd "$WS"
if git remote get-url origin >/dev/null 2>&1; then
  echo "origin already set: $(git remote get-url origin) — not changing it"
else
  git remote add origin "git@github.com:$ORG/$HOST_REPO.git"
  echo "added origin -> $ORG/$HOST_REPO"
fi
git push -u origin --all
git push origin --tags
echo "workspace pushed. Delivery history is now backed up + visible."
