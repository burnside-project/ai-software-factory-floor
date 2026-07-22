# ADR-0003: Best-effort external calls in factory setup scripts must never abort setup

Status: Accepted
Date: 2026-07-07
Deciders: Architect (via SPEC-002)
Related: SPEC-002 (Factory Dogfood Onboarding Fixes), SPEC-001 (Issue Lifecycle Labels), ADR-0001 (gate identity model), ADR-0002 (autonomous floor motor)

> **Note (rebased onto `main`):** This ADR was drafted as "ADR-0001" during SPEC-002 but
> renumbered to **ADR-0003** because `main` had independently merged ADR-0001 (gate identity
> model) and ADR-0002 (autonomous floor motor) while SPEC-002 was in flight. In the same
> window, `main` also refactored `setup-repo.sh`'s ruleset calls into an `apply_ruleset()`
> helper that already realises decision points 1–2 below for rulesets (distinguishing
> "already exists" from a real failure). SPEC-002's remaining contribution is applying the
> **same policy to the deploy-environments PUTs**, which `main` left as bare `>/dev/null`
> calls that still abort under `set -e` on free-tier orgs.

## Context

The factory's `templates/factory/scripts/setup-repo.sh` applies GitHub-side gating to a
target repo: labels, rulesets, and deploy environments. Several of these steps are
**best-effort external side effects** — they depend on org plan tier, pre-existing state,
and API availability:

- Rulesets may already exist (`factory-main-gates`, `factory-naming`) → the POST 409/422s.
- Deploy **environments** are a paid GitHub feature → the PUT returns **HTTP 422 on
  free-tier orgs**.

The script runs under `set -euo pipefail`. The ruleset steps already tolerate failure by
wrapping the call in `… || echo "<warning>"`. The environments steps did **not**: they ran
`gh api … >/dev/null` with no guard, so a 422 aborted the entire run *after* labels and
rulesets had been applied, and `>/dev/null` hid the reason. This left partially-configured
repos and a confusing operator experience during dogfood onboarding of a free-tier org.

This is not a one-off: any future external mutation added to this (or a sibling) setup
script faces the same question — should a best-effort side effect be allowed to kill the run?
A per-call ad-hoc answer produced the inconsistency above. A stated policy prevents it
recurring.

## Decision

**Every best-effort external mutation in the factory's setup scripts is non-fatal:
warn-and-continue, idempotent, and never aborts the run.**

Concretely:

1. Each external side-effect call that can fail on pre-existing state or org-tier limits is
   guarded (`… || echo "   <human-readable reason> — skipping"`), so a failure degrades to a
   visible warning and execution proceeds to the terminal success line.
2. Error output is **surfaced**, not sent to `/dev/null` — the operator must be able to see
   why a step was skipped (free-tier org, already-exists, insufficient scope).
3. Genuinely **required** steps (creating labels the lifecycle depends on) may remain fatal;
   the non-fatal policy applies to *optional/environment-dependent* side effects (rulesets,
   environments). The distinction is documented at each call site by the presence/absence of
   the guard.
4. **Exit-code contract:** a setup run that reached its terminal step exits 0 even if
   optional side effects were skipped. Exit non-zero is reserved for missing arguments and
   for failures of required steps. Callers may rely on "exit 0 == setup reached completion,
   check warnings for skipped optionals."

## Consequences

Positive:
- Setup is robust across org tiers (free and paid) and re-runs (idempotent).
- Error handling is consistent across all external calls; no more silent aborts.
- The exit-code contract is truthful and scriptable by the factory.

Negative / trade-offs:
- A repo can finish "set up" with a missing optional gate (e.g. no `production` environment).
  Mitigation: the warning is visible on stdout/stderr and the missing gate is recoverable by
  re-running after upgrading the org plan; setup-repo is idempotent.
- Requires discipline: future external calls must be classified required vs. best-effort and
  guarded accordingly. This ADR is the reference for that classification.

## Alternatives considered

- **Keep `set -e` abort-on-failure for all calls.** Rejected: makes the script unusable on
  free-tier orgs and produces partially-configured repos with no clear signal — the exact
  dogfound failure.
- **Preflight the org plan tier and branch.** Rejected as over-engineering for a bootstrap
  script; the warn-and-continue guard achieves the same operator outcome with far less code
  and no extra API calls.
