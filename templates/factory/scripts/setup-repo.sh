#!/usr/bin/env bash
# Apply factory gating to one code repo: labels, issue templates, CODEOWNERS,
# CI/deploy workflows, and the branch ruleset. Run from this scripts/ dir.
#   scripts/setup-repo.sh <org>/<repo>
#   scripts/setup-repo.sh <org>/<repo> --stage-files
#
# --stage-files (opt-in, default OFF; ADR-0007): instead of only PRINTING the
# ".github + CODEOWNERS" hand-copy instructions, clone the target repo, copy the
# governance subset (CODEOWNERS, .github/ISSUE_TEMPLATE/, PULL_REQUEST_TEMPLATE.md)
# copy-if-absent, and OPEN a review PR. It is open-only (never merges/approves/
# force-pushes), copy-if-absent (never clobbers the repo's own files), stages NO
# workflows, and is best-effort (a failure warns and the run still applies
# labels/rulesets/environments). Without the flag, behaviour is byte-for-byte
# unchanged (the instructions are printed, no clone/branch/push/PR happens).
#
# Ruleset selection is data-driven via the config root's .factory/ruleset-map.tsv (ADR-0006 /
# SPEC-019 TICKET-101 — instance routing, not vendored); precedence RULESET= override >
# .factory/ruleset-map.tsv manifest > greenfield ruleset.json (vendored generic default).
set -euo pipefail

# Args: <owner/name> plus the optional opt-in --stage-files flag and --dry-run, in any order.
REPO=""
STAGE_FILES=0
# --dry-run / plan mode (SPEC-019 TICKET-104): render intended mutations, make ZERO GitHub
# mutation, so `factory provision` and `factory sync` share ONE mutation path.
DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --stage-files) STAGE_FILES=1 ;;
    --dry-run) DRY_RUN=1 ;;
    -*) echo "error: unknown option '$arg'" >&2; exit 1 ;;
    *)  if [ -z "$REPO" ]; then REPO="$arg"; else echo "error: unexpected argument '$arg'" >&2; exit 1; fi ;;
  esac
done
[ -n "$REPO" ] || { echo "usage: setup-repo.sh <owner/name> [--stage-files] [--dry-run]" >&2; exit 1; }

# gh_mut — THE mutation guard. In dry-run it RENDERS the intended `gh` call and returns without
# mutating; otherwise it runs `gh` unchanged. READS (ruleset list, `--json`) are NEVER routed
# through it — they must run in BOTH modes to compute the plan.
gh_mut() { if [ "${DRY_RUN:-0}" = 1 ]; then printf 'would: gh %s\n' "$*"; else gh "$@"; fi; }

HERE="$(cd "$(dirname "$0")/.." && pwd)"   # the factory bundle root

# The ADR-0007 git-write staging skeleton lives ONCE in lib/stage-files.sh (SPEC-013b
# C-LIB extraction). Source it by a BASH_SOURCE-resolved path (never $PWD) so it is found
# regardless of the caller's cwd, mirroring the sibling scripts (#43/#44/#45).
STAGE_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=templates/factory/scripts/lib/stage-files.sh disable=SC1091
. "$STAGE_LIB_DIR/lib/stage-files.sh"

# Rulesets ship as report-only ('evaluate') so onboarding a repo never blocks an
# in-flight PR. They do NOT actually gate merges until flipped to 'active'. Set
# ENFORCEMENT=active to apply them enforcing from the start (do this once CI is green).
ENFORCEMENT="${ENFORCEMENT:-evaluate}"
case "$ENFORCEMENT" in
  evaluate|active) ;;
  *) echo "error: ENFORCEMENT must be 'evaluate' or 'active' (got '$ENFORCEMENT')" >&2; exit 1 ;;
esac

echo ">> labels"

mk_label() {
  gh_mut label create "$1" --repo "$REPO" --color "$2" --description "$3" --force
}

