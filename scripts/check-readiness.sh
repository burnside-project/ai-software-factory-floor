#!/usr/bin/env bash
set -euo pipefail

# check-readiness.sh — read-only pre-flight ("step 0" of PROVISIONING.md).
# Verifies the operator's local prerequisites before any provisioning script runs,
# so a missing tool or scope surfaces here instead of failing mid-flow.
#
# STRICTLY READ-ONLY (C2): only `command -v` lookups, `[ -d ]` presence tests, and a
# single `gh auth status` read. No writes, no gh mutations, no git writes, no network
# beyond those. It never surfaces the `gh auth status` output (C1): the scope check
# greps a substring with the grep's own output discarded, never unmasks the credential,
# and every MISSING: line is a static, human-authored string (never interpolates
# captured gh output). Commands are invoked directly — no eval / bash -c (C4).
#
# The 'project'-scope check is ADVISORY: a gh output-format change should prompt the
# operator to run `gh auth refresh`, it is not wired as a hard gate on any script.

fail=0

# C3: each check's non-zero exit is consumed by a trailing `|| { ...; fail=1; }` so
# `set -euo pipefail` cannot abort the run on the first miss — every prerequisite is
# reported. The single `exit 1` at the end fires only off the aggregated $fail.

command -v gh >/dev/null 2>&1 \
  || { echo "MISSING: gh not on PATH (install: https://cli.github.com)"; fail=1; }

command -v jq >/dev/null 2>&1 \
  || { echo "MISSING: jq not on PATH (install: brew install jq)"; fail=1; }

# gh auth status is a READ; its output is discarded so no account/token line is surfaced.
if command -v gh >/dev/null 2>&1; then
  gh auth status >/dev/null 2>&1 \
    || { echo "MISSING: gh not authenticated (run: gh auth login)"; fail=1; }

  # Advisory scope check: pipe gh auth status to `grep -q` with the grep's own output
  # discarded — only a boolean is observed, the raw blob is never printed (C1). The whole
  # pipe sits inside a `|| { ... }` guard so pipefail cannot abort it (C3).
  gh auth status 2>&1 | grep -q 'project' \
    || { echo "MISSING: gh missing 'project' scope (run: gh auth refresh -s project)"; fail=1; }
fi

# .claude/ presence in the factory checkout. Resolve the repo root from THIS script's
# own location (scripts/ -> ..) rather than $PWD, so the pre-flight is correct no matter
# which directory the operator launches it from — running it from scripts/ used to false-
# fail the .claude checks. The `cd` runs in a command-substitution subshell (read-only:
# no state change to the caller's shell). Mirrors reconcile-ci-checks.sh's HERE pattern.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

[ -d "$ROOT/.claude/agents" ] \
  || { echo "MISSING: .claude/agents not found in the factory checkout ($ROOT)"; fail=1; }

[ -d "$ROOT/.claude/commands" ] \
  || { echo "MISSING: .claude/commands not found in the factory checkout ($ROOT)"; fail=1; }

if [ "$fail" -ne 0 ]; then
  echo "Readiness check FAILED — resolve the MISSING items above."
  exit 1
fi

echo "All prerequisites OK"
