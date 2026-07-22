#!/usr/bin/env bash
# Verify every GitHub team referenced by CODEOWNERS exists and has >=1 member.
# A missing or empty team makes its CODEOWNERS rule match NO ONE — GitHub then
# treats that path as having no required reviewer, so the "code-owner review" gate
# silently fails open. This is the enforcement hole from audit finding N5.
#
# Read-only by default (exits non-zero if any referenced team is missing/empty, so
# it works as a pre-flight gate). Pass --create to create any missing teams (closed
# visibility, no repo attached — no seat cost). Adding MEMBERS stays manual/one-time.
#
#   scripts/setup-teams.sh            # verify (exit 1 if any missing or empty)
#   scripts/setup-teams.sh --create   # create missing teams, then verify membership
#
# Requires: gh (auth with read:org; admin:org for --create), grep. Same ORG default
# as the other factory scripts.
set -euo pipefail

# SPEC-019 (TICKET-099): ORG comes from the compiled .factory/factory.env, never a home
# default. Source the runtime-env helper (sibling lib/), fill from config, then fail closed.
# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/factory-runtime-env.sh"
factory_load_config
factory_require ORG
CODEOWNERS="${CODEOWNERS_FILE:-$(cd "$(dirname "$0")/.." && pwd)/CODEOWNERS}"
MODE="${1:-}"

[ -f "$CODEOWNERS" ] || { echo "::error::CODEOWNERS not found at $CODEOWNERS"; exit 1; }

# Distinct team slugs referenced as @ORG/<team> in CODEOWNERS.
# (while-read, not mapfile, so this runs on Bash 3.2 — see audit finding H2.)
teams=()
while IFS= read -r t; do [ -n "$t" ] && teams+=("$t"); done < <(
  grep -oE "@${ORG}/[A-Za-z0-9._-]+" "$CODEOWNERS" | sed "s#@${ORG}/##" | sort -u)

if [ "${#teams[@]}" -eq 0 ]; then
  echo "no @${ORG}/<team> references in $CODEOWNERS — nothing to verify"
  exit 0
fi

echo "Checking ${#teams[@]} team(s) referenced by CODEOWNERS in org '$ORG':"
fail=0
for t in "${teams[@]}"; do
  if ! gh api "orgs/$ORG/teams/$t" >/dev/null 2>&1; then
    if [ "$MODE" = "--create" ]; then
      if gh api --method POST "orgs/$ORG/teams" -f name="$t" -f privacy=closed >/dev/null 2>&1; then
        echo "  CREATED  $t (empty — add members before relying on its gate)"; fail=1
      else
        echo "  ERROR    $t — could not create (need admin:org?)"; fail=1
      fi
    else
      echo "  MISSING  $t (in CODEOWNERS but not an org team — rule fails open)"; fail=1
    fi
    continue
  fi
  n="$(gh api "orgs/$ORG/teams/$t/members" --jq 'length' 2>/dev/null || echo 0)"
  if [ "$n" -eq 0 ]; then
    echo "  EMPTY    $t (0 members — its CODEOWNERS rule fails open)"; fail=1
  else
    echo "  OK       $t ($n member(s))"
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "::error::CODEOWNERS references missing/empty teams — the code-owner review gate would fail open. Fix before flipping rulesets to 'active'."
  exit 1
fi
echo "all CODEOWNERS teams exist and are non-empty — the review gate has real owners"
