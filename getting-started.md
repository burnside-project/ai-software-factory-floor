# Getting Started

A task-oriented, copy-paste walkthrough for onboarding a repo into the
**ai-software-factory**. It covers the two situations you actually hit on the
command line:

- **[Use case 1 — New repo / empty shell](#use-case-1--new-repo--empty-shell-greenfield)** *(greenfield, "Path A")* — a brand-new repo the factory creates and owns end-to-end.
- **[Use case 2 — Existing repo / project](#use-case-2--existing-repo--project-path-b)** *(existing, "Path B")* — a repo that already has code and CI; the factory adds a reconciled gate layer **without clobbering** its pipeline.

> **This guide is the friendly on-ramp. [`PROVISIONING.md`](../PROVISIONING.md) is
> the canonical runbook** — the single source of truth for exact step ordering,
> per-org vs. per-repo split, and the "Am I done?" checklist. When the two ever
> disagree, `PROVISIONING.md` wins. This guide links out to it rather than
> restating the deep procedures.

---

## Before you start — the mental model

Three things make everything below make sense.

### 1. Two repos are always in play

You run commands from a **checkout of `ai-software-factory`** (this repo), and they
write into a **separate target repo** — the delivery instance. Keep the target as a
**sibling** of the factory checkout, never nested inside it:

```
<workspace>/
├── ai-software-factory/        ← you run scripts from HERE (the factory root)
└── myrepo-delivery/            ← the target the factory writes INTO (a sibling)
```

`bootstrap-project.sh` takes the target path as an argument, so "cd to root" means
`cd` to the **parent** directory before you clone.

### 2. Naming convention

The target directory basename should be `<name>-delivery` (a delivery instance) or
`product-<name>` (a product repo). A non-conforming name only produces a
`WARNING` — set `FORCE=1` to silence it — but staying on-convention keeps the
factory's naming ruleset and metrics happy. Full rules:
[`templates/factory/NAMING.md`](../templates/factory/NAMING.md).

### 3. The seeded → activation boundary (important)

Onboarding has **two distinct layers**, installed by two different steps:

| Layer | Installed by | What lands | Enforces anything? |
|---|---|---|---|
| **Method + conventions** (seeded) | `bootstrap-project.sh` | `.ai/` method, `.claude/` agents + commands, lifecycle dirs, ledger, knowledge YAMLs, stub `Makefile`, and the **inert** `.github/ISSUE_TEMPLATE/`, `.github/PULL_REQUEST_TEMPLATE.md`, root `CODEOWNERS` | **No** |
| **Enforcement** (activation) | `templates/factory/scripts/setup-repo.sh` + `ACTIVATE.md` | CI/deploy **workflows**, branch **rulesets**, environments | Yes, once flipped to `active` |

Bootstrap deliberately **does not** copy anything under `.github/workflows/` — the
secret-bearing (`PROJECTS_TOKEN`) workflows and the off-by-default autonomy workflow
stay out of a bare repo until the deliberate, secret-gated activation step. A repo
can *look* onboarded while its gates are still non-enforcing — that's a net
regression, so both use cases below end at **rulesets `active`**.

> **Prefer a guided walkthrough?** These slash commands drive the same steps
> interactively from inside Claude Code, pausing for confirmation before every
> GitHub mutation:
> - `/provisioning:check-readiness` — the pre-flight (step 0)
> - `/provisioning:onboard-project` — full end-to-end, either path
> - `/provisioning:onboard-repo` — existing repo (Path B)
> - `/provisioning:activate-gates` — the activation leg for an already-bootstrapped repo

---

## Step 0 — Readiness (both use cases)

Run the read-only pre-flight from the factory root. It checks `gh` + `jq` are on
PATH, `gh` is authenticated with the `project` scope, and the `.claude/` layer is
present:

```bash
cd <workspace>/ai-software-factory      # your checkout of this repo
./scripts/check-readiness.sh
```

Fix every `MISSING:` line before continuing. Also install `openssl` (used to mint the
GitHub App JWT). Use **least-privilege** credentials — do **not** mint a broad
all-scopes / `admin:org` / full-`repo` classic PAT:

```bash
gh auth refresh -s project,read:org,repo    # operator gh CLI scopes
```

Set the shared env vars once per shell (secrets are **never** committed — paste at
runtime, use placeholders in files):

```bash
export ORG=<your-org>                 # an org you administer
export HOST_REPO=<host-repo>          # tracking/backup repo, e.g. roadmap
export PROJECTS_TOKEN=<paste-at-runtime-not-in-a-file>   # project + repo:read, no write
```

---

## One-time per org (both use cases)

Run these **once per GitHub org**, as an org admin. Every repo in that org reuses
them — skip this section if the org is already set up. Full detail lives in
[`PROVISIONING.md` → One-time per org](../PROVISIONING.md#one-time-per-org).

1. **Builder App** — create + install the least-privilege GitHub App (Repository
   permissions only, **Workflows: write**, **no `Administration`**), then wire the git
   credential helper + bot commit identity.
   → [`RUNBOOK-github-app.md`](../templates/factory/RUNBOOK-github-app.md)
2. **Teams / CODEOWNERS** — `templates/factory/scripts/setup-teams.sh` (add `--create`
   to create missing teams). **Must pass before any ruleset flips to `active`** — an
   empty CODEOWNERS team makes GitHub treat that path as having *no* required reviewer,
   a silent fail-open of the review gate.
3. **Host / tracking repo** — `templates/factory/scripts/setup-host-repo.sh` (review the
   dry-run plan, then `--apply`).
4. **Org Project** — `templates/factory/scripts/setup-project.sh` (creates the Project
   with `Stage`/`Spec` fields; group the Board by **Stage**).

---

## Use case 1 — New repo / empty shell (greenfield)

Goal: a brand-new repo the factory owns end-to-end, gated and delivering. The factory
seeds *everything*, including the shipped `ci.yml` / `deploy.yml`.

### 1.1 — Create and clone the repo (as a sibling)

```bash
cd <workspace>                         # the PARENT dir (sibling of ai-software-factory)

# Create the empty repo on GitHub, then clone it locally with a -delivery name:
gh repo create "$ORG/myrepo-delivery" --private --clone
# (or: create in the UI, then `git clone <url> myrepo-delivery`)
```

### 1.2 — Bootstrap the method into it

Run from the factory root, targeting the sibling checkout. Greenfield mode
seeds/overwrites (no `--target-existing` flag):

```bash
cd ai-software-factory
./scripts/bootstrap-project.sh ../myrepo-delivery
```

This lands the `.ai/` method, `.claude/` agents + commands, all lifecycle dirs, the
ledger, knowledge YAMLs, a stub `Makefile`, and the inert conventions (issue/PR
templates + root `CODEOWNERS`). It **fails hard** if the factory's `.claude/` layer is
missing (pass `--github-only` only if you deliberately want an
enforcement-only install with no Claude Code layer).

### 1.3 — Wire the Makefile

Fill in the stub's real commands **before** relying on `make verify`. CI runs `make
lint`, `make test`, `make build` as required checks; the stub seeds those (plus
`test-local` / `test-docker` for the delivery flow) as graceful no-ops that exit 0
until you wire them, so the first test PR is green while the repo is still a shell:

```bash
cd ../myrepo-delivery
$EDITOR Makefile        # fill in real lint / test commands
```

### 1.4 — Commit the seed and copy the shipped CI

For greenfield you also bring in the factory's `ci.yml` / `deploy.yml` (bootstrap does
not copy workflows — see the boundary above). Bootstrap doesn't create
`.github/workflows/` either, so **create it first** (`cp` won't make the parent dir):

```bash
mkdir -p .github/workflows
cp ../ai-software-factory/templates/factory/.github/workflows/ci.yml     .github/workflows/
cp ../ai-software-factory/templates/factory/.github/workflows/deploy.yml .github/workflows/
git add -A && git commit -m "chore: bootstrap ai-software-factory method + CI"
git push -u origin main
```

The shipped `ci.yml` is **stack-aware** — `lint`/`test`/`build` detect the repo's manifest
(`go.mod` → Go, `package.json` → Node, `pyproject.toml`/`requirements.txt`/`setup.py` →
Python) and install the matching toolchain before delegating to `make`, so you copy it
as-is with no per-language editing. Add another guarded `setup-*` step to support a new
stack.

### 1.5 — Apply gates in report-only mode

Rulesets ship as `enforcement: evaluate` so onboarding never blocks an in-flight PR:

```bash
cd ../ai-software-factory
templates/factory/scripts/setup-repo.sh "$ORG/myrepo-delivery"
```

This applies labels, the branch + naming rulesets (in `evaluate`), and the
staging/production environments.

### 1.6 — Open a test PR and verify

Open a throwaway PR and confirm the required checks run (`lint`, `test`, `build`,
`verification`, `audit` per the ruleset variant) and that the PR requests review from
the expected CODEOWNERS team — while rulesets are still in `evaluate`.

### 1.7 — Set the production reviewer (manual, one-time)

**Settings ▸ Environments ▸ production** → add a required reviewer. Without this the
deploy gate is non-enforcing.

### 1.8 — Flip rulesets to enforcing

Only after the test PR is green **and** `setup-teams.sh` has resolved the CODEOWNERS
teams:

```bash
ENFORCEMENT=active templates/factory/scripts/setup-repo.sh "$ORG/myrepo-delivery"
```

This re-run is idempotent — it **updates the existing ruleset in place** (the `evaluate`
run from 1.5 created it; this only flips `enforcement`). Confirm on GitHub that `main` now
requires the checks + 1 CODEOWNERS approval and blocks force-push.
→ **[Jump to First feature](#first-feature-both-use-cases)**

---

## Use case 2 — Existing repo / project (Path B)

Goal: add the factory's method and a **reconciled** gate layer to a repo that already
has code and CI — **without** clobbering its files or its pipeline. The two
differences from greenfield: the `--target-existing` bootstrap flag, and a CI-check
reconciliation step so the ruleset gates the repo's *real* checks.

### 2.1 — Clone the existing repo (as a sibling)

```bash
cd <workspace>                         # the PARENT dir (sibling of ai-software-factory)
git clone <url> theproject-delivery    # name on-convention if you can
```

### 2.2 — Bootstrap non-clobbering (`--target-existing`)

Run from the factory root. `--target-existing` (ADR-0005) always refreshes the
factory-owned `.ai/` + filtered `.claude/`, but seeds every **repo-owned** file
(`CODEOWNERS`, `Makefile`, knowledge YAMLs, ledger, lifecycle artifacts, issue/PR
templates) **copy-if-absent** — an existing file is preserved byte-for-byte. It is
idempotent:

```bash
cd ai-software-factory
./scripts/bootstrap-project.sh --target-existing ../theproject-delivery
```

> The repo's own `CODEOWNERS` is a security control and is **never** overwritten. If
> the repo already has a `Makefile`, it is kept as-is (copy-if-absent) — check it exposes
> `lint` / `test` / `build` (the checks CI requires), or reconcile the ruleset to its
> real check names in step 2.3.

### 2.3 — Reconcile the ruleset to the repo's real CI checks

An existing repo keeps its CI. Emit a ruleset variant whose **required status checks
match the repo's actual check names**, so flipping to `active` gates real checks
instead of requiring one that never reports. This helper is **emit-and-review only** —
it never POSTs anything:

```bash
# Live discovery (read-only gh api GET) → writes a reviewable JSON:
scripts/reconcile-ci-checks.sh "$ORG/theproject-delivery" --out /tmp/theproject-ruleset.json
# …or pass an explicit list (makes NO gh call):
# scripts/reconcile-ci-checks.sh "$ORG/theproject-delivery" --checks lint,test,build --out /tmp/theproject-ruleset.json
```

**Review the emitted JSON** — confirm the `required_status_checks` are the checks you
actually want to gate on.

### 2.4 — Apply gates in report-only mode, using the reconciled ruleset

```bash
RULESET=/tmp/theproject-ruleset.json \
  templates/factory/scripts/setup-repo.sh "$ORG/theproject-delivery"
```

Rulesets apply as `evaluate` (report-only) so an in-flight PR is never blocked.
`setup-repo.sh` selects the ruleset via `RULESET=` override > manifest
(`ruleset-map.tsv`) > greenfield default (ADR-0006).

### 2.5 — Land the `.github/` + CODEOWNERS state via a PR

Bootstrap seeded these locally in the target checkout; for an existing repo, open a PR
to bring them in. `setup-repo.sh` prints the exact paths. Either open it manually, or
opt into the **open-only** auto-PR (default OFF), which clones the repo, copies the
governance subset copy-if-absent (never workflows), and **opens** a PR — it never
merges, approves, or force-pushes (ADR-0007):

```bash
templates/factory/scripts/setup-repo.sh "$ORG/theproject-delivery" --stage-files
```

### 2.6 — Test PR, production reviewer, flip to enforcing

Identical to greenfield steps [1.6](#16--open-a-test-pr-and-verify)–[1.8](#18--flip-rulesets-to-enforcing):

```bash
# after a green test PR + resolved CODEOWNERS teams + production reviewer set:
RULESET=/tmp/theproject-ruleset.json ENFORCEMENT=active \
  templates/factory/scripts/setup-repo.sh "$ORG/theproject-delivery"
```

> Pass the same `RULESET=` file on the `active` flip that you used in `evaluate`, so
> the enforcing ruleset gates the reconciled check names.

---

## First feature (both use cases)

With gates active, deliver a feature from inside Claude Code **in the target repo**:

```bash
cd ../theproject-delivery      # or ../myrepo-delivery
# in Claude Code:
```
```
/feature-delivery <your idea, an intake doc path, or SPEC-XXX to resume>
```

The flow walks all delivery phases (idea → spec → architecture & security review →
tickets → test plan → **spec gate** → implementation → verification → **audit** →
docs → PR → **compliance gate**) and **stops for human approval** — agents open PRs,
humans merge. After merge:

```
/post-merge SPEC-XXX
```

See [`RUNBOOK-claude-code.md`](../RUNBOOK-claude-code.md) for operating the flow, and
[`templates/factory/RUNBOOK-deepseek audit.md`](../templates/factory/RUNBOOK-deepseek audit.md)
for the optional, off-by-default autonomy.

---

## "Am I done?" checklist

You are **not** done until every box is checked — a repo can look onboarded while its
gates are still non-enforcing:

- [ ] `./scripts/check-readiness.sh` exits 0.
- [ ] Builder App installed; a `…[bot]` PR was opened and a **human** approved it.
- [ ] `setup-teams.sh` passed — every CODEOWNERS team exists and is non-empty.
- [ ] `bootstrap-project.sh` seeded `.github/` templates + root `CODEOWNERS` in the repo.
- [ ] *(Path B)* the reconciled ruleset was reviewed and its checks match real CI.
- [ ] A test PR ran the required checks green and requested the expected CODEOWNERS review.
- [ ] **Rulesets are `active`** (not `evaluate`): `main` requires the checks + 1
      CODEOWNERS approval and blocks force-push.
- [ ] **The `production` environment has a required reviewer set.**
- [ ] `/feature-delivery` runs and stops at the human gate.

Canonical version of this list: [`PROVISIONING.md` → "Am I done?"](../PROVISIONING.md#am-i-done-checklist).

---

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `WARNING: '<name>' does not match the naming convention` | Target dir isn't `<name>-delivery` / `product-<name>`. Rename it, or `FORCE=1 ./scripts/bootstrap-project.sh …` to silence. |
| `ERROR: native Claude Code layer missing or incomplete` | You ran bootstrap from the wrong directory, or want an enforcement-only install. Run from the factory root; or pass `--github-only` deliberately. |
| `ERROR: .ai/templates/factory did not land` | The factory checkout is incomplete (a `templates/factory/` subtree didn't copy). Re-check out the factory repo and re-run. |
| `WARNING: '<dir>' not found in factory root` | You're not in the factory root. `cd` into the `ai-software-factory` checkout first. |
| `MISSING: gh missing 'project' scope` | `gh auth refresh -s project,read:org,repo`. |
| `MISSING: .claude/agents not found` when your checkout **is** complete | Fixed as of [PR #43](https://github.com/dataalgebra-engineering/ai-software-factory/pull/43): `check-readiness.sh` now resolves the factory root from the script's own location, so it runs correctly from any directory (previously it false-failed when launched from `scripts/`). Update your factory checkout (`git pull`) if you still hit this. |
| Ruleset is `active` but a required check never reports (existing repo) | You skipped reconciliation. Re-run `reconcile-ci-checks.sh`, review, and re-apply with `RULESET=`. |
| A required-review path has no reviewer (fail-open) | `setup-teams.sh` hasn't resolved that CODEOWNERS team — run it (with `--create`) before flipping to `active`. |

---

## Where to go next

- [`PROVISIONING.md`](../PROVISIONING.md) — the canonical zero-to-operating runbook (this guide's source of truth).
- [`OVERVIEW.md`](../OVERVIEW.md) — one-page map of the whole system.
- [`templates/factory/ACTIVATE.md`](../templates/factory/ACTIVATE.md) — the full go-live checklist, every gate spelled out.
- [`RUNBOOK-claude-code.md`](../RUNBOOK-claude-code.md) — operating the delivery flow.
- [`templates/factory/NAMING.md`](../templates/factory/NAMING.md) — the naming convention.
</content>
</invoke>
