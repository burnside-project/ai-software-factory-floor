#!/usr/bin/env bash
# Thin wrapper -> the single shared implementation in lib/sync-issues.sh.
# Kept so manual invocation and the sync-issues.yml Action run ONE proven code
# path (mirroring board-sync.yml -> board-sync.sh). All logic — the "<ID>:"
# title-prefix match, O1 no-write-back, O3 skip-with-notice, O4 Stage-on-create-
# only, and the C3 injection hardening — lives in lib/sync-issues.sh. The CLI/env
# signature is unchanged: <path> plus ORG / PROJECT / SPEC_FILTER.
#
#   scripts/sync-issues.sh <path>            # a dir or a single .md file
#   SPEC_FILTER=SPEC-005 scripts/sync-issues.sh ../../../tickets
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "$DIR/lib/sync-issues.sh" "$@"
