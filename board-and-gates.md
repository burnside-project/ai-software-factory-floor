# The board and the gates

What the factory board is, what actually moves cards on it, which parts a script provisions and
which parts you must click, and how to bring an existing instance up to date.

This is the explanatory document. It is **not** a source of truth for any list:

| Thing | Source of truth |
|---|---|
| The Stage vocabulary | [`templates/factory/stage-map.tsv`](../templates/factory/stage-map.tsv) |
| The board's fields, drivers and UI-only gaps | [`templates/factory/.github/PROJECTS.md`](../templates/factory/.github/PROJECTS.md) |
| The order you run things in | [`PROVISIONING.md`](../PROVISIONING.md) |

`tests/factory/test-stage-map.sh` fails the build if `PROJECTS.md` and `stage-map.tsv` disagree, so
those two are held in step mechanically. **This file deliberately does not restate the Stage list** —
a fourth copy is exactly the drift that produced `stage-map.tsv` in the first place.

---

## What the board is

One org-level GitHub Projects v2 board — `Your Factory Board` — with one card per work item,
moving left to right along the Stage line. There is exactly one board, and it is **org-level, not
repo-level**. That is the point: `metrics.sh` reports flow across every onboarded repo, and
`lib/sync-issues.sh` projects host-authored specs and tickets onto *other* repos' issues via each
artifact's `repo:` front-matter key. A repo-level board would drop the `PROJECTS_TOKEN` requirement
(repo projects are writable by `GITHUB_TOKEN`) but would lose the cross-repo roll-up, which is the
reason the board exists at all.

The Stage line itself is a data file, not code: `stage-map.tsv` maps each `stage:*` GitHub label to
its Projects v2 `Stage` option, and `setup-project.sh`, `board-sync.sh`, `metrics.sh` and
`setup-repo.sh` all derive from it. Four Stage options are **intentionally unmapped** — no label
marks them, because nothing in the label state machine does. That is documented, not broken;
`board-sync.sh` exits 0 on a label it cannot map. `PROJECTS.md` explains each case.

### Where these labels live — managed repos, not the factory repo

The `stage:*` / `type:*` / `priority:*` / `status:*` / `audit:*` taxonomy is provisioned by
`setup-repo.sh` onto the **belt repos the factory manages** — the repos that actually run the
conveyor. It is **not** applied to the `ai-software-factory` framework repo itself, so that repo's
own *Labels* page shows only GitHub's stock defaults (bug, enhancement, …). This is expected, not a
provisioning miss: the factory repo is a **lightweight-gate framework repo** (ADR-0011) whose own
process is driven by **files** — `tickets/*.md` and `specs/` — not by GitHub-issue labels. So the
taxonomy described here is what you will see on a repo *after* `setup-repo.sh` runs against it, not
on the framework repo. `gate:*` labels are a further special case — inert, human-applied signals
with no machine enforcement, deliberately not provisioned at all (see below).

---

## What moves cards

Three shipped components write to the board. All three need `PROJECTS_TOKEN` — `GITHUB_TOKEN`
cannot write org Projects v2 — and all three fail **soft** with a `::notice::` and exit 0 when the
token is absent, so a repo without the secret is degraded, never broken.

| Component | Writes | Trigger |
|---|---|---|
| `lib/sync-issues.sh` via `sync-issues.yml` | creates the board item; seeds `Stage` **on create only** | push to `main` touching `specs/**` / `tickets/**` |
| `board-sync.sh` via `board-sync.yml` | updates `Stage` on later transitions | `issues: labeled` with a `stage:*` label |
| `metrics.sh` via `metrics.yml` | nothing — **read-only** | weekly schedule |

The division matters: `sync-issues.sh` seeds a Stage only when it first creates the card, so it can
never fight `board-sync.sh` over an item already in flight.

### The gate labels do not move anything


`gate:*` labels are **inert**. Applying one will not advance a stage, will not open or close a gate,
and is not checked by anything at merge time. Two decisions produce that:

- `gate-enforcer.yml` is **dropped**. It was fail-open four separate ways — skippable via its own
  `if:`, never registered as a required check, verifying labels it had itself applied, and calling
  the invalid `gh pr view --labels` so it errored on the first gate whenever it did run. Dropping it
  removes no real enforcement, but the *appearance* of coverage must not survive it: after SPEC-016
  **there is no machine enforcement of `gate:*` labels at all**, and provisioning deliberately does
  not create `gate:*` labels for a control that does not exist.