# Labels that are NOT part of the Stage line. This script is THE ONLY label path
# (SPEC-016 / TICKET-067 AC16): the pack's separate label-setup.sh is deleted, because
# two provisioners meant the final colour of a label depended on invocation order.
# Blank and '#' rows are skipped so the table can carry section headings.
#
# NO gate:* family is provisioned. After gate-enforcer.yml is dropped nothing enforces
# those labels, and creating them would imply a control that does not exist. The lone
# 'gate:blocked' below is a MOTOR STATUS SIGNAL written by floor-motor.yml on phase
# failure — not a gate control — and keeps its existing b60205.
while IFS='|' read -r name color desc; do
  case "$name" in ''|\#*) continue ;; esac
  mk_label "$name" "$color" "$desc"
done <<'LABELS'
# lifecycle
epic|6f42c1|SPEC-XXX umbrella
task|0e8a16|TICKET-XXX work item
gate:blocked|b60205|a required gate is failing
audit:pass|0e8a16|audit cleared
audit:fail|b60205|audit found blocking issues
incident|d93f0b|from Observe stage
skip-ticket|ededed|bypass the PR ticket-reference check (infra/factory PRs)
# type:* — one row per option of the board's "Work Type" single-select field, which
# setup-project.sh creates as "Spec,Ticket,Epic,Bug,Feature Request". Keep the two in step.
# The FIELD is "Work Type", not "Type": "Type" is a reserved Projects v2 field name and the
# API rejects it (see setup-project.sh). The LABEL prefix stays `type:*` — labels have no
# such restriction, and renaming the prefix would orphan existing labels for no gain.
type:spec|6f42c1|Type=Spec — a SPEC-XXX specification issue
type:ticket|6f42c1|Type=Ticket — a TICKET-XXX work item
type:epic|6f42c1|Type=Epic — a multi-spec umbrella
type:bug|6f42c1|Type=Bug — a defect report
type:feature-request|6f42c1|Type=Feature Request — pre-spec intake
# priority:* — one row per option of the board's "Priority" single-select field,
# which setup-project.sh creates as "P0,P1,P2,P3". Keep the two in step.
priority:p0|d93f0b|Priority=P0 — production break or security issue
priority:p1|f97583|Priority=P1 — major feature blocked
priority:p2|dba901|Priority=P2 — important, not urgent
priority:p3|bfd4e2|Priority=P3 — nice to have
# status:* — triage signals WRITTEN BY the retained workflows. These are not optional
# decoration: `gh issue edit --add-label` and `gh issue create --label` FAIL on a label the
# repo does not have, so a missing row here aborts the job at runtime. Every status:* label
# referenced by any workflow or issue template must appear below — enforced by
# tests/factory/test-label-coverage.sh.
# They are deliberately NOT stage:* (AC13 bars retained workflows from writing the motor's
# drive signal) and NOT gate:* (no gate enforcement exists after SPEC-016 — see ADR-0013 §d).
status:needs-triage|ededed|awaiting triage — set by feature-request-to-spec.yml on intake
status:needs-info|ededed|missing required content — set by issue-template-validator.yml (report-only)
LABELS

# stage:* labels come from THE STAGE CONTRACT (SPEC-016 / TICKET-067):
# ../stage-map.tsv, the single source of truth shared with setup-project.sh,
# board-sync.sh and metrics.sh. Adding a stage there creates its label here
# automatically — the two can no longer drift apart.
# NOTE: reuse the bundle-root $HERE set at :32 — do NOT redefine it. An earlier revision
# of this block shadowed it with the scripts/ dir, which silently repointed ruleset.json
# and the .github/ copy paths one level too deep.
STAGE_MAP="$HERE/stage-map.tsv"
[ -f "$STAGE_MAP" ] || { echo "::error::stage-map.tsv not found at $STAGE_MAP" >&2; exit 1; }

while IFS="$(printf '\t')" read -r name _opt color desc; do
  case "$name" in
    stage:*) [ -n "$color" ] && mk_label "$name" "$color" "$desc" ;;
    *) : ;;
  esac
done < "$STAGE_MAP"

echo ">> .github + CODEOWNERS (committed via a PR by the caller)"
echo "   copy these into the repo working tree, then open a PR:"
echo "     $HERE/.github/   ->  <repo>/.github/"
echo "     $HERE/CODEOWNERS ->  <repo>/CODEOWNERS  (or .github/CODEOWNERS)"

