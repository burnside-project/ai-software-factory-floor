# AI-First Software Factory — Delivery Model

Status: **Proposed** (foundational model) · Owner: delivery · Date: 2026-06-22

The operating model for delivering software with AI agents on a line that is
**100% gated**: nothing advances a stage unless an automated check or a required
human/agent review passes. It maps the existing 14-phase `.ai/workflows/feature-delivery.md`
onto GitHub-native primitives (Issues, sub-issues, Projects v2, required checks,
CODEOWNERS, Environments) so the paper trail is backed up, visible, and enforced —
not convention.

## Principles

1. **Gated by default.** Every stage transition is a check. No green, no advance. No merge-to-`main` without all required checks. No deploy without the gate before it.
2. **Tests are the deploy trigger.** Deployment is a consequence of green checks + environment approval, never a manual side-channel.
3. **Files are canonical; Issues are the live view and workflow engine.** Long-form artifacts (brief, spec, reviews, verification) stay docs-as-code (PR-reviewed, diffable). Work items (Epics, Tickets) are Issues synced from file front-matter. Issue assignee, labels, comments, and Project fields **drive the cycle** — who owns the work, what stage it's in, and what the last agent decided. One source of truth, one live command center.
4. **The Issue is the handoff point.** Builder → auditor → human transitions are visible as assignee changes. Audit verdicts are posted as Issue comments. A human never needs to open a file to know where work stands — the board tells them.
5. **Every artifact is traceable.** Brief → Epic → Spec → Ticket(Issue) → PR → Checks → Release, linked both directions.
6. **Agents are operators, gates are the QA line.** An `.ai` agent produces an artifact; a gate decides if it passes. The agent never approves its own gate.

## The line: phase → stage → gate

The existing 14 phases collapse into stages, each with an **exit gate** (the
condition that must be machine-true to move on).

| `.ai` phase | Stage | Artifact (canonical) | Exit gate (enforced by) |
|---|---|---|---|---|
| — | **Brief** | `docs/briefs/BRIEF-XXX.md` | PM sign-off (review on brief PR) |
| 1 PM | **Epic/Spec draft** | `docs/specs/SPEC-XXX/spec.md` | spec file merged via PR |
| 2 Architect | Spec | `…/architecture-review.md` | architect approval (CODEOWNERS on spec dir) |
| 3 Security Architect | Spec | `…/security-review.md` | security-architect approval (CODEOWNERS) |
| 4 Tech Lead | **Tickets** | Issues (type: Task) | tickets opened + linked as sub-issues of Epic |
| 5 QA | **Test plan** | `verification/test-plans/TESTPLAN-SPEC-XXX.md` | test plan merged before code |
| 6 **Spec Gate** | gate | `…/spec-gate.md` (VERDICT: Ready) | required "spec-gate" check = Ready |
| 7 Implementation | **Code** | PR (`Closes #<ticket>`) | PR opened against ticket |
| 8 Docker Test | **Test** | CI run (`make verify`) | required checks: lint, unit, contract, integration |
| 9 Verification | **Verify** | `verification/reviews/VERIFY-SPEC-XXX.md` | required "verification" check + doc present |
| 10 Audit | **Audit** | `specs/…/audit-report.md` (test gap diff + issues) | independent test pass matches; no blocking issues |
| 11 Docs | (within Review) | README/runbooks/ADRs | docs-changed check on user-facing change |
| 12 PR | **Review** | PR review | CODEOWNERS approvals (backend + security + qa) |
| 13 Compliance Gate | **Review** | compliance verdict (Ready / Needs revision) | audit report exists, no blocking issues |
| 14 Stop → human | **Deploy** | Release + Actions | Environment protection (staging→prod, required reviewers) |
| — | **Observe** | smoke/health + metrics | post-deploy smoke check; incident Issues on failure |
| — | **Feedback** | Discussion → new Issues | loop back to Brief/Ticket |

"100% gated + tested + deployed based on test" = the **Test → Verify → Review →
Deploy** band is all required checks + Environment rules; merge and deploy buttons
are physically blocked until green.

## GitHub primitive mapping

- **Repo** owns code + Issues + PRs + Wiki + Actions + Environments + Releases. All repo-scoped.
- **Project (v2)** is the org-level cross-repo board — references Issues/PRs from every repo; owns no code. Custom **Stage** field = the line above.
- **Issues can't be repo-less** → cross-repo Epics need a host repo (see Topology).

### Issue type taxonomy + hierarchy