- `gate-auto-transition.yml` is **deferred**, not shipped. Its label writes collide with the
  `stage:*` labels `` consumes as its drive signal, with no concurrency guard on
  either side. The collision and a proposed guard are recorded as the open design problem rather
  than shipping a racy fix.

The gates that actually enforce are the ones in the repo ruleset — required status checks
(`lint`, `test`, `build`, `verification`, `audit` per variant), CODEOWNERS approval, force-push
protection — plus the `production` environment's required reviewer. Those are configured by
`setup-repo.sh` and flipped from `evaluate` to `active` by an operator. See
[`PROVISIONING.md`](../PROVISIONING.md) and [`templates/factory/ACTIVATE.md`](../templates/factory/ACTIVATE.md).

### Other workflows on the floor


| Workflow | Status | What it does |
|---|---|---|
| `issue-template-validator.yml` | retained | comments and labels on a malformed issue — **report-only**, it does not reject |
| `gate-status-dashboard.yml` | retained | writes gate visibility to `$GITHUB_STEP_SUMMARY` |
| `feature-request-to-spec.yml` | retained | opens a spec issue from a feature-request discussion; idempotent (skips if an issue already links the discussion URL) |
| `stage-label-sync.yml` | dropped | listened for a Projects-*classic* event that cannot fire, and duplicated `board-sync.yml` against a different Stage vocabulary |
| `gate-enforcer.yml` | dropped | see above |
| `gate-auto-transition.yml` | deferred | see above |

Every retained workflow declares an explicit least-privilege `permissions:` block and takes
untrusted event data through `env:` bindings only — never `${{ github.event.* }}` interpolated
directly into a `run:` block. That indirection is the durable control; it generalises past these
specific files.

---

## Script-provisioned vs UI-only

**Script-provisioned** (`setup-project.sh`, idempotent, re-run freely):

- the org Project itself;
- the `Stage` single-select and its options, derived from `stage-map.tsv`;
- the `Spec` text field;
- the `Work Type` and `Priority` single-selects.

The field is `Work Type`, **not** `Type` — `Type` is a reserved Projects v2 field name and the API
rejects it outright, which under `set -euo pipefail` aborted the whole script and hard-failed
provisioning. Evidence and the reserved-name probe:
[`verification/results/TICKET-067-live-board.md`](../verification/results/TICKET-067-live-board.md).

**UI-only — no script does these, because GitHub exposes no API for them:**

- Projects v2 **views** (the Stage board view, the Spec table view);
- per-column **WIP limits**;
- the built-in Project **workflow automations** (auto-add, auto-archive on close);
- **discussion categories** — the `DISCUSSIONS-*.md` charters shipped under
  `templates/factory/.github/` are intent for a human to type in, not provisioning input.

Any doc claiming a script creates one of these is wrong. Do them once, by hand, after
[`PROVISIONING.md`](../PROVISIONING.md) step 4.

---

## How to upgrade

One command, documented in full under **"Upgrading an existing instance"** in
[`PROVISIONING.md`](../PROVISIONING.md):

```bash
./scripts/provision.sh "$ORG/<repo>" --upgrade
```

There is no separate upgrade script and none is wanted. `provision.sh --upgrade` runs the existence
check, the local `.ai/` bundle refresh (only with `--checkout`; skipped otherwise), the board, and
the gates — all idempotent. `scripts/upgrade-project.sh` is the **local-filesystem leg only**,
invoked by the orchestrator; read alone it looks like the whole path, which is the standing trap.
[ADR-0005](decisions/ADR-0005-install-file-ownership-boundary.md) rejected a standalone
`upgrade-existing` verb and
[ADR-0012 §(d)](decisions/ADR-0012-factory-provisioning-automation.md) rejected per-sub-script
`--dry-run`/`--apply`.

Two things upgrade cannot reach: the UI-only list above, and convention files already present in a
target repo (seeded **copy-if-absent**, so the factory can never update or delete one — by design,
so it cannot clobber a repo's own conventions).

**Board fields are permanent.** The upgrade path is additive-only: it can create a missing field,
never remove or retype one, and renaming a single-select option does not migrate existing cards.
Add a field only once something actually writes it — an unwritten field ships as a permanently
empty column you cannot take back. Smoke-test any new field against a throwaway board before it
reaches a provisioning path.

---

## Verification status

This document describes shipped behaviour and claims no completion state of its own. The one live
run behind the board claims here is
[`verification/results/TICKET-067-live-board.md`](../verification/results/TICKET-067-live-board.md)
(field creation, idempotency on re-run, Stage options confirmed byte-identical to `stage-map.tsv`).
Where a claim is not backed by an artifact under `verification/results/`, it is written as a
decision, not as a verified outcome.
