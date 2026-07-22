#!/usr/bin/env bash
# Create the org Project (v2) + the fields that make up the factory line.
# Idempotent: skips creation if a project with the same title already exists, and every
# field block is guarded by an existence check, so a re-run issues ZERO mutations.
# Requires: gh auth with 'project' scope (gh auth refresh -s project,read:org).
#
# THE STAGE CONTRACT (SPEC-016 / TICKET-067). The Stage options are NOT written here —
# they are derived from ../stage-map.tsv, the single source of truth shared with
# board-sync.sh, metrics.sh and setup-repo.sh. Change the vocabulary THERE, never here.
# Renaming a Projects v2 option does not migrate existing cards, and the upgrade path
# (provision.sh --upgrade) is additive-only: it can add a field or option but can never
# remove or retype one. Treat every addition as permanent.
set -euo pipefail

# --dry-run / plan mode (SPEC-019 TICKET-104): render the intended mutations and make ZERO GitHub
# mutation, so `factory provision` and `factory sync` can share ONE mutation path. Parse the flag
# up front; this script otherwise takes no positional arguments.
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    *) echo "error: unknown argument '$arg' (usage: setup-project.sh [--dry-run])" >&2; exit 1 ;;
  esac
done
# gh_mut — THE mutation guard. In dry-run it RENDERS the intended `gh` call and returns without
# mutating; otherwise it runs `gh` unchanged. READS (project list / field-list) are NEVER routed
# through it — they must run in BOTH modes to compute the plan.
gh_mut() { if [ "${DRY_RUN:-0}" = 1 ]; then printf 'would: gh %s\n' "$*"; else gh "$@"; fi; }

# SPEC-019 (TICKET-099): ORG/PROJECT come from the compiled .factory/factory.env, never a home
# default. Source the runtime-env helper (sibling lib/), fill from config, then fail closed.
# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/factory-runtime-env.sh"
factory_load_config
factory_require ORG PROJECT
TITLE="$PROJECT"

# Resolve the stage map from THIS script's location (scripts/ -> ..), never $PWD, so the
# script works from any directory and from a vendored .ai/templates/factory/ bundle.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE_MAP="$HERE/../stage-map.tsv"
[ -f "$STAGE_MAP" ] || { echo "::error::stage-map.tsv not found at $STAGE_MAP" >&2; exit 1; }

# Column 2, deduped, in file order == the board's Stage option order.
STAGE_OPTIONS="$(awk -F'\t' '!/^#/ && NF && $2!="" && !seen[$2]++ {printf "%s%s", sep, $2; sep=","} END{print ""}' "$STAGE_MAP")"
[ -n "$STAGE_OPTIONS" ] || { echo "::error::no Stage options derived from $STAGE_MAP" >&2; exit 1; }

num=$(gh project list --owner "$ORG" --format json \
      | jq -r --arg t "$TITLE" '.projects[] | select(.title==$t) | .number' | head -1)

if [ -z "$num" ]; then
  if [ "${DRY_RUN:-0}" = 1 ]; then
    # Render the create and use a placeholder number so the field plan below still renders. A read
    # of a placeholder project's field-list returns nothing, so every field classifies as "would
    # create" — exactly the plan for a brand-new board.
    printf 'would: gh %s\n' "project create --owner $ORG --title $TITLE"
    num="(dry-run)"
    echo "would create project (title \"$TITLE\")"
  else
    num=$(gh project create --owner "$ORG" --title "$TITLE" --format json | jq -r '.number')
    echo "created project #$num"
  fi
else
  echo "project #$num already exists"
fi

# has_field <name> -> 0 if the field already exists on the project
has_field() {
  # A not-yet-created project (dry-run placeholder) has NO fields — short-circuit to "absent" so the
  # plan renders "would create" without a wasted real `gh field-list` on the "(dry-run)" number
  # (it 404s; harmless here because this runs in an `if` condition, but skipping it is cleaner).
  if [ "${DRY_RUN:-0}" = 1 ] && [ "$num" = "(dry-run)" ]; then return 1; fi
  gh project field-list "$num" --owner "$ORG" --format json \
    | jq -e --arg n "$1" '.fields[] | select(.name==$n)' >/dev/null 2>&1
}

# Stage (the line). Options come from stage-map.tsv — see the contract note above.
if has_field "Stage"; then
  echo "field Stage already present"
else
  gh_mut project field-create "$num" --owner "$ORG" --name "Stage" \
    --data-type SINGLE_SELECT --single-select-options "$STAGE_OPTIONS"
  echo "created Stage field ($STAGE_OPTIONS)"
fi

# Free-text Spec field for traceability/grouping.
if has_field "Spec"; then
  echo "field Spec already present"
else
  gh_mut project field-create "$num" --owner "$ORG" --name "Spec" --data-type TEXT
  echo "created Spec field"
fi

# Work Type — what KIND of work item a card is, so the board can group by it.
#
# NOT named "Type": that is a RESERVED field name in Projects v2 and the API rejects it —
#   GraphQL: Name cannot have a reserved value, Name has already been taken (createProjectV2Field)
# Found by live verification against a throwaway org board, not by review: the name looks
# perfectly ordinary and nothing in the CLI help hints at a reserved list. Under
# `set -euo pipefail` the rejection aborted the whole script, so `Priority` was never
# reached and `provision.sh --upgrade` hard-failed with "setup-project.sh failed" — i.e.
# this would have broken provisioning for EVERY repo, not just degraded the board.
# `Work Type`, `Item Type`, `Kind` and `Artifact` were all probed and accepted.
if has_field "Work Type"; then
  echo "field Work Type already present"
else
  gh_mut project field-create "$num" --owner "$ORG" --name "Work Type" \
    --data-type SINGLE_SELECT --single-select-options "Spec,Ticket,Epic,Bug,Feature Request"
  echo "created Work Type field"
fi

# Priority — triage order.
if has_field "Priority"; then
  echo "field Priority already present"
else
  gh_mut project field-create "$num" --owner "$ORG" --name "Priority" \
    --data-type SINGLE_SELECT --single-select-options "P0,P1,P2,P3"
  echo "created Priority field"
fi

# DELIBERATELY NOT CREATED (SPEC-016 AC3):
#   Gate Status — nothing writes it. gate-auto-transition.yml is deferred and AC13 bars
#     any retained workflow from writing stage:*, so it would ship as a permanently empty
#     column. Since upgrade is additive-only, an unused field is a permanent commitment.
#   Repo        — duplicates the Projects v2 built-in `Repository` field, and the `repo:`
#     front-matter key lib/sync-issues.sh already projects on.

echo "Project ready: https://github.com/orgs/$ORG/projects/$num"
