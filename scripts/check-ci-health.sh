#!/usr/bin/env bash
set -euo pipefail

# check-ci-health.sh — read-only diagnosis of "jobs are queued but nothing is running".
#
# WHY THIS EXISTS. On 2026-07-19 every job on the self-hosted runners stalled: GitHub held
# the jobs at "Waiting for a runner to pick up this job...", all six runners reported
# online+idle, labels matched, and the status page said All Systems Operational for the
# first ~75 minutes. The actual cause was an EXPIRED LEAF CERT on GitHub's own
# pipelines.actions.githubusercontent.com, so the runners could not fetch job messages —
# visible only as `NotTimeValid` in the runner _diag log. Reaching that took a long manual
# hunt. The signature is mechanical, so this script does the hunt in seconds.
#
# WHAT IT DISTINGUISHES. "Queued" alone says nothing about why. This separates:
#   - nothing is actually stuck (queue drains normally)      -> healthy
#   - runners are all BUSY                                   -> saturation, not a stall
#   - no runner is online                                    -> runners down / deregistered
#   - a requested label matches no online runner             -> workflow/runner misconfig
#   - runners online+idle but jobs still queued              -> DISPATCH STALL, then probe:
#       * TLS to the Actions endpoints (expired cert, bad chain)
#       * an open GitHub incident
#       * NotTimeValid / listener errors in the local runner _diag log (host-only)
#       * local clock skew (a wrong clock presents as NotTimeValid too)
#
# STRICTLY READ-ONLY (C2). Only `gh` reads, an `openssl s_client` handshake, one
# githubstatus.com GET, and local file reads. No writes, no gh mutations, no git writes,
# nothing that changes runner or repo state. Safe to run at any time, including mid-incident.
#
# NOT ALL FINDINGS ARE YOURS TO FIX. An expired cert at depth 0 belongs to GitHub — the
# script says so explicitly rather than implying a local remedy, because the tempting
# "fixes" (trusting the expired cert, disabling verification) are respectively useless and
# dangerous. Expiry is checked independently of trust, so adding it to a trust store changes
# nothing; disabling verification removes TLS protection from CI hosts to route around an
# outage you do not control.
#
# Env (all optional):
#   REPO                owner/name           (default: derived from `gh repo view`)
#   ORG                 runner scope         (default: the owner part of REPO)
#   STALL_MINS          queued-for minutes before a run counts as stalled (default 5)
#   ACTIONS_ENDPOINTS   space-separated hosts to TLS-probe
#   RUNNER_DIAG_DIR     runner _diag dir     (default /data/github-runner/_diag)
#   SKIP_STATUS_PAGE=1  do not call githubstatus.com
#
# Exit 0 = healthy or a cause identified that is NOT a stall (saturation).
# Exit 1 = a stall or degradation was found; the DIAGNOSIS line says which.
#
# Bash 3.2 compatible; shellcheck clean.

STALL_MINS="${STALL_MINS:-5}"
DIAG_DIR="${RUNNER_DIAG_DIR:-/data/github-runner/_diag}"
ENDPOINTS="${ACTIONS_ENDPOINTS:-pipelines.actions.githubusercontent.com broker.actions.githubusercontent.com}"

say()  { echo "$*"; }
head2() { echo; echo "== $*"; }

# `timeout` is GNU; macOS has it only as gtimeout via coreutils. Resolve once, tolerate
# absence — a missing timeout must degrade to "no timeout", never abort the diagnosis.
TO=""
if command -v timeout  >/dev/null 2>&1; then TO="timeout 20"
elif command -v gtimeout >/dev/null 2>&1; then TO="gtimeout 20"
fi

# ---- prerequisites -------------------------------------------------------------------
command -v gh >/dev/null 2>&1 || { echo "MISSING: gh not on PATH"; exit 1; }
command -v jq >/dev/null 2>&1 || { echo "MISSING: jq not on PATH"; exit 1; }

REPO="${REPO:-$(gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null || true)}"
[ -n "$REPO" ] || { echo "MISSING: could not determine REPO (set REPO=owner/name)"; exit 1; }
ORG="${ORG:-${REPO%%/*}}"

say "CI health check — repo $REPO, runner scope $ORG, stall threshold ${STALL_MINS}m"

