# Factory Scaffolding Bundle

Drop-in GitHub config that turns the [`AI-First Software Factory`](../../../docs/architecture/ai-software-factory.md)
model into enforced gates. Apply per code repo; create the Project + host Epics
once at org level.

## Variables

| Var | Pilot value | Notes |
|---|---|---|
| `ORG` | `your-org` | GitHub org |
| `HOST_REPO` | `roadmap` | hosts cross-repo Epics/Briefs + `.ai` method + Project (swap for `.github`) |
| `CODE_REPOS` | `aws-marketplace-keys`, `license-go`, `product-pg-cdc` | each gets the `.github/` + CODEOWNERS + ruleset |
| `PROJECT` | "Your Factory Board" | the org Project (v2) board |

## What goes where

```
ENGINE (ai-software-factory checkout — NOT vendored into delivery repos)
  scripts/provision.sh              # the single provisioning ORCHESTRATOR (engine-only; ADR-0012)
                                    # validate → bootstrap → repo-create → setup-project (JOIN) → setup-repo → seed sync-issues.yml
  scripts/bootstrap-project.sh      # filesystem method-bundle installer (provision.sh delegates to it)
  scripts/upgrade-project.sh        # --upgrade bundle refresh (local .ai/ only; never pushes main)
each CODE_REPO/
  .github/ISSUE_TEMPLATE/epic.yml   task.yml
  .github/PULL_REQUEST_TEMPLATE.md  # forces full background: spec + epic + all related tickets/issues
  .github/workflows/ci.yml          # gates: lint/test/build/verification (required) + tf-validate/integration (where present)
  .github/workflows/deploy.yml      # env-gated deploy-on-green
  .github/workflows/sync-issues.yml # SEEDED by provision.sh (copy-if-absent, open-only PR) — event-driven board sync
  CODEOWNERS                        # .ai review roles → enforced approvals
HOST_REPO/
  .ai/ (the method + templates)     # backed-up engine (incl. scripts/lib/sync-issues.sh — the shared projector,
                                    #   and scripts/lib/stage-files.sh — the shared ADR-0007 git-write staging helper)
  .github/workflows/sync-issues.yml # event-driven: on push to main touching specs/** or tickets/**, projects front-matter → Issues + Project board (needs PROJECTS_TOKEN; fail-soft if unset)
  Epics live here when cross-repo
```

> `provision.sh` and `bootstrap-project.sh`/`upgrade-project.sh` are **engine-only** (top-level
> `scripts/`); they are NEVER vendored into a delivery repo (a vendored copy could not reach the
> filesystem installer or the factory source). Only `templates/factory/scripts/lib/stage-files.sh`
> is vendored, because the vendored `setup-repo.sh` consumes it too (ADR-0012 decision a).

## Rollout order (pilot = SPEC-005)

```bash
export ORG=your-org HOST_REPO=roadmap
# 0. back up the workspace + method + create the host repo (see HOST-REPO-LAYOUT.md)
scripts/setup-host-repo.sh            # dry run; add --apply to execute

# 1. provision each code repo in ONE command (engine-only orchestrator — ADR-0012):
#    validate naming -> bootstrap -> repo-create -> setup-project (JOIN the org Project,
#    never recreate) -> setup-repo (labels/rulesets/CODEOWNERS/environments) -> seed sync-issues.yml.
#    Idempotent (re-run-to-heal); --dry-run previews with zero mutations; --upgrade retrofits
#    an existing repo non-destructively. This replaces the old separate setup-project.sh +
#    setup-repo.sh + hand-copy-.github/ + manual-sync-issues.yml-seed ritual.
scripts/provision.sh --dry-run "$ORG/product-pg-cdc"          # preview
for r in aws-marketplace-keys product-pg-cdc; do scripts/provision.sh "$ORG/$r"; done

# 2. seed the pilot Epic + Tasks from the SPEC-005 files (routine projection is then automatic
#    via the seeded sync-issues.yml on push to main; this is the initial backfill)
scripts/sync-issues.sh ../../../specs/draft/SPEC-005-container-marketplace-golive
scripts/sync-issues.sh ../../../tickets   # filters by spec: SPEC-005

# 3. prove the line end-to-end on one ticket, then flip the ruleset to enforced.

# 4. (ongoing) report flow — WIP by Stage, throughput, cycle time
scripts/metrics.sh                    # markdown to stdout; see METRICS.md
```

