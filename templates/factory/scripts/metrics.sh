#!/usr/bin/env bash
# Factory metrics: read the org Project (the line) for WIP-by-Stage, and the
# epic/task issues on the boards' code repos for throughput + cycle time.
# The Project + files stay the source of truth; this only reports.
#
#   scripts/metrics.sh                 # markdown to stdout
#   scripts/metrics.sh metrics.md      # write to a file
#   ORG=... PROJECT="..." scripts/metrics.sh
#
# Requires: gh (auth + project scope), jq.  Same env defaults as sync-issues.sh.
# Assumes `gh project item-list --format json` exposes the Stage single-select under
# `.stage` and the repo under `.content.repository` (gh >= 2.x).
set -euo pipefail

command -v gh >/dev/null || { echo "::error::gh CLI is required"; exit 1; }
command -v jq >/dev/null || { echo "::error::jq is required"; exit 1; }

# SPEC-019 (TICKET-099): ORG/PROJECT come from the compiled .factory/factory.env, never a home
# default. Source the runtime-env helper (sibling lib/), fill from config, then fail closed.
# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/factory-runtime-env.sh"
factory_load_config
factory_require ORG PROJECT
PROJECT_TITLE="$PROJECT"
OUT="${1:-}"
NOW="$(date -u +%Y-%m-%dT%H:%MZ)"

# Stage options, in line order.
#
# THE STAGE CONTRACT (SPEC-016 / TICKET-067). Derived from ../stage-map.tsv, the single
# source of truth. This array used to be a hand-maintained literal guarded by the comment
# "must match setup-project.sh" — exactly the convention-only guarantee that let five
# copies of this vocabulary drift apart.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STAGE_MAP="$HERE/../stage-map.tsv"
[ -f "$STAGE_MAP" ] || { echo "::error::stage-map.tsv not found at $STAGE_MAP" >&2; exit 1; }

# Bash 3.2: no mapfile. Word-splitting is safe — Stage options contain no whitespace,
# which the stage-map test asserts.
# shellcheck disable=SC2207
STAGES=($(awk -F'\t' '!/^#/ && NF && $2!="" && !seen[$2]++ {print $2}' "$STAGE_MAP"))
[ "${#STAGES[@]}" -gt 0 ] || { echo "::error::no Stage options derived from $STAGE_MAP" >&2; exit 1; }

pnum="$(gh project list --owner "$ORG" --format json \
        | jq -r --arg t "$PROJECT_TITLE" '.projects[] | select(.title==$t) | .number' | head -1)"
[ -z "$pnum" ] && { echo "::error::project '$PROJECT_TITLE' not found in org '$ORG'"; exit 1; }

items="$(gh project item-list "$pnum" --owner "$ORG" --limit 1000 --format json)" || {
  echo "::error::gh project item-list failed — check auth (needs 'project' scope) and project #$pnum"; exit 1
}

# Distinct code repos present on the board (content.repository may be owner/repo or a URL).
# (while-read instead of `mapfile` so this runs on Bash 3.2, e.g. stock macOS.)
repos=()
while IFS= read -r r; do [ -n "$r" ] && repos+=("$r"); done < <(echo "$items" \
  | jq -r '.items[].content.repository // empty' \
  | sed 's#^https://github.com/##' | sort -u)

# Aggregate closed task issues across those repos for throughput + cycle time.
agg='[]'
for r in "${repos[@]}"; do
  j="$(gh issue list --repo "$r" --state closed --label task --limit 500 \
        --json number,createdAt,closedAt 2>/dev/null || echo '[]')"
  agg="$(jq -n --argjson a "$agg" --argjson b "$j" '$a + $b')"
done

render() {
  echo "# Factory Metrics"
  echo
  echo "_org \`$ORG\` · project \"$PROJECT_TITLE\" (#$pnum) · ${NOW}_"
  echo
  echo "## Items by Stage (the line)"
  echo
  echo "| Stage | Items |"
  echo "|---|---|"
  local inflight=0 c
  for s in "${STAGES[@]}"; do
    c="$(echo "$items" | jq --arg s "$s" '[.items[] | select((.stage // .Stage // "")==$s)] | length')"
    echo "| $s | $c |"
    [ "$s" != "Done" ] && inflight=$((inflight + c))
  done
  echo
  echo "- in-flight (not Done): **$inflight**"
  echo
  echo "## Throughput & cycle time (task issues)"
  echo
  if [ "${#repos[@]}" -eq 0 ]; then
    echo "_No issues on the board yet._"
    return
  fi
  echo "Repos on the board: $(printf '%s, ' "${repos[@]}" | sed 's/, $//')"
  echo
  echo "- tasks closed, last 7 days: $(echo "$agg"  | jq '[.[]|select(.closedAt and ((.closedAt|fromdateiso8601) > (now-604800)))]|length')"
  echo "- tasks closed, last 30 days: $(echo "$agg" | jq '[.[]|select(.closedAt and ((.closedAt|fromdateiso8601) > (now-2592000)))]|length')"
  echo "- tasks closed, all time: $(echo "$agg"     | jq 'length')"
  echo "- cycle time: $(echo "$agg" | jq -r '
      [ .[] | select(.closedAt) | (((.closedAt|fromdateiso8601)-(.createdAt|fromdateiso8601))/86400) ] as $d
      | if ($d|length) > 0
        then "avg \((($d|add)/($d|length))*10|round/10) d · min \(($d|min)*10|round/10) d · max \(($d|max)*10|round/10) d  (\($d|length) tasks)"
        else "no closed tasks yet" end')"
}

if [ -n "$OUT" ]; then render > "$OUT"; echo "Wrote $OUT"; else render; fi
