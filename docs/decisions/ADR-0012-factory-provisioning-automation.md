# ADR-0012: Factory provisioning automation — one orchestrator, and the ADR-0007 surface extended to one workflow

Status: Accepted
Date: 2026-07-13
Deciders: Architect (Phase 2) + Security Architect (Phase 3), via SPEC-013b
Related: SPEC-013b (`provision.sh` orchestrator), SPEC-013 / 013a (`sync-issues.yml` +
`lib/sync-issues.sh`, PR #53), SPEC-008 (`--stage-files` + the git-write floor),
ADR-0007 (factory git-write guardrails — the reference this narrowly extends),
ADR-0005 (install file-ownership / copy-if-absent boundary), ADR-0003 (best-effort
external calls), ADR-0002 (never-auto-merge floor).

## Context

Standing up a code repo with the full factory stack was a multi-step manual ritual: run
`setup-project.sh` (org Project + `Stage`/`Spec` fields), then `setup-repo.sh` per repo
(labels, rulesets, CODEOWNERS, environments, naming ruleset), then hand-copy `.github/` +
`CODEOWNERS` into a PR, following prose in `ACTIVATE.md`. Miss a step and the repo is
half-provisioned. Separately, 013a shipped `sync-issues.yml` as a *template* but nothing
placed it into a target repo's `.github/workflows/` — a freshly onboarded repo had the
sync library available but no workflow invoking it. And there was no `--upgrade` path to
bring an existing repo up to the current baseline.

SPEC-013b consolidates this behind one command, `provision.sh <owner/repo>`. Doing so
forces four decisions worth recording so future maintainers do not relitigate them — one
of which (b) is a deliberate, security-reviewed reversal of a prior decision and MUST NOT
be mistaken for a silent reuse.

## Decision

### (a) Two-layer home boundary — engine-only `scripts/`, never vendored

`provision.sh` lives at **top-level `scripts/provision.sh`**, the same engine-only layer as
`bootstrap-project.sh` / `upgrade-project.sh`, and is **NEVER vendored** into a delivery
repo. It composes the top-level *filesystem* installer `bootstrap-project.sh` (which a
vendored copy under `.ai/templates/factory/` could not reach) with the *vendored* GitHub
scripts (`setup-repo.sh` / `setup-project.sh`). Only the ONE shared helper —
`templates/factory/scripts/lib/stage-files.sh` — is vendored, because the vendored
`setup-repo.sh` consumes it too.

This **overturns** the 013a working note that put a provisioning orchestrator under the
vendored bundle: a vendored orchestrator cannot reach `bootstrap-project.sh` or the factory
source tree, so the orchestrator's home is engine-only `scripts/`. `provision.sh` resolves
its sub-scripts + templates from `ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"`
(never `$PWD` — the #43/#44/#45 CWD bug and a path-substitution surface) so it always runs
the audited engine copies regardless of the caller's cwd.

### (b) ADR-0007 boundary EXTENSION — the first WORKFLOW the factory writes into a target repo

The `--stage-files` staging surface (ADR-0007) is generalised into a parameterised file-set
helper, `lib/stage-files.sh` (`stage_files_pr(repo, branch, title, body, copy-fn,
needs-workflow-scope)`), consumed by BOTH `setup-repo.sh` (the governance subset) and
`provision.sh` (the `sync-issues.yml` seed). The extraction is behavior-preserving for the
governance path (proven byte-for-byte by `tests/factory/stage-files-lib.sh` STG-13); every
ADR-0007 guardrail lives ONCE in the lib and is **unconditional** — the `needs-workflow-scope`
selector may only *widen the push credential*, never relax a guardrail.

**This narrowly and deliberately EXTENDS ADR-0007 guardrail 4 / SPEC-008 C6 — "No workflows
are staged".** ADR-0007 guardrail 4 explicitly rejected staging workflows (injecting the
factory build into a repo that keeps its own CI is high blast-radius). SPEC-013b extends
that surface to cover **exactly one workflow file**, `sync-issues.yml` — the first time the
factory writes a *workflow* (not a governance file) into a target repo. A merged
`sync-issues.yml` runs with the target repo's secrets and `GITHUB_TOKEN`, so a tampered one
would be a secret-exfiltration / repo-write primitive; this is why the seed is bounded by
the full ADR-0007 mechanism (open-only `gh pr create`, copy-if-absent `test -e` — never
overwrite an existing workflow, no force-push, its OWN `factory/seed-sync-issues-workflow`
branch distinct from the governance branch so a reviewer approving a workflow does so
knowingly, ephemeral `mktemp -d` clone with `trap … EXIT`, no `eval`). The worst case of a
wrong `<owner/repo>` remains a spurious open PR + a `factory/…` branch, zero merged state,
human-closable — the workflow is inert until a human reviews and merges it.

This is a **documented, deliberate reversal** of a prior security decision, not a silent
reuse. A future reader must not mistake the seed path for the governance path.

**New token-scope surface.** The workflow push needs `workflow` scope, which the global
HTTPS `insteadOf` token LACKS. The seed widens *only the push credential* by pointing
origin's push URL at the `github-dataalgebra:` SSH host alias (key-based auth — carries NO
token in the URL/argv/env); the credential is never echoed, never in a URL, and there is no
`set -x`/`GIT_TRACE` near auth. A push rejected for missing scope fails LOUD (warns naming
the step, prints the manual-seed instruction) and NEVER falls back to a token-in-URL and
never silently half-completes. **C11 preference (advisory, strong):** prefer a GitHub App
installation token (short-lived, installation-scoped, auditable) over a broad classic PAT
with `repo`+`workflow` — the `workflow` scope is the widest write privilege in the tooling
chain. The seed's push credential is a **git** credential (the `github-dataalgebra:` SSH key
or an App installation token), NOT a repo secret — `provision.sh` itself does **not** require
a `PROJECTS_TOKEN`. (`PROJECTS_TOKEN` — set via `gh secret set PROJECTS_TOKEN --body <...>` —
is the *runtime* secret the **merged** `sync-issues.yml` consumes to write the org board; that
is a separate concern from opening the seed PR.) No real token is committed in any example.