# ---- 1. is anything actually stuck? --------------------------------------------------
# Date math via jq (fromdateiso8601/now), NOT `date -d`: BSD and GNU date disagree on
# parsing ISO-8601, and this script runs from both an operator mac and a Linux runner.
# READING A FAILED READ IS THE TRAP. `gh` prints the error BODY to STDOUT and exits
# non-zero — during the 2026-07-19 503s that body was {"message":"No server is currently
# available..."}. It is valid JSON, `--jq` is not applied to it, and `jq length` on that
# OBJECT returns its key count (1), which silently became "1 runner registered, 0 online"
# and a confident, wrong "the fleet is down" verdict. So: gate on the EXIT STATUS and on
# the payload actually being an ARRAY, and never diagnose from data that failed to load.
head2 "queued runs"
runs_json='[]'; runs_ok=0
if out="$(gh run list --repo "$REPO" --status queued --limit 100 \
          --json databaseId,createdAt,workflowName,headBranch 2>/dev/null)"; then
  if printf '%s' "$out" | jq -e 'type=="array"' >/dev/null 2>&1; then
    runs_json="$out"; runs_ok=1
  fi
fi

if [ "$runs_ok" -eq 0 ]; then
  say "  UNAVAILABLE — could not read the run list (API degraded or unauthenticated)"
  say "  NOTE: GitHub's API returns 503 during an Actions incident — that is itself a signal."
fi

stalled_json="$(printf '%s' "$runs_json" \
  | jq --argjson m "$STALL_MINS" '[.[] | select((now - (.createdAt|fromdateiso8601)) > ($m*60))]' \
  2>/dev/null || echo '[]')"
stalled_n="$(printf '%s' "$stalled_json" | jq 'length' 2>/dev/null || echo 0)"
queued_n="$(printf '%s'  "$runs_json"    | jq 'length' 2>/dev/null || echo 0)"

say "  $queued_n queued, $stalled_n queued longer than ${STALL_MINS}m"
printf '%s' "$stalled_json" \
  | jq -r '.[] | "    #\(.databaseId)  \(.workflowName)  (\(.headBranch))"' 2>/dev/null || true

if [ "$runs_ok" -eq 1 ] && [ "$stalled_n" -eq 0 ]; then
  say
  say "DIAGNOSIS: healthy — no run has been queued longer than ${STALL_MINS}m."
  exit 0
fi

# ---- 2. runner fleet state -----------------------------------------------------------
head2 "runners (org: $ORG)"
runners_json='[]'; runners_ok=0
if out="$(gh api "orgs/$ORG/actions/runners" --jq '.runners' 2>/dev/null)"; then
  if printf '%s' "$out" | jq -e 'type=="array"' >/dev/null 2>&1; then
    runners_json="$out"; runners_ok=1
  fi
fi

online_n=0; idle_n=0; total_n=0
if [ "$runners_ok" -eq 1 ]; then
  online_n="$(printf '%s' "$runners_json" | jq '[.[]|select(.status=="online")]      | length' 2>/dev/null || echo 0)"
  idle_n="$(  printf '%s' "$runners_json" | jq '[.[]|select(.status=="online" and .busy==false)]|length' 2>/dev/null || echo 0)"
  total_n="$( printf '%s' "$runners_json" | jq 'length' 2>/dev/null || echo 0)"
  say "  $total_n registered, $online_n online, $idle_n online+idle"
  printf '%s' "$runners_json" \
    | jq -r '.[] | "    \(.name)  status=\(.status) busy=\(.busy)  [\([.labels[].name]|join(","))]"' \
    2>/dev/null || true
else
  say "  UNAVAILABLE — the Actions API is not answering for runners."
  say "  Consistent with a GitHub-side Actions/API outage. NOT evidence that the fleet is"
  say "  down: an unread fleet and an offline fleet are different things, and only the"
  say "  runner host can settle it (systemctl status 'actions.runner.*')."
fi

