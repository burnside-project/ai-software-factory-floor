# ADR-0011: The factory engine repo runs a lightweight merge gate (intentional ADR-0001 exception)

Status: **Accepted** · Date: 2026-07-11 · Owner: delivery · Supplements [ADR-0001](ADR-0001-gate-identity-model.md)

## Context

[ADR-0001](ADR-0001-gate-identity-model.md) defines the factory's merge-gate model for **product repos**: the GitHub App (bot) authors every PR and — because Apps cannot be CODEOWNERS — **cannot approve**, enforcing `author ≠ approver` for free; the 13 agent roles are the *record* (committed `architecture-review.md`, `security-review.md`, `audit-report.md`, `VERIFY-*.md`), not the approval; and **one human code-owner review** (`required_approving_review_count: 1` + `require_code_owner_review: true`) is the authority. A human merges; the motor/agents never merge or self-approve. This model assumes **two humans** in the org's factory teams.

That model fits product repos (e.g. `burnside-project-marketing-site`, whose `factory-main-gates` ruleset requires a code-owner review, no bypass). It fits the **engine repo (`ai-software-factory`) poorly**: it is **solo-maintained**. GitHub blocks self-approval by the PR author, so requiring a code-owner review on a one-maintainer repo would only force an admin bypass — governance theatre, not separation of duties.

## Decision

The **`ai-software-factory` engine repo runs a deliberately lightweight merge gate**, and this is a **knowing exception to ADR-0001**, not drift:

- The `main-audit-gate` ruleset on `main` requires **status checks only** — `independent-audit` (the live cross-model DeepSeek gate, ADR-0008/0009/0010) plus the four `factory-ci` contexts (`shellcheck`, `syntax`, `bash32-portability`, `json`) — at `enforcement: active`, with **admin bypass** and no `pull_request`/code-owner-review rule. There is no root CODEOWNERS.
- **Approval = the operator's decision to merge.** The machine gate is the cross-model audit + CI; the human authority is the maintainer choosing to merge a green PR. The DeepSeek audit still provides the `author ≠ auditor` independence ADR-0002 promises (a different model reviews the diff) — so "no self-grading" holds even though "author ≠ approver" via a second human does not.
- **The operator performs the merge.** The agent opens/prepares PRs and stops; the maintainer clicks Approve + Merge. The agent does not run `gh pr merge` on this repo.

## Consequences

- **No two-human separation of duties on the engine repo.** Accepted: it is solo-maintained; the real safeguards here are the live DeepSeek audit + CI checks + the maintainer's judgment, not a second approver.
- **The model the factory *ships* is unchanged.** The greenfield/template rulesets (`templates/factory/ruleset.json` and variants) still carry the full ADR-0001 `pull_request` code-owner-review rule; product repos still get the two-human model. This ADR narrows the exception to the engine repo only.
- **If the engine repo gains a second maintainer**, revisit — adding the code-owner-review rule + a CODEOWNERS would then be cheap and meaningful.

## Alternatives considered

- **Enforce ADR-0001 on the engine repo too** — require a code-owner review + add CODEOWNERS. Rejected for now: with one maintainer it reduces to admin-bypass theatre and adds friction without adding a genuine independent approver.
- **Leave it undocumented** (status-checks-only by omission). Rejected: an engine repo that visibly runs a lighter gate than the model it ships should say so on purpose, so the difference reads as a decision, not a misconfiguration.
