# Activate the factory — go-live checklist

One ordered path from "the method is installed" to "gates are enforcing and Claude
Code opens PRs autonomously." Model: [`docs/architecture/ai-software-factory.md`](../../docs/architecture/ai-software-factory.md)
and [ADR-0001](../../docs/decisions/ADR-0001-gate-identity-model.md) (the 2-human /
8-team / GitHub-App identity model). Steps are idempotent-ish; nothing is destructive.
Run by **you** (org admin) unless noted.

```bash
export ORG=your-org HOST_REPO=roadmap
cd .ai/templates/factory      # bundle root — scripts are relative to here
```

> This checklist reflects the **current** scripts and gate model. The autonomous
> "floor motor" (`floor-motor.yml`, `deepseek audit`) **is shipped** — it is
> **off by default**, was validated end-to-end in v0.3.1, and is **optional**. Enable
> it deliberately per [`RUNBOOK-floor-motor.md`](RUNBOOK-floor-motor.md) **after** this
> checklist — see the note at the end.

## Phase 0 — Prerequisites
- [ ] `gh auth status` OK, with scopes: `gh auth refresh -s project,read:org,repo`
- [ ] `jq` and `openssl` installed
- [ ] Teams referenced by CODEOWNERS exist and are non-empty:
      `scripts/setup-teams.sh` (add `--create` to make any that are missing).
      **This must pass** — a missing/empty team makes its review rule fail open.

## Phase 1 — Builder identity (the GitHub App)
> The App authors PRs with no seat cost; either human then approves independently.
- [ ] Follow [`RUNBOOK-github-app.md`](RUNBOOK-github-app.md): create + install the App
      (incl. **Workflows: write**), wire the git credential helper + bot commit identity.
- [ ] Smoke test: the App opens a PR whose author is `…[bot]`, and a **human** approves it.

## Phase 2 — Backup + tracking surface
- [ ] `scripts/setup-host-repo.sh` (dry run — review the plan)
- [ ] `scripts/setup-host-repo.sh --apply` (create `$ORG/$HOST_REPO`, push the workspace)
- [ ] Open the Project → **Board** layout → group by **Stage** (after Phase 3 creates it)

## Phase 3 — Provision each repo (one command)
> `provision.sh` (top-level `scripts/`, engine-only, never vendored — ADR-0012) is the single
> entry point. It is a **thin orchestrator**: validate naming → bootstrap the bundle → ensure
> the GitHub repo → **JOIN** the org Project (never recreate) → apply `setup-repo.sh` (labels,
> rulesets + naming ruleset in `evaluate`, CODEOWNERS, environments) → **seed `sync-issues.yml`**
> on an open-only, copy-if-absent PR. It is idempotent (re-run-to-heal) and rulesets ship
> `enforcement: evaluate` so onboarding never blocks an in-flight PR.
- [ ] Preview first: `scripts/provision.sh --dry-run "$ORG/<repo>"` (zero mutations, prints the plan)
- [ ] For each code repo: `scripts/provision.sh "$ORG/<repo>"`
      (add `--upgrade` to bring an EXISTING repo up to the current baseline non-destructively)
- [ ] Review + merge the governance PR and the `sync-issues.yml` seed PR it opens (open-only; a human merges)
- [ ] Set **required reviewers** on each `production` environment (manual, one-time)

> **What it consolidates / fallback.** `provision.sh` replaces the old separate `setup-project.sh`
> + `setup-repo.sh` + hand-copy-`.github/`-into-a-PR + manual-`sync-issues.yml`-seed ritual. Those
> scripts still run standalone if you need to do a single step by hand; `provision.sh` just runs
> them in the right order and adds the workflow seed. The `sync-issues.yml` seed uses a
> `workflow`-scope credential (the `github-dataalgebra:` SSH alias / a GitHub App token — the
> global HTTPS token lacks `workflow` scope; see ADR-0012); if it is unavailable the seed warns
> loudly ("provisioned EXCEPT board-sync") without failing the run — seed it manually or re-run.

## Phase 4 — Prove it green
- [ ] Open a PR in each repo; confirm the required checks run and pass:
      `lint`, `test`, `build`, `verification`, `audit` (per the repo's ruleset variant)
- [ ] Confirm the PR requests review from the expected CODEOWNERS team
- [ ] `scripts/audit-org-naming.sh` — repo names conform; `scripts/validate-artifacts.sh`
      (in a delivery repo) — spec/ticket names + spec content pass

## Phase 5 — Flip to enforcing
- [ ] Re-run with enforcement on: `ENFORCEMENT=active scripts/setup-repo.sh "$ORG/<repo>"`
      (or flip in **Settings ▸ Rules ▸ Rulesets**)
- [ ] Confirm on GitHub: `main` requires the checks + 1 CODEOWNERS approval, no force-push
- [ ] **If the independent audit gate is landed** (`enable-audit.sh`): requiring the
      `independent-audit` context and flipping it with the rest of the ruleset (coupling,
      pre-flip validation, honest framing) is the operator-owned step documented in
      [`PROVISIONING.md` "Per repo"](../../PROVISIONING.md) — the single source; not restated here.

## Phase 6 — Operate
- [ ] Routine board projection is automatic via `sync-issues.yml` (seeded by `provision.sh` in
      Phase 3) on push to `main` touching `specs/**`/`tickets/**` — needs `PROJECTS_TOKEN`,
      fail-soft if unset. `scripts/sync-issues.sh <tickets-path>` still mirrors artifact
      front-matter → Issues + board manually for backfills/one-offs.
- [ ] Run a real feature: `/feature-delivery <idea>` → agents produce spec → … → audit → PR,
      then **stop** for human approval (agents open PRs; humans merge)
- [ ] After merge: `/post-merge` archives the spec, records evidence, updates the ledger
- [ ] `scripts/metrics.sh` — WIP / throughput / cycle time from the board

---

## Relationship to #4 (autonomous floor motor)

Issue #4's **lights-out** activation **is shipped**: GitHub Actions running
`claude-code-action` (`floor-motor.yml`, `deepseek audit`) that auto-drives a feature
through `state:*` label transitions, gated by `FLOOR_MOTOR_ENABLED`. It was validated
end-to-end in **v0.3.1** and is **off by default** — the default model remains
**human-driven Claude Code + a GitHub App builder** (this checklist). The floor motor is
an **optional** autonomy layer on top of this foundation; enable it deliberately per
[`RUNBOOK-floor-motor.md`](RUNBOOK-floor-motor.md), only after the go-live checklist above.
