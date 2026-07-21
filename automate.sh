#!/usr/bin/env bash
set -euo pipefail

# Usage: ./automate.sh [audit|features|deploy|all]   (default: all)
# Env toggles: DEPLOY_REMOTE=1 REMOTE_HOST=4 REMOTE_PATH=/srv/<name>

REPO="YOUR_LOCAL_REPO"
AUDIT="$REPO/audit"
LOGS="$REPO/logs/automate"
STAMP="$(date +%Y%m%d-%H%M%S)"
DATE="$(date +%F)"
STAGE="${1:-all}"

DEPLOY_REMOTE="${DEPLOY_REMOTE:-0}"
REMOTE_HOST="${REMOTE_HOST:-REMOTE_ALIAS}"
REMOTE_PATH="${REMOTE_PATH:-/srv/PATH_TO_DEPLOY}"

mkdir -p "$AUDIT/reports" "$LOGS"
cd "$REPO"

# bypassPermissions skips ALL tool-permission prompts. Required for unattended
# headless runs — without it the agent silently waits for a TTY that isn't there.
CLAUDE_FLAGS=(
  --output-format stream-json
  --verbose
  --permission-mode bypassPermissions
)

# Streams agent output live: raw JSONL to disk, prose + tool calls to terminal+log.
run_claude() {
  local label="$1"; shift
  local prompt="$1"; shift
  local raw="$LOGS/${STAMP}-${label}.jsonl"
  local pretty="$LOGS/${STAMP}-${label}.log"
  echo ">>> [$label] starting — raw=$raw  pretty=$pretty"
  claude -p "$prompt" "${CLAUDE_FLAGS[@]}" "$@" \
    | tee "$raw" \
    | jq -rj '
        if .type=="assistant" then
          (.message.content[]?
            | if .type=="text" then .text
              elif .type=="tool_use" then "\n[tool: \(.name)] \(.input | tostring | .[0:200])\n"
              else empty end)
        elif .type=="result" then "\n\n--- done (\(.subtype // "ok")) ---\n"
        else empty end' \
    | tee "$pretty"
  echo ""
}

do_audit() {
  if [[ -s "$AUDIT/reports/$DATE.md" ]]; then
    echo "SKIP audit: $AUDIT/reports/$DATE.md already exists"
    return 0
  fi
  run_claude audit "Audit this repository. Cover:
- Security: secrets in code, insecure deps, OWASP-style issues
- Code quality: dead code, complexity hotspots, anti-patterns
- Test coverage: gaps, missing critical paths
- Dependencies: outdated, known CVEs
- Architecture: observations and recommendations

Write ONE markdown report to $AUDIT/reports/$DATE.md.
Do NOT commit. Do NOT open a PR. Do NOT modify any source files.
Just write that one report file and stop."
  [[ -s "$AUDIT/reports/$DATE.md" ]] || { echo "FAIL: audit report not written"; exit 1; }
  echo "OK audit -> $AUDIT/reports/$DATE.md"
}

do_plan_features() {
  local report="$AUDIT/reports/$DATE.md"
  [[ -s "$report" ]] || { echo "FAIL: no audit report at $report; run './automate.sh audit' first"; exit 1; }
  mkdir -p "$REPO/features"
  run_claude plan-features "Read the audit report at $report.

For each finding that an AI coding agent can safely implement, produce one feature
spec file at $REPO/features/NN-<slug>.md (e.g. 01-gitignore-secrets.md, 02-remove-tls-verify-false.md).
Number them in execution order, lowest-risk-and-most-isolated first.

Each spec MUST contain these sections:
  # <title>
  ## Audit refs
  ## Goal
  ## Files to change (explicit list)
  ## Steps (concrete, ordered)
  ## Acceptance criteria
  ## Out of scope

EXCLUDE from the feature list anything that requires human action and write those
to a separate $REPO/features/HUMAN-ACTIONS.md (rotating real credentials in
GCP/Stripe/Redis consoles, regenerating DJANGO_SECRET_KEY in production env,
git-history rewrites to purge secrets, branch-protection settings, dependabot
enablement on github.com).

EXCLUDE high-blast-radius refactors (splitting the 2,437-line models.py, the
1,910-line config.py, consolidating dual service layers) — list those in
$REPO/features/DEFERRED.md with one-line rationale. They need design discussion
first.

Spec files only. Do not modify any source files. Do not commit."
  ls -1 "$REPO/features/"*.md 2>/dev/null | head -1 >/dev/null \
    || { echo "FAIL: planner produced no specs in $REPO/features/"; exit 1; }
  echo "OK plan -> $REPO/features/ ($(ls -1 "$REPO/features/"*.md 2>/dev/null | wc -l | tr -d ' ') specs)"
}

