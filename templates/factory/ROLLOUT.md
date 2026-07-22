# Factory Rollout Checklist (pilot = SPEC-005)

One ordered sequence to take the AI-First Software Factory live. Each step is
idempotent-ish; nothing is destructive. Model: `docs/architecture/ai-software-factory.md`.
Bundle details: `README.md`. All commands are run by **you** (outward-facing).

> For the **general** activation path (any repos, not the SPEC-005 pilot) — including
> the GitHub App builder and the `evaluate → active` flip — use [`ACTIVATE.md`](ACTIVATE.md).
> This file is the pilot-specific instance of that sequence.

```bash
export ORG=your-org HOST_REPO=roadmap
cd .ai/templates/factory     # bundle root (scripts are relative to here)
```

## Prerequisites
- [ ] `gh auth status` OK, with project scope: `gh auth refresh -s project,read:org,repo`
- [ ] `jq` installed (scripts use it)
- [ ] GitHub teams referenced by CODEOWNERS exist and are non-empty — verify with
      `scripts/setup-teams.sh` (it fails if any team is missing/empty, which would make
      that review rule fail open). `--create` makes missing teams.
- [ ] Builder GitHub App set up (authors PRs, no seat cost) — see `RUNBOOK-github-app.md`.
      Required before Claude Code can open PRs autonomously.

## Step 0 — Back up the workspace + create the host repo
> Closes the single-machine risk; gives cross-repo Epics/Briefs + the `.ai` method a home.
- [ ] `scripts/setup-host-repo.sh` (dry run — review the plan)
- [ ] `scripts/setup-host-repo.sh --apply` (creates `$ORG/$HOST_REPO`, pushes the workspace)
- [ ] Confirm `repos/` stayed gitignored (it is) — code is not vendored into the host repo

## Step 1 — Land the per-repo `.github` gate files (PR-039/040/041)
> Must precede the ruleset so `factory-verification` exists as a referenceable check.
- [ ] `aws-marketplace-keys` — branch `factory/delivery-gates`, PR-039 (CODEOWNERS + issue templates + verify gate)
- [ ] `license-go` — PR-040 (CODEOWNERS + issue templates + verify gate)
- [ ] `product-pg-cdc` — PR-041 (CODEOWNERS + issue templates; Verify = existing `Feature spec`)
- [ ] Merge all three (commands + bodies: `prs/open/PR-039..041`)

## Step 2 — Org Project + Stage field
- [ ] `scripts/setup-project.sh` → creates "Your Factory Board" Project + `Stage` + `Spec` fields

## Step 3 — Per-repo labels, ruleset, environments
> Auto-selects the reconciled ruleset per repo (amk/license-go: `build`+`factory-verification`; pg-cdc: `Lint`/`Test`/`Integration Test`/`Docs drift guard`/`Feature spec`). enforcement starts `evaluate` (non-blocking).
- [ ] `scripts/setup-repo.sh "$ORG/aws-marketplace-keys"`
- [ ] `scripts/setup-repo.sh "$ORG/product-pg-cdc"`
- [ ] `scripts/setup-repo.sh "$ORG/license-go"` (optional for SPEC-005; do for completeness)
- [ ] Set required reviewers on each `production` environment (one-time, repo settings)

## Step 4 — Project the SPEC-005 Epic + Tasks onto Issues + board
- [ ] `SPEC_FILTER=SPEC-005 scripts/sync-issues.sh ../../../specs/draft/SPEC-005-container-marketplace-golive`
- [ ] `SPEC_FILTER=SPEC-005 scripts/sync-issues.sh ../../../tickets`
- [ ] Link Tasks (TICKET-043…049, 023…026) as sub-issues of the SPEC-005 Epic
- [ ] Verify the board: 1 Epic + 11 Tasks, Stage column populated, repos correct

## Step 5 — Prove one ticket end-to-end (de-risk before enforcing)
- [ ] Pick TICKET-044 (do-first); open a PR `Closes #<task>`
- [ ] Confirm the line: PR → CI green → CODEOWNERS review → merge → board moves to Done

## Step 6 — Flip gates to enforced
- [ ] Edit each `ruleset.*.json`: `"enforcement": "active"`; re-apply via `setup-repo.sh`
- [ ] Confirm teams exist so `require_code_owner_review` is satisfiable
- [ ] (amk) optionally add `{"context":"tf-validate"}` / `{"context":"integration"}` once those run as separate checks

## Step 7 — Backfill history (after the pilot is green)
- [ ] Add front-matter to SPEC-001…004/006/007 + TICKET-001…042/050…056
- [ ] Run `sync-issues.sh` (no filter) to create closed Epics/Tasks for full visible history
- [ ] Update `docs/delivery-ledger.md` + `docs/specs.md` with the GitHub `#` numbers

## Done when
- The SPEC-005 board reflects live status across repos, gates block on red, and deploys
  follow green — the factory is enforcing, not advisory.