```
Epic   (type: Epic)        ─ one per SPEC-XXX; host repo = roadmap repo if cross-repo
 └─ Task (type: Task)      ─ one per TICKET-XXX; sub-issue, lives in the owning code repo
 └─ Bug / Incident         ─ from Observe/Feedback; link to the Epic or stand alone
```

Sub-issues may live in different repos than their parent Epic — the hierarchy
holds across repos; the Project unifies the view.

### Project (v2) schema

- **Fields:** `Stage` (single-select = the line), `Spec` (text, SPEC-XXX), `Repo`, `Owner/Agent`, `Iteration`, `Risk`, `Gate` (Blocked/Pending/Passed).
- **Views:** Board grouped by `Stage` (the factory floor); Table filtered by `Spec` (traceability); Roadmap by `Iteration` (delivery forecast).

---

## Issue lifecycle: builder → auditor → human

Every `TICKET-XXX` Task Issue cycles through three owners. The Issue's
**assignee**, **labels**, and **comments** are the workflow engine — a human
can see at a glance where any ticket is and what the last agent decided.

### The cycle

```
                   ┌─────────────────────────────┐
                   │  TICKET-XXX Issue            │
                   │  assignee, labels, comments  │
                   └─────────────────────────────┘
                        │              ▲
            assigned    │              │  audit:fail
            to builder  ▼              │  reassign to builder
                  ┌──────────┐    ┌──────────┐
                  │  Claude   │    │ DeepSeek │
                  │  Code     │───▶│ (auditor)│
                  │ (builder) │    │          │
                  │           │    │ runs own │
                  │ writes    │    │ tests,   │
                  │ code +    │    │ posts    │
                  │ tests     │    │ diff in  │
                  └──────────┘    │ comment  │
                                 └──────────┘
                        │              │
                        │              │  audit:pass
                        │              ▼
                        │         ┌──────────┐
                        │         │  Human   │
                        └────────▶│ (merge)  │
                                  │          │
                                  │ reviews  │
                                  │ PR,      │
                                  │ closes   │
                                  └──────────┘
```

### What each actor does to the Issue

| Actor | Action | gh command |
|---|---|---|
| **Builder** picks up work | add `stage:code` label, assign self | `gh issue edit N --add-label stage:code --assignee @me` |
| Builder finishes code | add `stage:test` label | `gh issue edit N --add-label stage:test` |
| Builder finishes verification | add `stage:verify` label, post test results as comment | `gh issue comment N --body "…"` |
| Builder hands off | add `stage:audit` label, **reassign to auditor** | `gh issue edit N --add-label stage:audit --assignee auditor` |
| **Auditor** picks up | confirm assignee, read comment history | — |
| Auditor runs independent tests | post audit diff as comment | `gh issue comment N --body "…"` |
| Auditor passes | add `audit:pass` + `stage:review` labels, **reassign to human** | `gh issue edit N --add-label audit:pass,stage:review --assignee human` |
| Auditor fails | add `audit:fail` label, **reassign back to builder** | `gh issue edit N --add-label audit:fail --assignee builder` |
| **Human** reviews PR | merge PR, close Issue, add `stage:done` label | `gh issue close N --comment "merged"` |

### Labels inventory

Labels are created by `setup-repo.sh` alongside the existing task/epic/gate labels:

| Label | Color | Purpose |
|---|---|---|
| `stage:code` | #fbca04 | being implemented by builder |
| `stage:test` | #c5def5 | builder running tests |
| `stage:verify` | #bfe5bf | verification doc written |
| `stage:audit` | #f9d0c4 | under auditor review |
| `audit:pass` | #0e8a16 | audit cleared |
| `audit:fail` | #b60205 | audit found blocking issues |
| `stage:review` | #1d76db | waiting on human reviewer |
| `stage:done` | #5319e7 | merged and closed |

### What the human sees

The board view at a glance:

| Stage: Audit | Stage: Review | Stage: Done |
|---|---|---|
| TICKET-044 ⏳ *audit running* | TICKET-043 ✅ *audit:pass* | TICKET-042 ✅ *merged* |
| *(assigned to DeepSeek)* | *(assigned to human)* | *(closed)* |

Click any Issue → the last comment is the audit diff (or "merged"). No file
browsing needed for status. The human only needs to check `stage:review`.

### How files and Issues stay in sync

This does **not** break the files-are-canonical principle:

1. `sync-issues.sh` still projects file front-matter → Issues (creation + Stage field).
2. Agent actions on Issues (labels, assignee, comments) are **transient workflow state** — they don't overwrite files. Files record *what*; Issues record *where in the pipeline*.
3. At the end of the cycle (merged), the post-merge workflow archives files and closes the Issue. File and Issue converge on "done."

