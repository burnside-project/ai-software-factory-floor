#!/usr/bin/env bash
# pr-merged.sh — when a ticket PR merges, close its linked issues and emit a → stage:done
# intent for each. SPEC-017 / TICKET-086. Rewrites the body of TICKET-050.
#
# CLOSING AN ISSUE IS NOT A stage:* WRITE, so it legitimately stays in this client. Advancing
# the stage is an INTENT via lib/emit-intent.sh — the arbiter decides. This producer is not
# in the writer ledger.
#
# WHAT IMPROVED OVER TICKET-050: that ticket did an UNCONDITIONAL
# `--remove-label stage:review --add-label stage:done`. Under CAS, an issue that is not
# actually at `review` is REFUSED and reported by the arbiter, not silently jumped to done.
# expected-current-stage carries `stage:review` so the arbiter can check it.
#
# WHAT WAS CUT: TICKET-050 step 3 moved specs/approved -> specs/implementing. Removed —
# those dirs don't exist here (it's draft/ and completed/), it needs contents: write in an
# otherwise minimal-privilege workflow, and spec-directory lifecycle is post-merge.yml's job
# (TICKET-051, NOT adopted by SPEC-017). Doing it here would silently take on a slice of an
# unadopted ticket.
#
# Env:
#   PR_BODY        the merged PR's body, for Closes/Fixes/Resolves + bare TICKET-NNN refs
#   PR_NUMBER      the merged PR
#   TARGET_REPO    owner/name
#   GH_TOKEN       an App token — a dispatch raised with GITHUB_TOKEN starts no run
#   DRY_RUN=1      print instead of mutating (the test path)
#
# Bash 3.2 compatible; shellcheck clean.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EMIT="$HERE/lib/emit-intent.sh"
[ -f "$EMIT" ] || { echo "::error::emit-intent.sh not found at $EMIT" >&2; exit 1; }

PR_BODY="${PR_BODY:-}"
PR_NUMBER="${PR_NUMBER:-}"
TARGET_REPO="${TARGET_REPO:-${GITHUB_REPOSITORY:-}}"
DRY_RUN="${DRY_RUN:-0}"

[ -n "$TARGET_REPO" ] || { echo "::error::TARGET_REPO is required" >&2; exit 1; }

# issue_for_ticket <TICKET-NNN> — the title-prefix join (lib/sync-issues.sh:89-91).
issue_for_ticket() {
  gh issue list --repo "$TARGET_REPO" --search="$1: in:title" --state all --json number,title -- \
    | jq -r --arg id "$1" 'first(.[]|select(.title|startswith($id + ":"))|.number) // empty'
}

is_closed() { # <issue> -> 0 if already closed
  [ "$(gh issue view "$1" --repo "$TARGET_REPO" --json state --jq '.state' 2>/dev/null)" = "CLOSED" ]
}
current_stage() { # <issue>
  gh issue view "$1" --repo "$TARGET_REPO" --json labels \
    --jq '.labels[].name | select(startswith("stage:"))' 2>/dev/null | head -1
}

# ---- collect referenced issues -------------------------------------------------------
# Closes/Fixes/Resolves #N are direct issue numbers. Bare TICKET-NNN resolve via the join.
# De-duplicated: a PR body naming the same issue twice acts once.
direct="$(printf '%s\n' "$PR_BODY" | grep -oiE '(close[sd]?|fix(e[sd])?|resolve[sd]?)[[:space:]]+#[0-9]+' \
          | grep -oE '#[0-9]+' | tr -d '#' || true)"
tickets="$(printf '%s\n' "$PR_BODY" | grep -oE 'TICKET-[0-9]+' | LC_ALL=C sort -u || true)"

issues=""
for n in $direct; do issues="$issues $n"; done
for t in $tickets; do
  n="$(issue_for_ticket "$t")"
  [ -n "$n" ] && issues="$issues $n"
done
# shellcheck disable=SC2086  # word-splitting $issues into one-per-line is intended here
issues="$(printf '%s\n' $issues | grep -E '^[0-9]+$' | LC_ALL=C sort -un || true)"

if [ -z "$issues" ]; then
  echo "::notice::PR #${PR_NUMBER:-?} references no issue (no Closes/Fixes/Resolves #N and no TICKET-NNN) — nothing to close"
  exit 0
fi

closed=""; raised=""; skipped=""
for n in $issues; do
  if is_closed "$n"; then
    skipped="$skipped #$n(already closed)"
    continue
  fi

  from="$(current_stage "$n")"; [ -n "$from" ] || from="(none)"

  # → stage:done intent. expected-current-stage is stage:review; the arbiter refuses if the
  # issue is not actually there. The merged-ness claim is advisory — the arbiter re-derives
  # merged_at + default-branch ancestry itself (TICKET-083).
  _dry=""; [ "$DRY_RUN" = "1" ] && _dry="--dry-run"
  # shellcheck disable=SC2086  # $_dry is one intentional optional flag
  if bash "$EMIT" $_dry \
       --issue "$n" --from stage:review --to stage:done \
       --event pr-merged --producer-class human-gate \
       --run-id "${GITHUB_RUN_ID:-local}" --repo "$TARGET_REPO" \
       --reason "PR #${PR_NUMBER:-?} merged (issue was at $from)"; then
    raised="$raised #$n"
  else
    skipped="$skipped #$n(emit-failed)"
  fi

  if [ "$DRY_RUN" = "1" ]; then
    echo "DRY RUN: would close #$n --reason completed"
    closed="$closed #$n"
  else
    if gh issue close "$n" --repo "$TARGET_REPO" --reason completed 2>/dev/null; then
      closed="$closed #$n"
    else
      skipped="$skipped #$n(close-failed)"
    fi
  fi
done

summary="PR #${PR_NUMBER:-?} merged. Closed:${closed:- none}. Raised → stage:done intent for:${raised:- none}."
[ -n "$skipped" ] && summary="$summary Skipped:$skipped."
echo "$summary"
[ -n "${GITHUB_STEP_SUMMARY:-}" ] && printf '%s\n' "$summary" >> "$GITHUB_STEP_SUMMARY"
if [ "$DRY_RUN" != "1" ] && [ -n "$PR_NUMBER" ]; then
  gh pr comment "$PR_NUMBER" --repo "$TARGET_REPO" --body "$summary" || true
fi
