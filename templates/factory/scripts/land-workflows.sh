#!/usr/bin/env bash
# land-workflows.sh — the explicit operator verb that stages factory workflow templates into
# a target repo's checkout (SPEC-017 AC17 / TICKET-079; closes SPEC-016 architecture review
# F5 for the SPEC-017 unit only).
#
# WHY THIS EXISTS. Nothing in this repo stages workflow templates. bootstrap-project.sh C7
# and setup-repo.sh deliberately refuse to (ADR-0008: no auto-ship of workflows), and
# provision.sh --upgrade delivers project + labels + rulesets and no workflows at all. That
# was survivable while templates were inert. SPEC-017 makes it fatal: after the cutover
# (TICKET-089) floor-motor.yml no longer drives on `issues: labeled`, so a repo holding the
# new motor WITHOUT stage-arbiter.yml has a belt that drives on nothing and is driven by
# nothing — and no manual path back, because the documented recovery ("re-add the stage
# label") is exactly what stops working.
#
# ADR-0008 IS PRESERVED, NOT RELAXED. That ADR bars a bootstrap from SILENTLY installing a
# workflow. It does not bar an operator from asking for one — enable-audit.sh is the
# precedent this follows. Accordingly: dry-run by DEFAULT, prints every action before taking
# it, applies only on --apply, never clones/branches/pushes/opens a PR. Landing stays a
# human, open-only step.
#
# ATOMIC UNITS. Some workflows are only correct together. floor-motor.yml and
# stage-arbiter.yml are one unit: after TICKET-089 each is inert or broken without the other.
# The unit is declared in DATA below, not in prose, and a partial land is REFUSED with a
# non-zero exit — not warned about. A warning is a thing an operator scrolls past.
#
#   templates/factory/scripts/land-workflows.sh <owner/repo>              # dry run (default)
#   templates/factory/scripts/land-workflows.sh <owner/repo> --apply
#   templates/factory/scripts/land-workflows.sh <owner/repo> --only sync-issues.yml --apply
#
# Run from a checkout of the TARGET repo (CWD), like enable-audit.sh, so files land in that
# repo's tree for the operator to commit and open a PR.
#
# Bash 3.2 (stock macOS) compatible; shellcheck clean.
set -euo pipefail

REPO=""
APPLY=0
ONLY=""
want_only=0

for arg in "$@"; do
  if [ "$want_only" -eq 1 ]; then ONLY="$ONLY $arg"; want_only=0; continue; fi
  case "$arg" in
    --apply)   APPLY=1 ;;
    --dry-run) APPLY=0 ;;
    --only)    want_only=1 ;;
    -*)        echo "error: unknown option '$arg'" >&2; exit 1 ;;
    *)         if [ -z "$REPO" ]; then REPO="$arg"; else echo "error: unexpected argument '$arg'" >&2; exit 1; fi ;;
  esac
done
[ "$want_only" -eq 0 ] || { echo "error: --only needs a workflow filename" >&2; exit 1; }
[ -n "$REPO" ] || { echo "usage: land-workflows.sh <owner/repo> [--apply] [--only <file.yml>]" >&2; exit 1; }

# Same tenant-selector validation as enable-audit.sh (C11): one owner/name, no traversal.
case "$REPO" in
  */*/*|*..*|/*|*/) echo "error: '<owner/repo>' must be a single owner/name (got '$REPO')" >&2; exit 1 ;;
  */*) : ;;
  *) echo "error: '<owner/repo>' must contain one '/' (got '$REPO')" >&2; exit 1 ;;
esac

# ---- two-layout probe (ADR-0008 Context §2) ------------------------------------------
# This script lives at templates/factory/scripts/ in the factory repo and at
# .ai/templates/factory/scripts/ in a bootstrapped host repo. Resolve the bundle from
# BASH_SOURCE, never $PWD — $PWD is the TARGET checkout here, which is a different tree.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_WF="$HERE/.github/workflows"
[ -d "$SRC_WF" ] || { echo "error: workflow templates not found at $SRC_WF" >&2; exit 1; }

DEST_WF=".github/workflows"

# ---- the atomic units, as DATA -------------------------------------------------------
# One unit per line, space-separated members. Landing a proper subset of any unit is
# refused. Add a unit here rather than encoding the rule in a conditional.
UNITS="floor-motor.yml stage-arbiter.yml"

unit_for() { # unit_for <file> -> prints the unit containing it, or nothing
  # `|| true` on the pipeline: with no match the trailing `read` fails, the pipeline exits
  # non-zero, and under `set -euo pipefail` the CALLER's `u="$(unit_for …)"` assignment
  # inherits that status and kills the script. That only happens on the BORING case — a file
  # in no unit — so every atomic-unit assertion passed while an ordinary land died silently.
  { printf '%s\n' "$UNITS" | while IFS= read -r u; do
      for m in $u; do [ "$m" = "$1" ] && { printf '%s' "$u"; return 0; }; done
    done; } || true
}

# ---- what to land --------------------------------------------------------------------
if [ -n "$ONLY" ]; then
  SELECTED="$ONLY"
else
  SELECTED=""
  for u in $UNITS; do SELECTED="$SELECTED $u"; done
fi

# Normalise + validate that each selection exists in the bundle.
CLEAN=""
for f in $SELECTED; do
  [ -n "$f" ] || continue
  case "$f" in */*|*..*) echo "error: --only takes a bare filename (got '$f')" >&2; exit 1 ;; esac
  if [ ! -f "$SRC_WF/$f" ]; then
    # Distinguish "you typo'd" from "this unit member has not been built yet". Before
    # TICKET-082 ships stage-arbiter.yml the default selection legitimately cannot be
    # satisfied, and saying so is more useful than a bare not-found.
    if [ -n "$(unit_for "$f")" ]; then
      echo "error: '$f' is part of an atomic unit but does not exist in the bundle yet." >&2
      echo "       The unit cannot be landed until every member exists." >&2
      echo "       ($f is delivered by SPEC-017 TICKET-082.)" >&2
    else
      echo "error: no such workflow template: $f" >&2
    fi
    exit 1
  fi
  CLEAN="$CLEAN $f"
