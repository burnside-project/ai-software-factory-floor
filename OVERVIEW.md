# Overview — ai-software-factory

A one-page map of the system. For usage start at [`README.md`](README.md); for the
operator flow, [`RUNBOOK-claude-code.md`](RUNBOOK-claude-code.md).

**What it is:** an opinionated, spec-first AI SDLC you drop into any repo — 13 role
subagents that carry a feature from idea to PR, plus the GitHub-native gates that make
each stage *enforced*, not just convention. Optionally, an autonomous motor runs the whole
line lights-out.

**Status:** `VERSION` **0.3.1** · latest release `v0.3.1` (autonomous floor motor,
validated live end-to-end). Everything below is shipped.

---

## The three layers

### 1. Method — the human-driven SDLC
A **14-phase flow**: idea → spec → architecture & security review → tickets → test plan →
**spec gate** → implement → verify → **audit** → docs → PR → **compliance gate** → human
merge. One subagent per role; run it with `/feature-delivery`, archive with `/post-merge`.

- Agents: [`.claude/agents/`](.claude/agents) · flow: [`workflows/feature-delivery.md`](workflows/feature-delivery.md)
- Onboard a repo end-to-end (zero → gated, delivering): [`PROVISIONING.md`](PROVISIONING.md) — the single canonical runbook; `/provisioning:onboard-project` is the guided path through it and `/provisioning:check-readiness` its pre-flight; `/provisioning:activate-gates` is the standalone guided gate-activation for an already-bootstrapped repo; `/provisioning:onboard-repo` is the guided existing-repo (Path B) entry. Commands split by audience — **delivery** (`/feature-delivery`, `/post-merge`) ships into delivered projects; **provisioning** (`/provisioning:onboard-project`, `/provisioning:check-readiness`, `/provisioning:activate-gates`, `/provisioning:onboard-repo`) is factory-root only and filtered out of delivered projects (ADR-0004)
- Install into a repo: `scripts/bootstrap-project.sh` · re-sync + version bump: `scripts/upgrade-project.sh`
- Templates: [`templates/specs`](templates/specs), [`templates/tickets`](templates/tickets), [`templates/reviews`](templates/reviews)

### 2. Enforcement — GitHub-native gates (`templates/factory/`)
The agents produce artifacts; this makes each stage machine-enforced when wired to GitHub.

- **Gates:** required checks (`lint/test/build/verification/audit`), CODEOWNERS approvals,
  naming rulesets, `pr-lint` (conventional titles), `validate-artifacts` (naming **+**
  spec content), environment protection.
- **Identity model** — [`docs/decisions/ADR-0001`](docs/decisions/ADR-0001-gate-identity-model.md):
  2 humans across 8 teams + a **GitHub App builder** (no seat cost) → `author ≠ approver` for free.
- **Scripts:** `setup-repo`, `setup-project`, `setup-teams`, `sync-issues`, `metrics`,
  `audit-org-naming`, `setup-host-repo` (all under `templates/factory/scripts/`). `setup-repo`
  selects the ruleset data-driven via `ruleset-map.tsv` (ADR-0006) and takes an opt-in
  `--stage-files` flag that open-only auto-opens the governance PR (ADR-0007).
- **Go live:** [`ACTIVATE.md`](templates/factory/ACTIVATE.md) (general) or
  [`ROLLOUT.md`](templates/factory/ROLLOUT.md) (SPEC-005 pilot).

### 3. Autonomous floor motor (v0.3.0) — lights-out delivery
GitHub Actions + `claude-code-action`, driven by `stage:*` labels. Design:
[`docs/decisions/ADR-0002`](docs/decisions/ADR-0002-autonomous-floor-motor.md).

```
stage:spec (epic)  → spec + arch/security reviews + tickets + test plan → PR → stage:spec-review (human approves gate)
stage:code (ticket)→ implement → verify → audit → PR → stage:review (human merges)
```

**Motor prepares, human decides:** never merges, never self-approves (prompt + branch
protection). Guardrails: kill switch (`FLOOR_MOTOR_ENABLED`), App-token auth, per-phase
turn/timeout caps, run summaries, failure→incident. Board sync keeps the Project `Stage`
field in step. Enable per [`RUNBOOK-floor-motor.md`](templates/factory/RUNBOOK-floor-motor.md)
+ [`RUNBOOK-github-app.md`](templates/factory/RUNBOOK-github-app.md).

### Plus: the factory holds itself to its own bar
`.github/workflows/ci.yml` runs shellcheck + `bash -n` + a Bash-3.2 portability guard +
JSON validation on every PR to this repo.

---

## Current state & what's next

| | |
|---|---|
| Shipped | v0.2.3 (audit fixes + gate model + App) · v0.3.0 (floor motor T1–T6) · v0.3.1 (Epic #4 / T7 — motor validated live, end-to-end) |

**Honest caveat:** the motor is code-complete, CI-clean, and — as of v0.3.1 — proven
end-to-end by the T7 live run.

## Core invariants
- No code before an accepted spec and a `Ready` spec gate.
- One ticket = one shippable slice; no unrelated refactors.
- Every acceptance criterion has recorded test evidence.
- **Agents open PRs; humans merge.** No agent (or motor) approves its own gate.
