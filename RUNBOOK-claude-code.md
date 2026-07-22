# Operator Runbook — Native Claude Code SDLC

How to drive a project end-to-end with this delivery system inside Claude Code.
This is the *native* runbook (slash commands + subagents). The original prose
process lives in [`runbook.md`](runbook.md).

---

## 0. Concepts

- **Subagents** (`.claude/agents/*.md`) — one per role (Product Manager, Architect,
  Security Architect, Tech Lead, QA, Backend/Data Engineer, Test Engineer, SRE,
  Auditor, Documentation Writer, Release Engineer, Compliance Reviewer). Each has
  scoped tools and a single responsibility. Review/planning roles cannot write code.
- **Slash commands** (`.claude/commands/*.md`) — `/feature-delivery` orchestrates
  the whole flow; `/post-merge` archives a merged spec.
- **Artifacts** flow through directories: `specs/{draft,approved,implementing,completed}`,
  `tickets/{backlog,ready,active,completed}`, `verification/{test-plans,results,reviews}`,
  `prs/{open,merged}`, `knowledge/*.yaml`, `docs/delivery-ledger.md`.

---

## 1. Set up a new project

```bash
# from the ai-software-factory repo root
./scripts/bootstrap-project.sh /path/to/new-project
```

This installs the framework into `<new-project>/.ai/`, copies the native
`.claude/agents` and `.claude/commands` to the project root, creates the
lifecycle directories, and seeds `delivery-ledger.md`, `knowledge/*.yaml`, and a
stub `Makefile`.

> The native `.claude/` layer is required: if it is missing or incomplete the
> bootstrap **fails hard** (exit 1) rather than producing a slash-command-less
> install. Pass `--github-only` (before or after the path) to deliberately opt into a
> GitHub-enforcement-only install that skips the Claude Code layer.

Then:

```bash
cd /path/to/new-project
# wire the Makefile to real lint/test/docker commands before relying on `make verify`
```

To refresh the framework in an existing project later:

```bash
/path/to/ai-software-factory/scripts/upgrade-project.sh /path/to/new-project
```

(Upgrade replaces framework assets and `.claude/{agents,commands}`; it never
touches your specs, tickets, verification, knowledge, or docs.)

---

## 2. Deliver a feature

Open Claude Code in the project and run:

```
/feature-delivery <your feature idea, or an intake doc path, or SPEC-XXX to resume>
```

The command walks all phases, delegating each to its subagent and pausing at
the gates. Phase → agent → output:

| # | Phase | Agent | Output | Code? |
|---|---|---|---|---|
| 1 | Spec | product-manager | `specs/draft/SPEC-XXX-<slug>/spec.md` | no |
| 2 | Architecture | architect | `architecture-review.md` (+ ADR) | no |
| 3 | Security | security-architect | `security-review.md` | no |
| 4 | Tickets | tech-lead | `tickets/ready/TICKET-XXX-*.md` | no |
| 5 | Test plan | qa-engineer | `verification/test-plans/TESTPLAN-SPEC-XXX.md` | no |
| 6 | **Spec Gate** | — | `VERDICT: Ready / Needs revision / Too broad` | — |
| 7 | Implementation | backend-engineer / data-engineer | code for approved tickets only | **yes** |
| 8 | Docker test | test-engineer | `make verify` results | runs |
| 9 | Verification | test-engineer | `verification/reviews/VERIFY-SPEC-XXX.md` | runs |
| 10 | **Audit** | auditor | `audit-report.md` (bugs, security, drift, edge cases, missing tests) | no |
| 11 | Documentation | documentation-writer | README / runbooks / architecture / decisions | docs |
| 12 | PR | release-engineer | branch + PR (spec, tickets, evidence, audit, rollback) | git |
| 13 | **Compliance Gate** | compliance-reviewer | `VERDICT: Ready / Needs revision` | no |

### The three gates (non-negotiable)
- **Phase 6 — Spec Gate.** Continue only on `Ready`. `Too broad` → re-slice with
  the tech-lead before any code. This is the primary defense against scope creep.
- **Phase 10 — Audit Gate.** Blocking audit issues must be resolved before Phase 12.
  Loop back through implementation and testing until the audit passes clean.
- **Phase 13 — Compliance Gate.** Stop for human approval. The release-engineer
  opens the PR and stops. **A human merges.** Agents never merge.

---

## 3. After merge

```
/post-merge SPEC-XXX
```

Moves the spec to `specs/completed/`, saves the PR body and final test evidence,
updates `docs/delivery-ledger.md` and `knowledge/{features,tests,repos}.yaml`,
writes an implementation summary, and confirms no active tickets remain.

---

## 4. Invariants (what "good" looks like)

- No code before an accepted spec and a `Ready` spec gate.
- One ticket = one shippable slice (≤ ~3 days); no unrelated refactors.
- Every acceptance criterion has recorded test evidence.
- Every PR carries the full background — spec, epic, and all related tickets/issues — plus rollback notes (`PULL_REQUEST_TEMPLATE.md`).
- The delivery ledger and knowledge files are current after every merge.

---

## 5. Running a single role

You don't have to run the whole pipeline. Invoke any role directly, e.g.:

> Use the **security-architect** subagent to review `specs/draft/SPEC-004-*/spec.md`.

Useful for ad-hoc reviews, re-slicing, or re-verifying after a fix.