done
[ -n "$CLEAN" ] || { echo "error: nothing selected" >&2; exit 1; }

# ---- ATOMIC-UNIT ENFORCEMENT: refuse a partial land ----------------------------------
# Checked against the selection PLUS what the target already has, so
# `--only stage-arbiter.yml` is legal on a repo that already carries the motor.
for f in $CLEAN; do
  u="$(unit_for "$f" || true)"
  [ -n "$u" ] || continue
  for m in $u; do
    selected=0
    for s in $CLEAN; do [ "$s" = "$m" ] && selected=1; done
    [ "$selected" -eq 1 ] && continue
    if [ ! -f "$DEST_WF/$m" ]; then
      echo "::error::REFUSED — partial land of an atomic unit." >&2
      echo "  '$f' and '$m' are one unit: after SPEC-017's cutover each is inert or broken" >&2
      echo "  without the other, and the belt has no manual recovery path." >&2
      echo "  Land the unit together:" >&2
      echo "    land-workflows.sh $REPO --only $f --only $m --apply" >&2
      exit 1
    fi
  done
done

# ---- BROKEN BELT detection — reported on EVERY run, not just at land time -------------
# A repo that already holds an intent-driven motor without an arbiter (or vice-versa) is
# already broken before this script runs. Say so every time, with the fix.
broken=""
if [ -d "$DEST_WF" ]; then
  # Iterate UNITS BY LINE. `for u in $UNITS` word-splits, which turned each MEMBER into its
  # own single-member "unit" — and a single-member unit can never be half-landed, so this
  # check silently detected nothing. The atomic-refusal path above happened to still work,
  # which is what made the hole invisible.
  while IFS= read -r u; do
    [ -n "$u" ] || continue
    present=""; missing=""
    for m in $u; do
      if [ -f "$DEST_WF/$m" ]; then present="$present $m"; else missing="$missing $m"; fi
    done
    if [ -n "$present" ] && [ -n "$missing" ]; then
      broken="$broken
  unit [$u]: present:$present  MISSING:$missing"
    fi
  done <<UNITS_EOF
$UNITS
UNITS_EOF
fi
if [ -n "$broken" ]; then
  echo "::warning::BROKEN BELT — this repo holds part of an atomic workflow unit:$broken"
  echo "  remediate:  land-workflows.sh $REPO --apply"
fi

# ---- plan, then apply ----------------------------------------------------------------
[ "$APPLY" -eq 1 ] && mode="APPLY" || mode="DRY RUN (default — pass --apply to write)"
echo ">> land-workflows: $REPO  [$mode]"
echo "   source: $SRC_WF"
echo "   dest:   $(pwd)/$DEST_WF"

changes=0
for f in $CLEAN; do
  if [ -f "$DEST_WF/$f" ] && cmp -s "$SRC_WF/$f" "$DEST_WF/$f"; then
    echo "   = $f (identical — no change)"
    continue
  fi
  if [ -f "$DEST_WF/$f" ]; then action="UPDATE"; else action="CREATE"; fi
  changes=$((changes + 1))
  if [ "$APPLY" -eq 1 ]; then
    mkdir -p "$DEST_WF"
    cp "$SRC_WF/$f" "$DEST_WF/$f"
    echo "   $action $f"
  else
    echo "   would $action $f"
  fi
done

if [ "$changes" -eq 0 ]; then
  echo ">> nothing to do — every selected workflow is already identical (idempotent no-op)"
elif [ "$APPLY" -eq 1 ]; then
  echo ">> landed $changes file(s) into $DEST_WF"
  echo "   NEXT: commit them and open a PR. This verb never commits, pushes, or merges."
else
  echo ">> $changes file(s) would change. Re-run with --apply to write them."
fi