# Saturation and offline-fleet are DIFFERENT causes with the same "queued" symptom, and
# neither is the TLS stall — return early so the probes below do not mislabel them. Guarded
# on runners_ok: with no fleet data these classifications are not merely unknown, they are
# actively misleading.
if [ "$runners_ok" -eq 1 ] && [ "$total_n" -gt 0 ] && [ "$online_n" -eq 0 ]; then
  say
  say "DIAGNOSIS: no runner is ONLINE — the fleet is down or deregistered, not a dispatch stall."
  say "  Next: on the runner host, systemctl status 'actions.runner.*' and check the service logs."
  exit 1
fi
if [ "$runners_ok" -eq 1 ] && [ "$online_n" -gt 0 ] && [ "$idle_n" -eq 0 ]; then
  say
  say "DIAGNOSIS: all $online_n online runners are BUSY — this is saturation, not a stall."
  say "  Jobs are queued because there is no free runner. Add capacity or wait."
  exit 0
fi

# ---- 3. label reachability -----------------------------------------------------------
# A requested label that no online runner carries queues forever and looks exactly like a
# dispatch stall. Check before blaming the network.
head2 "requested labels vs online runners"
first_run=""
[ "$runners_ok" -eq 1 ] && first_run="$(printf '%s' "$stalled_json" | jq -r '.[0].databaseId // empty' 2>/dev/null || true)"
if [ -z "$first_run" ]; then
  say "  skipped — needs both a stalled run and readable runner labels"
fi
if [ -n "$first_run" ]; then
  want="$(gh api "repos/$REPO/actions/runs/$first_run/jobs" \
          --jq '[.jobs[]|select(.status=="queued")|.labels[]]|unique|.[]' 2>/dev/null || true)"
  have="$(printf '%s' "$runners_json" | jq -r '[.[]|select(.status=="online")|.labels[].name]|unique|.[]' 2>/dev/null || true)"
  if [ -n "$want" ]; then
    say "  requested: $(printf '%s' "$want" | tr '\n' ' ')"
    missing=""
    # No `<<<` and no process substitution: Bash 3.2 portability. A plain for-loop over
    # word-split output is fine here — GitHub labels never contain whitespace.
    for l in $want; do
      printf '%s\n' "$have" | grep -qxF "$l" || missing="$missing $l"
    done
    if [ -n "$missing" ]; then
      say
      say "DIAGNOSIS: no online runner carries:$missing"
      say "  The job cannot be dispatched. Fix runs-on / vars.RUNNER_LABELS, or label a runner."
      exit 1
    fi
    say "  all requested labels are present on at least one online runner"
  fi
fi

# ---- 4. dispatch stall: runners are online, idle, and correctly labelled --------------
say
if [ "$runs_ok" -eq 1 ] && [ "$runners_ok" -eq 1 ]; then
  say "SYMPTOM: $stalled_n run(s) queued >${STALL_MINS}m while $idle_n runner(s) sit online+idle"
  say "         with matching labels. That is a DISPATCH STALL — probing why."
else
  say "SYMPTOM: queue and/or runner state could not be read. Probing the paths that do not"
  say "         depend on the Actions API — TLS, clock, listener log, status page."
fi

head2 "TLS to the Actions endpoints"
tls_bad=""
for h in $ENDPOINTS; do
  # shellcheck disable=SC2086  # $TO is an intentional optional command prefix
  out="$(echo | $TO openssl s_client -connect "$h:443" -servername "$h" 2>&1 || true)"
  if printf '%s' "$out" | grep -q "Verify return code: 0"; then
    say "  OK      $h"
  elif printf '%s' "$out" | grep -q "certificate has expired"; then
    # shellcheck disable=SC2086
    end="$(echo | $TO openssl s_client -connect "$h:443" -servername "$h" 2>/dev/null \
           | openssl x509 -noout -enddate 2>/dev/null | sed 's/notAfter=//' || true)"
    depth="$(printf '%s' "$out" | grep -m1 -B1 "certificate has expired" | grep -o 'depth=[0-9]*' || true)"
    say "  EXPIRED $h  (expired $end${depth:+, $depth})"
    tls_bad="$tls_bad $h"
  else
    say "  FAILED  $h  ($(printf '%s' "$out" | grep -m1 -E 'verify error|Verify return code' || echo 'no handshake'))"
    tls_bad="$tls_bad $h"
  fi
done