### (c) Consolidation — one thin orchestrator, re-run-to-heal, hard-vs-best-effort scoping

`provision.sh` is a THIN ordered orchestrator: `validate naming → bootstrap-project.sh (or
--upgrade: gh repo view + upgrade-project.sh) → gh repo create → setup-project.sh (JOIN the
org Project, never recreate) → setup-repo.sh → seed sync-issues.yml`. It **delegates
idempotency downward** and re-implements nothing — no naming regex (it reuses
`audit-org-naming.sh`'s `allowed()` allowlist + `setup-repo.sh`'s owner/name shape guard),
no ruleset/label/Project field logic (owned by the already-idempotent sub-scripts).

There is **no rollback**; the contract is **fail-loud-then-re-run-to-heal** (every step is
idempotent, so a run that stops on a hard failure is safe to re-run to completion once the
cause is fixed). The exit-code semantics distinguish two classes:

- **HARD (flip the exit non-zero and stop):** naming validation, bootstrap, repo-create /
  `gh repo view` existence in `--upgrade`, labels, rulesets, Project. A half-provisioned repo
  MUST NOT read as success.
- **BEST-EFFORT (warn LOUD on stderr naming the step, do NOT flip the exit, never
  `/dev/null`):** the `sync-issues.yml` seed, and `setup-repo.sh`'s environment-422s
  (ADR-0003, free-tier deploy environments). A failed seed is surfaced as "provisioned
  EXCEPT board-sync" with the manual-seed instruction — the repo is never *silently* left
  un-synced.

The orchestrator is NOT framed as wholly best-effort.

### (d) Dry-run-gates-delegation, and `--upgrade`

The sub-scripts have **no dry-run mode** and mutate on invocation, so `--dry-run` gates ALL
delegation **at the orchestrator**: it prints the plan and invokes **NO** sub-script —
critically including the *filesystem*-mutating `bootstrap-project.sh` — makes **ZERO**
mutating `gh` calls, and clones/pushes nothing. (A read-only `gh repo view` for `--upgrade`
existence would be permissible; the shipped implementation makes even that call only in
apply mode, so dry-run is `gh`-free.) The dry-run leak surface is not only `gh`; it is any
sub-script invocation.

`--upgrade` swaps the create steps for a `gh repo view` existence check (HARD — fail if
absent) and runs the GitHub-side steps non-destructively (Project → `setup-repo.sh` → seed).
The `.ai/` bundle refresh into an existing local checkout stays `upgrade-project.sh`'s
concern (a local-filesystem op); `provision.sh` **never pushes the bundle to `main`**.

## Consequences

Positive:
- One idempotent command provisions or upgrades a repo; no more forgotten steps.
- The governance and workflow-seed git-writes share ONE audited guardrail skeleton
  (`lib/stage-files.sh`) instead of a divergent second copy — the ADR-0007-forbidden
  outcome — with the governance path proven byte-for-byte unchanged across the extraction.
- The "first workflow write" is an isolated, attributable, human-reviewed PR on its own
  branch; the audit trail (who merged the workflow) is preserved (open-only).

Negative / trade-offs:
- The seed introduces a new, wider credential (`workflow` scope) into the tooling chain.
  Its *leakage* is bounded by token hygiene (never in URL/argv/echo); its *existence* is
  bounded by the C11 App-token-over-broad-PAT preference.
- No rollback: a hard failure leaves a partially-provisioned repo. This is intentional
  (fail loud, re-run-to-heal) rather than a transactional orchestrator.
- An existing remote `factory/…` seed branch is a skip/reuse signal (never reset-and-force),
  the same no-force tension ADR-0007 records for the governance branch.

## Alternatives considered

- **Vendor the orchestrator under `templates/factory/`** (the 013a note). Rejected — a
  vendored copy cannot reach `bootstrap-project.sh` or the factory source tree (decision a).
- **Inline a second copy of the ADR-0007 guardrails for the seed, or fold the workflow into
  the governance PR.** Both rejected: a divergent second copy is exactly what ADR-0007
  forbids, and folding the workflow into the governance push would fail the `workflow`-scope
  gate AND smuggle a workflow into a governance review (decision b / C2).
- **Give `--dry-run` to the sub-scripts and let the orchestrator delegate in dry-run.**
  Rejected as out of scope and higher-risk: gating at the orchestrator (invoke nothing) is a
  simpler, provable zero-mutation contract (decision d).
- **Treat the whole orchestrator as best-effort** (the spec's early wording). Rejected: a
  repo with no gates or no board is not "provisioned" — those steps are HARD; only the seed
  and env-422 are best-effort (decision c / C8).