do_features() {
  shopt -s nullglob
  # only numbered specs are executable; HUMAN-ACTIONS.md and DEFERRED.md are skipped
  local specs=("$REPO"/features/[0-9]*.md)
  if (( ${#specs[@]} == 0 )); then
    echo "SKIP features: no numbered specs in $REPO/features/"
    return 0
  fi
  for f in "${specs[@]}"; do
    local name wt
    name="$(basename "$f" .md)"
    wt="$REPO/../wt-$name"
    [[ -d "$wt" ]] || git worktree add "$wt" -b "feat/$name"
    (
      cd "$wt"
      run_claude "feat-$name" \
        "Implement the feature spec at $f for this checkout.
Follow the spec's Files to change list — do not touch unrelated files.
Add tests where the spec asks for them.
Commit on the current branch with a message that references the spec filename.
Do not push. Do not open a PR."
    ) &
  done
  wait
  echo "OK features"
}

do_deploy() {
  if [[ "$DEPLOY_REMOTE" == "1" ]]; then
    echo "preflight: pinging $REMOTE_HOST..."
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_HOST" 'docker --version' \
      || { echo "FAIL: cannot reach '$REMOTE_HOST'. Check: host up, VPN connected, ssh key auth"; exit 1; }
    rsync -az --delete \
      --exclude '.git' --exclude 'logs' --exclude 'audit' \
      --exclude 'node_modules' --exclude 'wt-*' \
      "$REPO"/ "$REMOTE_HOST:$REMOTE_PATH/"
    ssh "$REMOTE_HOST" "cd $REMOTE_PATH && docker compose up -d --build && docker compose ps"
    echo "OK deployed remote -> http://$REMOTE_HOST"
  else
    docker compose up -d --build
    docker compose ps
    echo "OK deployed local -> see ports above"
  fi
}

case "$STAGE" in
  audit)         do_audit ;;
  plan-features) do_plan_features ;;
  features)      do_features ;;
  deploy)        do_deploy ;;
  all)           do_audit; do_plan_features; do_features; do_deploy ;;
  *) echo "usage: $0 [audit|plan-features|features|deploy|all]"; exit 2 ;;
esac

project-burnside-www-production on  main [?] on ☁️  (us-west-2) on ☁️  support@burnsideproject.ai 
❯ 
    | tee "$raw" \
    | jq -rj '
        if .type=="assistant" then
          (.message.content[]?
            | if .type=="text" then .text
              elif .type=="tool_use" then "\n[tool: \(.name)] \(.input | tostring | .[0:200])\n"
              else empty end)
        elif .type=="result" then "\n\n--- done (\(.subtype // "ok")) ---\n"
        else empty end' \
    | tee "$pretty"
  echo ""
}

do_audit() {
  if [[ -s "$AUDIT/reports/$DATE.md" ]]; then
    echo "SKIP audit: $AUDIT/reports/$DATE.md already exists"
    return 0
  fi
  run_claude audit "Audit this repository. Cover:
- Security: secrets in code, insecure deps, OWASP-style issues
- Code quality: dead code, complexity hotspots, anti-patterns
- Test coverage: gaps, missing critical paths
- Dependencies: outdated, known CVEs
- Architecture: observations and recommendations

Write ONE markdown report to $AUDIT/reports/$DATE.md.
Do NOT commit. Do NOT open a PR. Do NOT modify any source files.
Just write that one report file and stop."
  [[ -s "$AUDIT/reports/$DATE.md" ]] || { echo "FAIL: audit report not written"; exit 1; }
  echo "OK audit -> $AUDIT/reports/$DATE.md"
}