Loss of the Issue board sets the team back to file-reading — no data is destroyed. Loss of files means the spec/ticket is gone. Files remain the single source of truth for content; Issues are the single source of truth for **current status and agent decisions**.

## Canonical source + front-matter sync

Files stay canonical; a `gh`-based sync projects them onto Issues + the board.
Every ticket/spec file carries front-matter the sync reads:

```yaml
---
id: TICKET-044
type: task            # brief | epic | spec | task | bug
spec: SPEC-005
repo: aws-marketplace-keys
owner: backend-engineer
stage: ticket         # mirrors the Project Stage field
status: ready
---
```

The `.ai` agents keep writing files (Phases 1–11 unchanged). The sync opens/updates
the matching Issue and sets the Project Stage. No double-bookkeeping.

## Gating config (the enforcement layer)

Per code repo:

- **Branch protection on `main`:** require PR, require these status checks green, require CODEOWNERS review, no force-push, linear history.
- **Required status checks (CI):** `lint`, `unit`, `contract` (cross-repo wire), `integration` (LocalStack/docker), `verification`, `spec-gate` (for spec PRs).
- **CODEOWNERS:** `docs/specs/**` → architect + security-architect; `internal/**` → backend-engineer; `verification/**` → qa-engineer. Maps `.ai` review roles to enforced approvals.
- **Environments:** `staging` (auto-deploy on green `main`), `production` (required reviewer + wait timer). Deploy workflow keyed off check conclusion — "deployed based on test."

## Repo topology

Per your choice (artifacts inside each code repo) + the unavoidable cross-cutting host:

- **Each code repo** (`aws-marketplace-keys`, `license-go`, `pg-cdc`): its own `docs/specs/`, `verification/`, Issues (Tasks), PRs, CI, Environments.
- **One cross-cutting host** (`your-org/.github` or a small `roadmap` repo): cross-repo **Epics** + **Briefs**, the **`.ai/` method + templates**, and the org **Project**. This is also where the otherwise-unbacked process workspace gets a home.
- **One org Project** spans all of the above.

## Agent → stage → gate map

| `.ai` agent | Stage it operates | Gate it must clear |
|---|---|---|
| product-manager | Brief, Spec draft | brief sign-off; spec merged |
| architect | Spec | architecture-review approved (CODEOWNERS) |
| security-architect | Spec | security-review approved (CODEOWNERS) |
| tech-lead | Tickets | tickets opened + linked |
| qa-engineer / test-engineer | Test plan, Test | test plan merged; CI checks green |
| backend-engineer / data-engineer | Code | PR passes required checks |
| **auditor** | **Audit** | **independent test pass matches; no blocking issues** |
| compliance-reviewer | Review | governance check on flagged PRs |
| documentation-writer | Docs | docs-changed check |
| release-engineer | Deploy | Environment approval + green main |
| sre | Observe | post-deploy smoke + incident triage |

No agent merges its own gate — the check or a *different* role's CODEOWNERS
approval is the gate.

## Traceability chain

```
BRIEF-XXX.md ─▶ Epic #(SPEC-XXX) ─▶ spec.md + reviews + test-plan
                    └─ Task #(TICKET-XXX)
                            ├─ Code ─▶ CI checks (Test) ─ required ✔
                            ├─ Verify doc ─ required ✔
                            ├─ AUDIT (DeepSeek)
                            │   ├─ runs own test pass
                            │   ├─ compares results ─▶ test gap diff
                            │   ├─ audit:pass ─▶ review
                            │   └─ audit:fail ─▶ loop back to Code
                            ├─ Review (human) ─▶ CODEOWNERS ✔
                            ├─ Deploy ─▶ Environment gated ✔
                            └─ Observe ─▶ Feedback ─▶ next Task
```

## Rollout

1. **Pilot on SPEC-005** (cross-repo, in-flight): create the Epic in the host repo, Tasks (TICKET-043…049) in `aws-marketplace-keys`/`pg-cdc`, stand up the Project + Stage field, wire branch protection + required checks + CODEOWNERS + Environments on the two repos.
2. **Backfill** SPEC-001…007 as closed Epics and TICKET-001…056 as Issues (scripted via `gh` from front-matter) for a complete, visible history.
3. **Turn on the sync** so `.ai` file outputs auto-project onto Issues + board.
4. **Make the gates required** (flip branch protection to enforced) once the pilot is green end-to-end.

> Interim, do step 0 regardless: push the process workspace to its host repo so the
> delivery history is backed up before any restructuring.
