#!/usr/bin/env bash
# Set an issue's Project "Stage" field from its stage:* label, so the board stays in
# sync with the label state machine the floor motor drives (epic #4 T5). Idempotent —
# maps the label to a Stage option (set by setup-project.sh) and updates the item.
#
#   scripts/board-sync.sh <issue-url> <stage-label>
#
# Requires: gh authed with PROJECT scope (org projects write), jq. Same ORG/PROJECT
# defaults as sync-issues.sh. Used by board-sync.yml on `issues: labeled` events.
set -euo pipefail

# SPEC-019 (TICKET-099): ORG/PROJECT come from the compiled .factory/factory.env, never a home
# default. Source the runtime-env helper (sibling lib/), fill from config, then fail closed.
# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/factory-runtime-env.sh"
factory_load_config
factory_require ORG PROJECT
PROJECT_TITLE="$PROJECT"

# --dry-run / plan mode (SPEC-019 TICKET-104): render intended mutations, make ZERO GitHub
# mutation. The two positionals may appear in any order relative to the flag.
DRY_RUN=0
URL=""
LABEL=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    -*) echo "error: unknown option '$arg'" >&2; exit 1 ;;
    *)  if [ -z "$URL" ]; then URL="$arg"; elif [ -z "$LABEL" ]; then LABEL="$arg"; else echo "error: unexpected argument '$arg'" >&2; exit 1; fi ;;
  esac
done
if [ -z "$URL" ] || [ -z "$LABEL" ]; then echo "usage: board-sync.sh <issue-url> <stage-label> [--dry-run]" >&2; exit 1; fi

# Map stage:* label -> Project "Stage" option.
#
# THE STAGE CONTRACT (SPEC-016 / TICKET-067). This mapping is DATA, not a case statement:
# it is read from ../stage-map.tsv, the single source of truth shared with
# setup-project.sh, metrics.sh and setup-repo.sh. Add a label/option pair THERE and every
# site picks it up. A Stage option with `-` in column 1 is intentionally unmapped (Brief,
# Tickets, Deploy, Observe are set by other means) — not a gap to fill in here.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE_MAP="$HERE/../stage-map.tsv"
[ -f "$STAGE_MAP" ] || { echo "::error::stage-map.tsv not found at $STAGE_MAP" >&2; exit 1; }

STAGE="$(awk -F'\t' -v l="$LABEL" '!/^#/ && NF && $1==l {print $2; exit}' "$STAGE_MAP")"

# Unchanged behaviour: an unmapped label is a no-op, not a failure.
if [ -z "$STAGE" ]; then
  echo "no Stage mapping for '$LABEL' — nothing to sync"; exit 0
fi

pnum="$(gh project list --owner "$ORG" --format json \
        | jq -r --arg t "$PROJECT_TITLE" '.projects[]|select(.title==$t)|.number' | head -1)"
[ -n "$pnum" ] || { echo "::error::project '$PROJECT_TITLE' not found in org '$ORG'"; exit 1; }

if [ "${DRY_RUN:-0}" = 1 ]; then
  # Render the add and use a placeholder item id; the reads below still resolve the field/option
  # ids so the plan is complete, and the item-edit below is rendered rather than applied.
  printf 'would: gh %s\n' "project item-add $pnum --owner $ORG --url $URL"
  item="(dry-run)"
else
  item="$(gh project item-add "$pnum" --owner "$ORG" --url "$URL" --format json | jq -r '.id')"
fi
sf="$(gh project field-list "$pnum" --owner "$ORG" --format json)"
fid="$(echo "$sf" | jq -r '.fields[]|select(.name=="Stage")|.id')"
oid="$(echo "$sf" | jq -r --arg s "$STAGE" '.fields[]|select(.name=="Stage")|.options[]|select(.name==$s)|.id')"
pid="$(gh project view "$pnum" --owner "$ORG" --format json --jq .id)"

if [ -z "$fid" ] || [ -z "$oid" ]; then echo "::error::Stage field or option '$STAGE' not found on project #$pnum"; exit 1; fi
if [ "${DRY_RUN:-0}" = 1 ]; then
  printf 'would: gh %s\n' "project item-edit --id $item --project-id $pid --field-id $fid --single-select-option-id $oid"
  echo "would sync $URL Stage -> $STAGE"
else
  gh project item-edit --id "$item" --project-id "$pid" --field-id "$fid" --single-select-option-id "$oid" >/dev/null
  echo "synced $URL Stage -> $STAGE"
fi