Gates are created **non-enforcing** first so the pilot can run; flip
`enforcement: active` in the ruleset once green end-to-end.

Once live, `scripts/metrics.sh` reports how the line is flowing from the org Project
(WIP by Stage, throughput, cycle time) — see [`METRICS.md`](METRICS.md). Every PR
carries full background via [`.github/PULL_REQUEST_TEMPLATE.md`](.github/PULL_REQUEST_TEMPLATE.md).

## Board & Issue sync (`sync-issues.yml`)

`sync-issues.yml` keeps GitHub Issues + the org Project board in sync with the spec/ticket
files automatically. It fires on **push to `main`** whenever `specs/**` or `tickets/**`
changes and projects each file's front-matter (`id, type, spec, repo, owner, stage, status`)
onto an Issue via the shared `scripts/lib/sync-issues.sh` projector — the same code path the
manual `scripts/sync-issues.sh` wrapper now `exec`s.

- **Prerequisite:** `secrets.PROJECTS_TOKEN` — a PAT or GitHub App token with org
  **Projects: write** + **Issues: write** (the same token pattern `board-sync.yml` uses). If
  it is unset the Action **fail-softs**: it emits a `::notice::` and exits 0, so the board is
  simply not updated — nothing breaks and no token leaks.
- **Idempotent:** an Issue is matched by its `"<ID>:"` title prefix and updated in place
  (never duplicated), and nothing is written back into the markdown — files stay the source
  of truth.
- **Stage ownership:** `sync-issues.yml` sets the Project `Stage` **only when it creates** an
  Issue. `board-sync.yml` owns every subsequent `Stage` transition (on `stage:*` label
  changes), so the two complement each other and never flap.
- Files missing the required `id` front-matter are skipped with a `::notice::`; malformed
  YAML never crashes the run.

The manual `scripts/sync-issues.sh` still works for backfills and one-offs — it and the
Action share the single `scripts/lib/sync-issues.sh` implementation; the workflow just makes
routine projection automatic.

## Rulesets are per-repo (reconciled to real CI)

The existing repos already have their own CI with distinct check names, so each gets
a ruleset whose required checks match what it actually produces (`setup-repo.sh`
picks automatically):

| Repo | Required status checks | Verify gate |
|---|---|---|
| `aws-marketplace-keys` | `build`, `factory-verification` | `factory-verification.yml` (staged) |
| `license-go` | `build`, `factory-verification` | `factory-verification.yml` (staged) |
| `product-pg-cdc` | `Lint`, `Test`, `Integration Test`, `Docs drift guard`, `Feature spec` | existing `Feature spec` |
| *new repo* | `lint`, `test`, `build`, `verification` (the factory `ci.yml`) | factory `ci.yml` verification job |

Do **not** copy the factory `ci.yml`/`deploy.yml` over a repo that already has CI —
they're the greenfield template only.

## Naming conventions (gated)

See `NAMING.md` for the full convention + enforcement matrix. Mechanisms:
`ruleset.naming.json` (branch names), `pr-lint.yml` (conventional PR title +
ticket/spec reference, `skip-ticket` label escapes), `factory-naming.yml` +
`scripts/validate-artifacts.sh` (spec/ticket IDs, filenames, front-matter id↔file),
`scripts/audit-org-naming.sh` (org repo-name audit). `setup-repo.sh` applies the
naming ruleset; stage `pr-lint.yml` (all repos) and `factory-naming.yml` (delivery
instances) like the other workflows, then add `pr-lint`/`factory-naming` to required
checks once they report.
