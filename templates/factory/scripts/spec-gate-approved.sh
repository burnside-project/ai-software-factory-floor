#!/usr/bin/env bash
# spec-gate-approved.sh — when a human approves a spec PR, raise one → stage:code intent per
# ticket that spec owns. SPEC-017 AC3/AC9 / TICKET-085. Supersedes TICKET-049.
#
# WRITES NO LABEL. It emits INTENTS via lib/emit-intent.sh; the arbiter decides. This is the
# entire difference from TICKET-049 (which wrote stage:code directly and appears in no writer
# ledger, because this producer is not a writer).
#
# WHY TICKET-049 WAS UNIMPLEMENTABLE: it resolved tickets to issues via a `github_issue_id`
# front-matter key that lib/sync-issues.sh contractually NEVER writes — so every ticket
# carried null forever and the workflow was a no-op. This joins by TITLE PREFIX, the
# established idiom (lib/sync-issues.sh:89-91), which needs no write-back and works today.
#
# THE PROMOTION SET IS COMPUTED FROM BASE, NEVER FROM THE PR HEAD. The caller checks out base
# and points TICKETS_DIR at it. If it read head, THE PR AUTHOR WOULD CONTROL THE PROMOTION
# SET: a spec PR could add ticket files that auto-promote onto the build belt the instant any
# maintainer approves. And the spec PR *is* the thing that adds tickets, so that is the
# normal path, not an edge case. This script refuses to guess: TICKETS_DIR must be given.
#
# Env:
#   SPEC_ID        the spec whose tickets to promote (e.g. SPEC-016)
#   TICKETS_DIR    a base-branch checkout of tickets/  (NOT the PR head)
#   TARGET_REPO    owner/name
#   PR_NUMBER      the spec PR, for the summary comment
#   GH_TOKEN       an App token — a dispatch raised with GITHUB_TOKEN starts no run
#   DRY_RUN=1      print intents instead of raising them (the test path)
#
# Bash 3.2 compatible; shellcheck clean.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMIT="$HERE/lib/emit-intent.sh"
[ -f "$EMIT" ] || { echo "::error::emit-intent.sh not found at $EMIT" >&2; exit 1; }

SPEC_ID="${SPEC_ID:-}"
TICKETS_DIR="${TICKETS_DIR:-}"
TARGET_REPO="${TARGET_REPO:-${GITHUB_REPOSITORY:-}}"
PR_NUMBER="${PR_NUMBER:-}"
DRY_RUN="${DRY_RUN:-0}"

[ -n "$SPEC_ID" ]     || { echo "::error::SPEC_ID is required" >&2; exit 1; }
[ -n "$TICKETS_DIR" ] || { echo "::error::TICKETS_DIR is required — it must be a BASE-branch checkout, never the PR head" >&2; exit 1; }
[ -d "$TICKETS_DIR" ] || { echo "::error::TICKETS_DIR '$TICKETS_DIR' is not a directory" >&2; exit 1; }
[ -n "$TARGET_REPO" ] || { echo "::error::TARGET_REPO is required" >&2; exit 1; }

# fm <file> <key> — one front-matter value. Same reader as lib/sync-issues.sh.
fm() {
  awk -v k="$2" '
    /^---[[:space:]]*$/ {n++; next}
    n==1 && $0 ~ "^" k ":" { sub("^" k ":[[:space:]]*", ""); print; exit }
  ' "$1"
}

# issue_for <ticket-id> — the title-prefix join (lib/sync-issues.sh:89-91). No write-back,
# no github_issue_id. `--arg` binds the untrusted id; `--` terminates the gh call.
issue_for() {
  gh issue list --repo "$TARGET_REPO" --search="$1: in:title" --state all --json number,title -- \
    | jq -r --arg id "$1" 'first(.[]|select(.title|startswith($id + ":"))|.number) // empty'
}

current_stage() { # <issue>
  gh issue view "$1" --repo "$TARGET_REPO" --json labels \
    --jq '.labels[].name | select(startswith("stage:"))' 2>/dev/null | head -1
}

# ---- collect the promotion set from BASE tickets -------------------------------------
raised=""; skipped=""; found=0
for f in "$TICKETS_DIR"/*/*.md "$TICKETS_DIR"/*.md; do
  [ -e "$f" ] || continue
  [ "$(fm "$f" spec)" = "$SPEC_ID" ] || continue
  tid="$(fm "$f" id)"
  [ -n "$tid" ] || { skipped="$skipped $(basename "$f")(no id)"; continue; }
  found=$((found + 1))

  issue="$(issue_for "$tid")"
  if [ -z "$issue" ]; then
    skipped="$skipped $tid(no issue)"
    continue
  fi

  from="$(current_stage "$issue")"; [ -n "$from" ] || from="(none)"

  # human-gate: the approval is what authorises this. The reviewer-is-human check is NOT an
  # inline if — authority is the transition table's producer-authority column, and the
  # approving-review fact is re-derived by the arbiter (TICKET-083). This producer only
  # reports that an approval happened.
  _dry=""; [ "$DRY_RUN" = "1" ] && _dry="--dry-run"
  # shellcheck disable=SC2086  # $_dry is an intentional single optional flag
  if bash "$EMIT" $_dry \
       --issue "$issue" --from "$from" --to stage:code \
       --event spec-gate-approved --producer-class human-gate \
       --run-id "${GITHUB_RUN_ID:-local}" --repo "$TARGET_REPO" \
       --reason "spec $SPEC_ID approved (PR #${PR_NUMBER:-?}); promoting $tid"; then
    raised="$raised $tid(#$issue)"
  else
    skipped="$skipped $tid(emit-failed)"
  fi
done

# ---- report --------------------------------------------------------------------------
if [ "$found" -eq 0 ]; then
  msg="No tickets found for $SPEC_ID. Remediation: give each ticket \`spec: $SPEC_ID\` front-matter, push to main so sync-issues creates its Issue, then re-approve or re-run this workflow."
  echo "::notice::$msg"
  if [ "$DRY_RUN" != "1" ] && [ -n "$PR_NUMBER" ]; then
    gh pr comment "$PR_NUMBER" --repo "$TARGET_REPO" --body "$msg" || true
  fi
  exit 0
fi

summary="Spec gate approved for **$SPEC_ID**. Raised → stage:code intent for:${raised:- (none matched an Issue)}"
[ -n "$skipped" ] && summary="$summary
Skipped:$skipped"
echo "$summary"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '%s\n' "$summary" >> "$GITHUB_STEP_SUMMARY"
if [ "$DRY_RUN" != "1" ] && [ -n "$PR_NUMBER" ]; then
  gh pr comment "$PR_NUMBER" --repo "$TARGET_REPO" --body "$summary" || true
fi