# ---- 5. corroborating evidence -------------------------------------------------------
head2 "local clock (skew presents as an expired/not-yet-valid cert)"
if command -v timedatectl >/dev/null 2>&1; then
  timedatectl 2>/dev/null | grep -E "System clock synchronized|NTP service" | sed 's/^/  /' || true
else
  say "  $(date -u '+%Y-%m-%dT%H:%M:%SZ') UTC (timedatectl unavailable — compare against a known-good clock)"
fi

if [ -d "$DIAG_DIR" ]; then
  head2 "runner listener log ($DIAG_DIR)"
  # Newest log via `-nt` over a glob, not `ls -t | head` — shellcheck SC2012, and the
  # glob keeps this correct without parsing ls output.
  latest=""
  for f in "$DIAG_DIR"/Runner_*.log; do
    [ -e "$f" ] || continue
    if [ -z "$latest" ] || [ "$f" -nt "$latest" ]; then latest="$f"; fi
  done
  if [ -n "$latest" ]; then
    say "  $(basename "$latest")"
    n_tls="$(grep -c "NotTimeValid\|SSL connection could not be established" "$latest" 2>/dev/null || true)"
    say "  ${n_tls:-0} TLS/cert error lines"
    grep -E "ERR " "$latest" 2>/dev/null | tail -2 | cut -c1-140 | sed 's/^/    /' || true
  fi
fi

if [ "${SKIP_STATUS_PAGE:-0}" != "1" ] && command -v curl >/dev/null 2>&1; then
  head2 "GitHub status"
  # shellcheck disable=SC2086
  st="$($TO curl -s https://www.githubstatus.com/api/v2/summary.json 2>/dev/null || true)"
  if [ -n "$st" ]; then
    printf '%s' "$st" | jq -r '"  " + .status.description' 2>/dev/null || true
    printf '%s' "$st" | jq -r '.components[]|select(.status!="operational")|"  DEGRADED: \(.name) -> \(.status)"' 2>/dev/null || true
    printf '%s' "$st" | jq -r '.incidents[]|"  INCIDENT: \(.name) [\(.status)]"' 2>/dev/null || true
    say "  (the status page lags — it read All Systems Operational for ~75m on 2026-07-19)"
  fi
fi

# ---- 6. verdict ----------------------------------------------------------------------
say
if [ -n "$tls_bad" ] && { [ "$runs_ok" -eq 0 ] || [ "$runners_ok" -eq 0 ]; }; then
  # Degraded read + a TLS fault. Report both without claiming the queue/fleet picture, which
  # was never read. The TLS evidence stands on its own — it needs no API.
  say "DIAGNOSIS: TLS failure to:$tls_bad — AND the Actions API did not answer."
  say "  Both point at a GitHub-side Actions incident rather than a local fault. The queue"
  say "  and fleet state could not be read, so no claim is made about them here."
elif [ "$runs_ok" -eq 0 ] || [ "$runners_ok" -eq 0 ]; then
  say "DIAGNOSIS: INCONCLUSIVE — the Actions API did not answer, and the endpoints probed"
  say "  above verify clean. Nothing here proves a local fault."
  say "  Next: check githubstatus.com, and confirm the fleet from the runner host itself"
  say "  (systemctl status 'actions.runner.*') rather than through the API."
elif [ -n "$tls_bad" ]; then
  say "DIAGNOSIS: dispatch stall caused by TLS failure to:$tls_bad"
  say "  The runners cannot fetch job messages, so GitHub has no runner claiming the queue."
  say
  say "  If the expired cert is at depth=0, it is GITHUB'S leaf cert on GitHub's server."
  say "  You cannot renew it and there is nothing to fix locally — the runners reconnect by"
  say "  themselves once GitHub reissues. Do NOT disable TLS verification to work around it,"
  say "  and note that trusting an expired cert does not work: expiry is checked separately"
  say "  from trust."
  say
  say "  If instead depth=1/2 is expired, or the clock above is unsynchronised, THAT is yours:"
  say "  refresh the trust store (ca-certificates) or fix NTP."
else
  say "DIAGNOSIS: dispatch stall with no TLS fault found — runners are online, idle and"
  say "  correctly labelled, and the endpoints above verify clean."
  say "  Next: check runner-group repository access for $REPO, any org Actions policy"
  say "  restricting this repo, and the listener log above for non-TLS errors."
fi
exit 1