# stage_governance_files — TICKET-025 / ADR-0007: the opt-in --stage-files auto-PR. The
# LARGEST GitHub-mutation surface in the factory: it CLONES the target repo, branches,
# copies the governance subset copy-if-absent, commits, pushes the branch, and OPENS a PR
# (a human reviews + merges). The ADR-0007 guardrail skeleton (C1–C8 clone/branch/copy-if-
# absent/no-force/open-only/ephemeral-clone/best-effort) lives ONCE in lib/stage-files.sh
# (SPEC-013b C-LIB); this function only supplies the governance DATA (branch, title, body,
# and the copy-if-absent file set) and calls stage_files_pr with needs-workflow-scope=0 —
# the governance path stages NO workflows and needs no widened credential.

# stage_governance_copy <clone-dir> — the copy-if-absent file set for the governance subset
# (C6). Stages ONLY {CODEOWNERS, .github/ISSUE_TEMPLATE/*, .github/PULL_REQUEST_TEMPLATE.md},
# each via the lib's stage_files_cp_if_absent primitive so an existing repo-owned file is
# preserved byte-for-byte and NO workflow is ever staged. CODEOWNERS honours all three
# GitHub-valid locations — add to root only if none exists.
stage_governance_copy() {
  local dir="$1" f name
  if [ ! -e "$dir/CODEOWNERS" ] && [ ! -e "$dir/.github/CODEOWNERS" ] && [ ! -e "$dir/docs/CODEOWNERS" ]; then
    stage_files_cp_if_absent "$HERE/CODEOWNERS" "$dir/CODEOWNERS"
  fi
  mkdir -p "$dir/.github/ISSUE_TEMPLATE"
  for f in "$HERE"/.github/ISSUE_TEMPLATE/*; do
    [ -e "$f" ] || continue
    name="$(basename "$f")"
    stage_files_cp_if_absent "$f" "$dir/.github/ISSUE_TEMPLATE/$name"
  done
  stage_files_cp_if_absent "$HERE/.github/PULL_REQUEST_TEMPLATE.md" "$dir/.github/PULL_REQUEST_TEMPLATE.md"
}

stage_governance_files() {
  stage_files_pr "$REPO" "factory/stage-governance-files" \
    "chore: stage factory governance files (.github + CODEOWNERS)" \
    "Automated by setup-repo.sh --stage-files (ADR-0007). Adds the factory governance subset (CODEOWNERS, .github/ISSUE_TEMPLATE, .github/PULL_REQUEST_TEMPLATE.md) copy-if-absent, so the applied ruleset's require_code_owner_review has a CODEOWNERS to resolve. Open-only: a human reviews and merges." \
    stage_governance_copy 0
}

if [ "$STAGE_FILES" -eq 1 ]; then
  if [ "${DRY_RUN:-0}" = 1 ]; then
    # ADR-0007 git-write surface (clone/branch/push/PR) — a dry-run must make ZERO mutation, so it
    # is rendered, never executed.
    echo ">> --stage-files (dry-run): would stage the governance subset via an open-only PR (ADR-0007) — SKIPPED"
  else
    echo ">> --stage-files: staging the governance subset via an open-only PR (ADR-0007)"
    # C8/ADR-0003 best-effort: run in a subshell so (a) the EXIT trap cleans the temp clone on
    # every path incl. failure, and (b) a staging failure warns but never aborts the rest of
    # the run (rulesets / naming / environments still apply; exit-code contract unchanged).
    if ! ( stage_governance_files ); then
      echo "WARNING: --stage-files could not open the governance PR; stage manually per the printed instructions above. Continuing with rulesets/naming/environments." >&2
    fi
  fi
fi

# resolve_ruleset <owner/name> — data-driven ruleset selection (ADR-0006). Maps a repo
# basename ('${REPO##*/}') to its tailored ruleset via the TSV manifest.
#
# SPEC-019 (TICKET-101): the manifest + tailored rulesets are INSTANCE data and live at the
# CONFIG ROOT's .factory/ (spec.rulesets.routingFile), NOT in the vendored framework tree — so an
# adopting org routes its own repos without editing framework files that name another org's repos.
# The config root is resolved by git toplevel (never $PWD-relative beyond that). The greenfield
# report-only ruleset.json remains a VENDORED generic default at $HERE.
#
# jq-free (control flow, not a data transform), Bash-3.2 portable ('while IFS=$'\t' read', '< file'
# redirect — no subshell var-scope trap). FAIL-SAFE (C7): column 2 is a BARE filename joined to the
# .factory/ base and 'test -f'-validated; a value containing a path separator, '..', or an empty/
# missing/unmatched row degrades to the greenfield ruleset.json — never a wrong/over-permissive
# tailored pick, never an abort under set -e. The resolved path is never eval'd.
resolve_ruleset() {
  local repo="$1" here="$HERE"
  local ruleset="$here/ruleset.json"       # greenfield fallback (vendored generic default)
  local croot rbase manifest key file
  croot="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [ -n "$croot" ] || { printf '%s\n' "$ruleset"; return 0; }
  rbase="$croot/.factory"
  manifest="$rbase/ruleset-map.tsv"
  if [ -f "$manifest" ]; then
    while IFS=$'\t' read -r key file; do
      key="${key%$'\r'}"; file="${file%$'\r'}"     # N1: strip a trailing CR (CRLF-committed manifest)
      case "$key" in ''|\#*) continue ;; esac      # skip blank / comment rows
      if [ "$key" = "${repo##*/}" ]; then
        case "$file" in
          */*|*..*|'') ;;                           # C7: reject path sep / '..' / empty -> greenfield
          *) if [ -f "$rbase/$file" ]; then ruleset="$rbase/$file"; fi ;;  # confined to .factory/, test -f
        esac
        break
      fi
    done < "$manifest"
  fi
  printf '%s\n' "$ruleset"
}

echo ">> branch ruleset (main gates) — per-repo required checks reconciled to real CI"
# RULESET=<path> override (SPEC-007 C14): point setup-repo.sh at a reconciled ruleset
# (e.g. from reconcile-ci-checks.sh) without touching the manifest. When set it supersedes
# the manifest lookup; when UNSET selection is data-driven via ruleset-map.tsv (the pinned
# routing-named repos resolve to their variant, any other repo -> greenfield
# ruleset.json). Validate before use — must exist and be valid JSON; quoted everywhere;
# never eval'd. Precedence: RULESET= override > ruleset-map.tsv manifest > greenfield.
RULESET="${RULESET:-}"
if [ -n "$RULESET" ]; then
  [ -f "$RULESET" ] || { echo "error: RULESET='$RULESET' not found or not a file" >&2; exit 1; }
  jq -e . "$RULESET" >/dev/null 2>&1 || { echo "error: RULESET='$RULESET' is not valid JSON" >&2; exit 1; }
else
  RULESET="$(resolve_ruleset "$REPO")"
fi
echo "   using $(basename "$RULESET")"

# POST a ruleset, distinguishing "already exists" (benign, idempotent re-run) from a
# real failure (auth/network/malformed) — the old `|| echo "may already exist"`
# reported every error as benign, hiding genuinely broken setups.
apply_ruleset() { # apply_ruleset <name> <json-file> <success-msg>
  local name="$1" file="$2" ok="$3" out id body
  # Desired body: strip the human-readable _comment (the API rejects it) and set
  # enforcement to $ENFORCEMENT. Built once; used for both create and update so a re-run
  # is a true sync (enforcement AND any reconciled required checks).
  body="$(jq --arg e "$ENFORCEMENT" 'del(._comment) | .enforcement=$e' "$file")"
  if [ "${DRY_RUN:-0}" = 1 ]; then
    # Render the POST; do NOT feed the body to `gh api --input -` (that would consume/POST it).
    # The create-then-update-by-name dance is a mutation path and is skipped entirely in dry-run.
    printf 'would: gh %s\n' "api --method POST repos/$REPO/rulesets --input - (ruleset '$name', enforcement=$ENFORCEMENT)"
    echo "   $ok"
    return 0
  fi
  # CREATE on first onboarding (POST). If a ruleset with this name already exists the
  # POST 422s ("... already exists" / "name must be unique") — then UPDATE it in place so
  # `ENFORCEMENT=active` on a re-run ACTUALLY flips the gate (the previous version left it
  # untouched, so the documented flip never took). The update endpoint is
  # PUT /repos/{repo}/rulesets/{id} — NOT PATCH, which 404s. The id is looked up by name
  # among the repo-OWNED rulesets only (includes_parents=false), so an org-inherited
  # ruleset of the same name is never mistaken for this one. Name is a trusted literal
  # from the call sites and is bound via jq --arg (no injection).
  if out="$(printf '%s' "$body" | gh api --method POST "repos/$REPO/rulesets" --input - 2>&1)"; then
    echo "   $ok"
  elif printf '%s' "$out" | grep -qiE 'already exists|name.*(taken|exists|unique)'; then
    id="$(gh api "repos/$REPO/rulesets?includes_parents=false" \
            | jq -r --arg n "$name" 'map(select(.name==$n)) | .[0].id // empty' 2>/dev/null)"
    if [ -n "$id" ] && out="$(printf '%s' "$body" | gh api --method PUT "repos/$REPO/rulesets/$id" --input - 2>&1)"; then
      echo "   '$name' ruleset updated in place (enforcement=$ENFORCEMENT)"
    else
      echo "::error::'$name' ruleset exists but in-place update (PUT id=${id:-none}) failed for $REPO:" >&2
      printf '%s\n' "$out" >&2
      return 1
    fi
  else
    echo "::error::'$name' ruleset POST failed for $REPO:" >&2
    printf '%s\n' "$out" >&2
    return 1
  fi
}

apply_ruleset factory-main-gates "$RULESET" \
  "ruleset applied (enforcement=$ENFORCEMENT)"

echo ">> naming ruleset (branch-name convention on non-default branches)"
apply_ruleset factory-naming "$HERE/ruleset.naming.json" \
  "factory-naming ruleset applied (enforcement=$ENFORCEMENT)"

echo ">> environments (deploy gate)"
# Environments are a paid GitHub feature: the PUT 422s on free-tier orgs. Per
# ADR-0003 this best-effort side effect is warn-and-continue, not fatal — a 422
# must not abort the run before the banner below. Keep >/dev/null on the success
# path (audit N1: success JSON off stdout) but NOT stderr, so gh surfaces the 422.
ENV_SKIPPED=0
if [ "${DRY_RUN:-0}" = 1 ]; then
  # Render the PUTs; the best-effort 422 handling is a live-API concern and is skipped in dry-run.
  printf 'would: gh %s\n' "api --method PUT repos/$REPO/environments/staging"
  printf 'would: gh %s\n' "api --method PUT repos/$REPO/environments/production -F wait_timer=0"
  echo "   (dry-run: deploy environments not created)"
else
  gh api --method PUT "repos/$REPO/environments/staging"   >/dev/null \
    || { ENV_SKIPPED=1; echo "WARNING: 'staging' environment not created (free-tier org or insufficient scope; see 422 above). DEPLOY PROTECTION IS NOT ACTIVE. Required reviewers must be configured manually before deploys are gated." >&2; }
  gh api --method PUT "repos/$REPO/environments/production" \
    -F wait_timer=0 >/dev/null \
    || { ENV_SKIPPED=1; echo "WARNING: 'production' environment not created (free-tier org or insufficient scope; see 422 above). DEPLOY PROTECTION IS NOT ACTIVE. Required reviewers must be configured manually before deploys are gated." >&2; }
  if [ "$ENV_SKIPPED" -ne 0 ]; then
    echo "   deploy environment(s) SKIPPED — no deploy protection created (see WARNINGs above)"
  else
    echo "   production environment created WITHOUT a required reviewer (see banner below)"
  fi
fi

echo "done: $REPO"
echo
echo "=================================================================="
if [ "$ENFORCEMENT" != "active" ]; then
  echo " GATES ARE NOT FULLY ENFORCING YET — manual steps remain:"
  echo "  1. Rulesets applied in '$ENFORCEMENT' (report-only) mode — they do NOT"
  echo "     block merges. Flip to enforcing once CI is green: re-run with"
  echo "     ENFORCEMENT=active (idempotent — updates the existing ruleset in"
  echo "     place), or flip in repo Settings ▸ Rules ▸ Rulesets."
else
  echo " RULESETS ENFORCING (active). ✓  Remaining manual step:"
fi
echo "  2. The 'production' environment has NO required reviewer or wait timer."
echo "     Deploys to prod are UNGATED until you add reviewers in:"
echo "     Settings ▸ Environments ▸ production ▸ Required reviewers."
echo "=================================================================="
