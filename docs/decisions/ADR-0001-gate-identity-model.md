# ADR-0001: Gate identity model — how GitHub identities satisfy the factory gates

Status: **Accepted** · Date: 2026-07-06 · Owner: delivery

## Context

The factory maps a 14-phase workflow to GitHub-native gates (required status checks,
CODEOWNERS reviews, environment protection). A gate is only meaningful if the identity
that *clears* it differs from the one that *produced* the work. That raises a practical
question the audit surfaced (finding N5): **which GitHub identities hold each role, and
how do PRs actually get the approvals to pass — without inventing an account per role
or increasing cost?**

Constraints for this org:

- **Two humans**, both members of the org's factory teams.
- **Eight factory teams** already exist: `architect`, `backend-engineer`,
  `compliance-reviewer`, `data-engineering`, `release-engineer`, `security-architect`,
  `sre`, `test-engineer`. (There is intentionally **no** `product` or `qa-engineer`
  team — intake folds into `architect`, QA folds into `test-engineer`.)
- **No new paid seats.** On private repos a machine *user* account costs a seat; a
  **GitHub App** does not.
- The goal is **process traceability** (an auditable record of which role did each
  step), not full separation of duties.

## Decision

**Identities**

- **Builder = a GitHub App** (`burnside-factory[bot]`). It authors every PR and pushes
  branches via its installation token. Apps consume no seat, so cost is unchanged.
  Because the *bot* is always the PR author, either human is automatically an
  independent approver (GitHub blocks self-approval by the author).
- **Approvers = the two humans**, both in all eight teams.
  `required_approving_review_count: 1` — whoever is free clears the code-owner review.
- **Checks = Actions `GITHUB_TOKEN`** — free, no identity to manage.

**Gates**

- Required status checks (machine): `lint`, `test`, `build`, `verification`, **`audit`**.
- One CODEOWNERS approval from the team owning the changed paths (either human).
- Production environment: a required human reviewer.
- Rulesets ship `enforcement: "evaluate"`; flip to `active` (via `ENFORCEMENT=active`
  in `setup-repo.sh`) once teams + App + checks are live.

**The role record (not the approval)**

With only two approvers, approval identity cannot attribute 13 roles. The record of
"which role acted" lives in:

- committed artifacts (`architecture-review.md`, `security-review.md`,
  `audit-report.md`, `VERIFY-*.md`),
- the issue lifecycle (labels, assignee handoffs, audit verdict as a comment),
- PR-body sections, and
- a **`Role:` commit trailer** on each commit (`git log --grep '^Role:'`).

**CODEOWNERS** references only teams that exist (verified by `setup-teams.sh`), mapping
paths to the eight teams. `data-engineering` and `sre` are wired in; `product`/`qa`
paths map to `architect`/`test-engineer` until/unless those teams are created.

## Consequences

**Positive**

- Zero new cost: App + Actions token + existing humans/teams.
- `author ≠ approver` holds for free — the bot builds, a human approves.
- The `audit` check is the one machine-enforced, model-independent quality gate, so
  the human's single approval sits on a pre-validated bundle.
- `setup-teams.sh` fails the build if CODEOWNERS references a missing/empty team,
  closing the N5 "fails-open" hole.

**Negative / accepted trade-offs**

- This is **traceability, not separation of duties.** Both humans can clear any gate,
  so if they rubber-stamp, the role reviews are advisory. Mitigation: make the
  deterministic checks (audit verdict, verification doc, tests) carry the real weight.
- One primary human out ⇒ the other must review everything. Acceptable at this size.
- The GitHub App cannot be a CODEOWNER (Apps aren't valid there), so it can only build,
  never approve — which is exactly what we want.

## Alternatives considered

- **A machine user per role** — highest role fidelity, but N paid seats and, if one
  operator holds all tokens, it manufactures fake "independent" approvals (approval
  theater). Rejected on cost and honesty.
- **One human, all gates** — simplest, but a single point with no `author ≠ approver`
  guarantee unless the builder is separate. Superseded by the two-human App model.
- **Partition the eight teams between the two humans** — real pipeline separation
  (different approver at spec vs code), but one primary per role (bus-factor risk).
  Kept as a future option; membership-only change, no code impact.

> **Scope note:** this two-human / code-owner-review model applies to **product repos**.
> The solo-maintained **engine repo** (`ai-software-factory`) runs a lighter status-checks-only
> gate as a knowing exception — see [ADR-0011](ADR-0011-factory-repo-lightweight-gate.md).

## Follow-ups

- Register + install the GitHub App; wire its token where Claude Code runs.
  Step-by-step: `templates/factory/RUNBOOK-github-app.md`.
- Adopt the `audit` job in existing repos' CI before adding `audit` to their per-repo
  rulesets (the greenfield `ruleset.json` already requires it).
- Optionally create `product` / `qa-engineer` teams (`setup-teams.sh --create`) if a
  distinct product-manager or QA gate is wanted.
