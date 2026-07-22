#!/usr/bin/env bash
# reconcile-ci-checks.sh — emit a per-repo branch-ruleset variant whose required
# status checks match a repo's REAL CI check names, so flipping the ruleset to
# 'active' actually gates instead of requiring a check that never reports.
#
#   scripts/reconcile-ci-checks.sh <org/repo>                 # live discovery (read-only gh api GET)
#   scripts/reconcile-ci-checks.sh <org/repo> --checks a,b,c  # explicit list (makes NO gh call)
#   scripts/reconcile-ci-checks.sh <org/repo> --out path.json # write to a file (default: stdout)
#
# EMIT-AND-REVIEW ONLY: this helper writes a ruleset JSON for a human to review and
# NEVER applies it — it makes NO state-changing GitHub call (no POST/PUT/PATCH/DELETE).
# Applying the reviewed file stays the operator-confirmed setup-repo.sh step
# (setup-repo.sh accepts RULESET=<path>).
#
# SECURITY (SPEC-007 C1/C3): check/context names come from the GitHub API and are
# attacker-influenceable (a repo's workflow can name a check to attempt injection).
# They enter the emitted JSON ONLY via jq argument binding / raw jq input — NEVER
# string-concatenated into JSON and NEVER interpolated into a jq program (the filters
# are fixed literals). No eval. The gh token is never echoed, logged, or emitted.
set -euo pipefail

HERE="$(cd "$(dirname "$0")/.." && pwd)"
BASE_RULESET="$HERE/templates/factory/ruleset.json"

REPO=""
CHECKS=""
CHECKS_SET=0
OUT=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --checks)
      shift
      [ "$#" -gt 0 ] || { echo "ERROR: --checks requires a comma-separated value" >&2; exit 1; }
      CHECKS="$1"
      CHECKS_SET=1
      ;;
    --out)
      shift
      [ "$#" -gt 0 ] || { echo "ERROR: --out requires a path" >&2; exit 1; }
      OUT="$1"
      ;;
    --*)
      echo "ERROR: unknown flag '$1'" >&2
      exit 1
      ;;
    *)
      if [ -z "$REPO" ]; then
        REPO="$1"
      else
        echo "ERROR: unexpected extra argument '$1'" >&2
        exit 1
      fi
      ;;
  esac
  shift
done

[ -n "$REPO" ] || { echo "ERROR: <org/repo> required" >&2; echo "Usage: scripts/reconcile-ci-checks.sh <org/repo> [--checks a,b,c] [--out path.json]" >&2; exit 1; }
[ -f "$BASE_RULESET" ] || { echo "ERROR: base ruleset not found: $BASE_RULESET" >&2; exit 1; }

# Collect raw check names (newline-separated). With --checks: no GitHub call at all.
# With live discovery: BOUNDED read-only GET of ONE recent default-branch commit's
# check-runs (+ legacy statuses) — no unbounded pagination loop.
names=""
if [ "$CHECKS_SET" -eq 1 ]; then
  names="$(printf '%s' "$CHECKS" | tr ',' '\n')"
else
  branch="$(gh api "repos/$REPO" --jq '.default_branch')"
  [ -n "$branch" ] || { echo "ERROR: could not determine default branch for $REPO" >&2; exit 1; }
  # --jq filters are fixed literals; gh performs the read-only GET. Output is raw name
  # lines captured into variables and only ever passed to jq as quoted data (never a
  # command position). A repo with no runs yet yields empty output (handled below).
  cr="$(gh api "repos/$REPO/commits/$branch/check-runs" --jq '.check_runs[].name' 2>/dev/null || true)"
  st="$(gh api "repos/$REPO/commits/$branch/status" --jq '.statuses[].context' 2>/dev/null || true)"
  names="$(printf '%s\n%s\n' "$cr" "$st")"
fi

# Build the sorted, de-duplicated context array as a JSON value. Names enter jq as RAW
# INPUT (-R -s), so jq does all JSON encoding — no name is ever concatenated into JSON
# or into the filter text. `unique` sorts + de-dupes → byte-identical output for
# identical inputs (C12 determinism).
CTX_ARRAY="$(printf '%s\n' "$names" | jq -R -s '
  split("\n")
  | map(sub("^[[:space:]]+";"") | sub("[[:space:]]+$";""))
  | map(select(length > 0))
  | unique
  | map({context: .})
')"

# C12: empty discovery MUST NOT emit an empty required_status_checks array (a fail-open
# gate — nothing required means nothing blocks). Fail loudly and point at --checks.
CTX_LEN="$(printf '%s' "$CTX_ARRAY" | jq 'length')"
if [ "$CTX_LEN" -eq 0 ]; then
  echo "ERROR: no CI check names discovered for $REPO." >&2
  echo "       Refusing to emit a ruleset with an EMPTY required_status_checks array" >&2
  echo "       (that would be a fail-open gate: nothing required = nothing blocks)." >&2
  echo "       Re-run with --checks \"a,b,c\" to supply the check names explicitly." >&2
  exit 1
fi

# Merge into the base ruleset, replacing ONLY the required_status_checks rule's context
# array. The filter is a fixed literal; the untrusted data enters solely as the bound
# --argjson value, so every other rule (deletion, non_fast_forward, the pull_request
# reviewer rule, strict_required_status_checks_policy, name, target, conditions,
# _comment, enforcement) is preserved byte-for-byte.
result="$(jq --argjson ctx "$CTX_ARRAY" '
  (.rules[] | select(.type=="required_status_checks")
     | .parameters.required_status_checks) |= $ctx
' "$BASE_RULESET")"

if [ -n "$OUT" ]; then
  printf '%s\n' "$result" > "$OUT"
  echo "wrote reconciled ruleset for $REPO to: $OUT" >&2
  echo "review it, then apply with: RULESET='$OUT' scripts/setup-repo.sh '$REPO'" >&2
else
  printf '%s\n' "$result"
fi
