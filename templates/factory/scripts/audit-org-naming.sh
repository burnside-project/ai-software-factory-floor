#!/usr/bin/env bash
# Audit org repo names against the factory naming convention. Read-only.
# Flags repos whose names match none of the allowed patterns (excluding legacy
# exceptions). Run ad-hoc or on a schedule.
#   scripts/audit-org-naming.sh            # human table
#   scripts/audit-org-naming.sh --flags    # only non-conforming (exit 1 if any)
set -euo pipefail

MODE="${1:-}"

# Naming allowlist comes from the compiled .factory/factory.env (NAMING_PATTERNS) — a TAB-
# delimited list of anchored regexes authored in factory.config.yaml, never a hardcoded literal
# here (SPEC-019 TICKET-100). Sourced from the CONFIG ROOT (git toplevel), so a consumer's own
# patterns apply; the runtime reads the compiled shell value, never parses YAML (AC9).
_factory_load_naming() {
  [ -n "${NAMING_PATTERNS:-}" ] && return 0
  local top
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  # shellcheck source=/dev/null
  [ -n "$top" ] && [ -f "$top/.factory/factory.env" ] && . "$top/.factory/factory.env"
  return 0
}

allowed() {
  _factory_load_naming
  local name="$1" pat
  local IFS='	'   # split NAMING_PATTERNS on TAB
  # shellcheck disable=SC2086  # deliberate word-split of the TAB-delimited pattern list
  for pat in ${NAMING_PATTERNS:-}; do
    [ -n "$pat" ] || continue
    [[ "$name" =~ $pat ]] && return 0
  done
  return 1
}

# Sourcing guard: when this file is SOURCED (e.g. by scripts/provision.sh to reuse the
# allowed() naming allowlist — SPEC-013b C-DRIFT), expose allowed() and STOP (ORG is resolved
# below the guard, so a sourcer never triggers the fail-closed require);
# do NOT run the org-wide audit below (which calls `gh repo list`). The audit runs ONLY on
# direct execution — that path is byte-for-byte unchanged.
case "${BASH_SOURCE[0]}" in
  "$0") ;;        # executed directly — run the audit
  *) return 0 ;;  # sourced — helpers are now defined in the caller; do not audit
esac

# SPEC-019 (TICKET-099): ORG for the org-wide audit comes from the compiled .factory/factory.env,
# never a home default. Resolved AFTER the sourcing guard so a sourcer (provision.sh) that only
# wants allowed() never triggers the fail-closed require nor needs the runtime-env helper present.
# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib/factory-runtime-env.sh"
factory_load_config
factory_require ORG

flagged=0
while IFS= read -r name; do
  if allowed "$name"; then
    [ "$MODE" = "--flags" ] || printf "PASS  %s\n" "$name"
  else
    printf "FLAG  %s\n" "$name"; flagged=1
  fi
done < <(gh repo list "$ORG" --limit 200 --json name --jq '.[].name' | sort)

if [ "$MODE" = "--flags" ] && [ "$flagged" -eq 1 ]; then exit 1; fi
