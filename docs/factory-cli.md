# `factory` — the CLI

`factory` is the single entrypoint for the configurable factory framework (SPEC-019). It is a
**thin dispatcher**: it resolves the two anchors (below) and routes to verb logic in `lib/`. It
parses no config YAML itself — YAML parsing lives only in the python authoring tool (ADR-0015
Decision 3).

## Verbs

| Verb | Purpose | Status |
|---|---|---|
| `factory validate [--config PATH]` | offline schema + secret-shape validation, no mutation | **live** (TICKET-095) |
| `factory provision <owner/repo> [...]` | bootstrap/upgrade a repo (delegates to the audited orchestrator) | **live** (compat wrapper) |
| `factory sync [...]` | print a reconcile **plan** (dry-run, default); `--apply` reconciles config → GitHub | **live** (TICKET-102) |
| `factory migrate --to vN` | file-only schema migration (writes a patch, never mutates remote) | **live** (TICKET-106) |
| `factory doctor [--repo owner/name]` | cutover pre-flight; **side effect** — issues one `factory-doctor-probe` dispatch | **live** (TICKET-107) |
| `factory inspect` | show resolved configuration | TICKET-102+ |

A verb whose ticket has not landed fails loud (`exit 3`), never a silent no-op.

## The two anchors

`factory` deliberately keeps **engine discovery** and **config-root discovery** separate — the
trap that would make a vendored second repo read the framework author's config:

- **Engine anchor** — where the framework code lives. Resolved from the `factory` script's own
  location (`BASH_SOURCE`), never `$PWD`. In a vendored consumer this is `.ai/…`.
- **Config-root anchor** — where *your* `factory.config.yaml` lives. Resolved from your repo root
  (`git rev-parse --show-toplevel` of `$PWD`) or an explicit `--config PATH`. Your config always
  wins; there is no fallback to the engine's config.

Resolution precedence for the config file: `--config PATH` > `FACTORY_CONFIG=<path>` (whole-config
pointer; no per-field env override — ADR-0015 Decision 8) > `<config-root>/factory.config.yaml`.

## Compat wrapper

`scripts/provision.sh` still works exactly as before; it now forwards to `factory provision` so
every path routes through the one entrypoint. `factory` re-invokes the orchestrator with
`FACTORY_VIA_SHIM=1` so there is no recursion, and all existing `scripts/provision.sh <args>`
invocations are unchanged.

## `factory sync` — plan, `--apply`, and the credential matrix

`factory sync` compiles `factory.config.yaml` and reconciles it against live GitHub state.

- **`factory sync`** (no flag) — prints a **plan** and makes **zero mutation** (dry-run default).
  It resolves every object by its **natural key each run** (org by slug, org variables & secrets by
  name, the org Project by title, rulesets by name) — there is **no lock, no ID cache, no state
  file** (ADR-0015 Decision 6). For each org variable it classifies create / update / **no-op**; it
  verifies each identity secret/variable is **present** at its scope (names only — never the value);
  and it shows create/update for the org Project and the routing-named rulesets, which `--apply`
  reconciles by delegating to the idempotent appliers (`setup-project.sh` joins the project by
  title; `setup-repo.sh` applies the routed ruleset by name).
- **`factory sync --apply`** — writes the compiled `.factory/factory.env` and reconciles GitHub.
  Re-applying an unchanged value is a **no-op**.
- **`factory sync --check-compile`** — drift gate: fails if the on-disk `factory.env` differs from a
  fresh compile (read-only, CI-safe).

### The credential matrix (the security core)

`sync --apply` mutates live org state, so **who** may run it — and under **which** credential — is
load-bearing. Dry-run-default guards an *accident*; least-privilege + human-held + not-in-a-workflow
guards a *leaked* credential. Both are required.

| Verb / mode | Scope | Credential | May run in a workflow / CI? |
|---|---|---|---|
| `sync` (plan), `sync --check-compile`, `migrate` | read-only¹ | any read-scoped `gh` auth | **yes** (CI-safe) |
| `validate`, `inspect` | read-only | read-scoped | **yes** |
| **`doctor`** | **side effect** — issues one probe `repository_dispatch` | read-scoped diagnostics + short-lived App token for the probe | **operator step** (not run on-merge) |
| **`sync --apply`** | **mutates org variables / rulesets / project** | **operator-only, human-held admin `gh` auth** | **NO — refused** |

¹ `migrate` is file-only: it rewrites the checked-in config and makes no network/`gh` call.

- `sync --apply` is **never a workflow secret** and **never run on-merge**. Running it inside a
  workflow/CI context (detected via `GITHUB_ACTIONS` / `CI`) is **refused** with a non-zero exit,
  *before any mutation*, so a leaked workflow credential can never rewrite rulesets, variables, or
  the project.
- The builder App deliberately lacks `Administration`, so `--apply` cannot run under it — an
  operator applies it under their own admin auth.
- `sync` verifies secret **presence** at the named scope and **never reads or prints material**.

Schema: [`templates/factory/schema/factory.config.v1.md`](../templates/factory/schema/factory.config.v1.md).

### Ruleset downgrade gate (TICKET-105)

`factory sync` diffs each routing-named repo's desired ruleset against the **live** one and flags a
**weakening** of branch protection — enforcement `active→evaluate`, a lowered approval count, or a
dropped required status check — as a `downgrade` in the plan. Applying a downgrade requires the
explicit **`--allow-downgrade`** flag; without it, `--apply` SKIPS the weakening (safe by default).
The `evaluate→active` flip is a *strengthening* and stays **human-only** — it is flagged, never
auto-applied. `factory.config.yaml` and the ruleset routing are covered by `.github/CODEOWNERS`, so
a config PR that would weaken protection needs the owning reviewers.

## `factory doctor` — cutover pre-flight (TICKET-107)

`factory doctor` turns the manual App investigation into a repeatable pre-flight: it checks the
things whose absence only bites **during** a cutover. A non-zero exit means *do not cut over yet*.

Checks (each reported pass/fail): `gh`/API connectivity · App ID configured (org variable) ·
**private-key secret present** (presence only — the value is never read) · installation covers the
repos · installation **token can be minted** · **`repository_dispatch` can be issued** · runner
labels resolve · project access · `python3` + PyYAML.

**`doctor` has a side effect** and is classified as such in the credential matrix. To prove the App
can actually drive the belt it issues **one** real `repository_dispatch` on a **dedicated,
unconsumed** event type — `factory-doctor-probe`. It never reuses a consumed event type; the probe
event has no arbiter, so it moves nothing. Because it mutates (creates a dispatch), `doctor` is an
**operator step**, not run on-merge.

**Token hygiene (security review BLOCK-4).** Two secret-shaped values pass through the live probe —
the App private key (`-----BEGIN…`) and the short-lived installation token (`ghs_…`) minted from it.
**Neither is ever written to stdout, stderr, or a log:** the private key is streamed to `openssl`
on stdin, and the token is held in a local and handed to `gh` out-of-band via the environment. Only
redacted status lines are printed.

Live run (operator): point `doctor` at the App key and issue the probe against one repo —

```bash
FACTORY_DOCTOR_APP_KEY=/path/to/app-private-key.pem FLOOR_APP_ID=123456 \
  factory doctor --repo your-org/some-repo
```

Dry, offline dependency/plan check (no network, no dispatch) — `FACTORY_DOCTOR_MOCK=1 factory doctor`.