do_plan_features() {
  local report="$AUDIT/reports/$DATE.md"
  [[ -s "$report" ]] || { echo "FAIL: no audit report at $report; run './automate.sh audit' first"; exit 1; }
  mkdir -p "$REPO/features"
  run_claude plan-features "Read the audit report at $report.

For each finding that an AI coding agent can safely implement, produce one feature
spec file at $REPO/features/NN-<slug>.md (e.g. 01-gitignore-secrets.md, 02-remove-tls-verify-false.md).
Number them in execution order, lowest-risk-and-most-isolated first.

Each spec MUST contain these sections:
  # <title>
  ## Audit refs
  ## Goal
  ## Files to change (explicit list)
  ## Steps (concrete, ordered)
  ## Acceptance criteria
  ## Out of scope

EXCLUDE from the feature list anything that requires human action and write those
to a separate $REPO/features/HUMAN-ACTIONS.md (rotating real credentials in
GCP/Stripe/Redis consoles, regenerating DJANGO_SECRET_KEY in production env,
git-history rewrites to purge secrets, branch-protection settings, dependabot
enablement on github.com).

EXCLUDE high-blast-radius refactors (splitting the 2,437-line models.py, the
1,910-line config.py, consolidating dual service layers) — list those in
$REPO/features/DEFERRED.md with one-line rationale. They need design discussion
first.

Spec files only. Do not modify any source files. Do not commit."
  ls -1 "$REPO/features/"*.md 2>/dev/null | head -1 >/dev/null \
    || { echo "FAIL: planner produced no specs in $REPO/features/"; exit 1; }
  echo "OK plan -> $REPO/features/ ($(ls -1 "$REPO/features/"*.md 2>/dev/null | wc -l | tr -d ' ') specs)"
}

do_features() {
  shopt -s nullglob
  # only numbered specs are executable; HUMAN-ACTIONS.md and DEFERRED.md are skipped
  local specs=("$REPO"/features/[0-9]*.md)
  if (( ${#specs[@]} == 0 )); then
    echo "SKIP features: no numbered specs in $REPO/features/"
    return 0
  fi
  for f in "${specs[@]}"; do
    local name wt
    name="$(basename "$f" .md)"
    wt="$REPO/../wt-$name"
    [[ -d "$wt" ]] || git worktree add "$wt" -b "feat/$name"
    (
      cd "$wt"
      run_claude "feat-$name" \
        "Implement the feature spec at $f for this checkout.
Follow the spec's Files to change list — do not touch unrelated files.
Add tests where the spec asks for them.
Commit on the current branch with a message that references the spec filename.
Do not push. Do not open a PR."
    ) &
  done
  wait
  echo "OK features"
}

do_deploy() {
  if [[ "$DEPLOY_REMOTE" == "1" ]]; then
    echo "preflight: pinging $REMOTE_HOST..."
    ssh -o BatchMode=yes -o ConnectTimeout=5 "$REMOTE_HOST" 'docker --version' \
      || { echo "FAIL: cannot reach '$REMOTE_HOST'. Check: host up, VPN connected, ssh key auth"; exit 1; }
    rsync -az --delete \
      --exclude '.git' --exclude 'logs' --exclude 'audit' \
      --exclude 'node_modules' --exclude 'wt-*' \
      "$REPO"/ "$REMOTE_HOST:$REMOTE_PATH/"
    ssh "$REMOTE_HOST" "cd $REMOTE_PATH && docker compose up -d --build && docker compose ps"
    echo "OK deployed remote -> http://$REMOTE_HOST"
  else
    docker compose up -d --build
    docker compose ps
    echo "OK deployed local -> see ports above"
  fi
}

case "$STAGE" in
  audit)         do_audit ;;
  plan-features) do_plan_features ;;
  features)      do_features ;;
  deploy)        do_deploy ;;
  all)           do_audit; do_plan_features; do_features; do_deploy ;;
  *) echo "usage: $0 [audit|plan-features|features|deploy|all]"; exit 2 ;;
esac

project-burnside-www-production on  main [?] on ☁️  (us-west-2) on ☁️  support@burnsideproject.ai 
❯ 
