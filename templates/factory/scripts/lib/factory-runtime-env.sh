#!/usr/bin/env bash
# factory-runtime-env.sh — the RUNTIME source for a factory instance's identity (SPEC-019 /
# TICKET-099). Sourced, never executed. Bash 3.2; shellcheck clean.
#
# THE MOVE (TICKET-099): the org/project values that used to be baked into each hot-path script
# as a "point home" default (an ORG assignment falling back to the framework author's org) now
# live ONLY in the
# COMPILED `.factory/factory.env` at the consumer's config-root — a file `factory sync` (TICKET-097)
# generates from factory.config.yaml and that is NEVER vendored into a consumer's bundle. A script
# resolves its identity by sourcing THIS helper and calling:
#
#   factory_load_config      # fill any UNSET ORG/PROJECT from the config-root .factory/factory.env
#   factory_require ORG      # (+ PROJECT) — fail CLOSED, loud, non-zero, if still unset
#
# Two properties are load-bearing:
#   1. EXPLICIT WINS — an `ORG=… script` (or a workflow `env: ORG:`) is honoured verbatim; the
#      compiled file only fills what the caller left unset (the old fill-if-unset precedence, minus
#      the home literal).
#   2. FAIL CLOSED — a missing required value is a LOUD non-zero exit, never a silent default to
#      the framework author's org. board-sync must never write to the wrong org and report success.
#
# CONFIG-ROOT anchor: the consumer repo root, found with `git rev-parse --show-toplevel` (the same
# config-root pattern as lib/factory-discovery.sh) — NEVER engine-relative, so a vendored copy of
# this helper reads the CONSUMER's config, not the framework author's.

# factory_load_config — fill UNSET ORG/PROJECT from the config-root .factory/factory.env.
# A no-op for any value the caller already set (explicit wins). Silent when no config exists —
# it is factory_require's job, not this function's, to fail closed.
factory_load_config() {
  # Nothing to fill if both are already set explicitly.
  # (`${VAR-}` — colon-less — is the set-u-safe "value if SET, else empty"; identical to a
  #  colon-dash default under a -n test, and it keeps the removed home-default shape out of the tree.)
  if [ -n "${ORG-}" ] && [ -n "${PROJECT-}" ]; then
    return 0
  fi

  local top env
  top="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$top" ] || return 0
  env="$top/.factory/factory.env"
  [ -f "$env" ] || return 0

  # Preserve anything the caller passed explicitly: source the compiled file, then restore the
  # pre-source values so an explicit ORG=… / PROJECT=… always wins over the file.
  local _org="${ORG-}" _project="${PROJECT-}"
  # shellcheck source=/dev/null
  . "$env"
  [ -n "$_org" ] && ORG="$_org"
  [ -n "$_project" ] && PROJECT="$_project"
  export ORG PROJECT
  return 0
}

# factory_require NAME [NAME…] — fail CLOSED if any named var is unset/empty.
# Exits non-zero with an explicit message pointing at `factory sync`; NEVER defaults to a home org.
factory_require() {
  local name val
  for name in "$@"; do
    val="${!name:-}"
    if [ -z "$val" ]; then
      printf '::error::%s\n' \
        "$name is unset and no .factory/factory.env was found — run 'factory sync' (SPEC-019); refusing to default to a home org" >&2
      exit 1
    fi
  done
  return 0
}
