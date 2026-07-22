# ADR-0005: Install file-ownership boundary — factory-owned refreshed, repo-owned copy-if-absent

Status: Accepted
Date: 2026-07-09
Deciders: Architect (via SPEC-007)
Related: SPEC-007 (`/onboard-repo` + command filter), SPEC-002 (dogfood onboarding fixes),
ADR-0004 (command classification)

## Context

`bootstrap-project.sh` was written for the **greenfield** case (`<repo>-delivery`): it seeds a
brand-new project and freely overwrites conventions — most sharply, it **unconditionally
overwrites `CODEOWNERS`** (`bootstrap-project.sh:135-137`), re-seeds the `knowledge/*.yaml` files,
and re-writes issue/PR templates. Its only mode selector is `--github-only`.

SPEC-007 introduces onboarding an **existing** repo (Path B) — a repo that already has its own
code, `CODEOWNERS`, real `knowledge/*.yaml`, a real `Makefile`, and possibly its own `.github/`.
Running the greenfield seed against such a repo would **destroy the repo's own files** (spec Gap B,
`spec.md:32-37`; Risk #1, `:373-376`). We need a safe existing-repo install mode, and that mode
forces an architectural question that outlives this spec: **which files does the factory own (and
may overwrite on every install/upgrade), and which belong to the target repo (and must never be
touched)?**

## Decision

**Partition every install target into two ownership classes, and treat each by a fixed policy. Add
a `--target-existing` mode to `bootstrap-project.sh` that applies this partition.**

1. **Factory-owned — always install/refresh (overwrite):** the `.ai/` method bundle
   (`agents/workflows/skills/prompts/templates`, `METHOD_VERSION`) and the `.claude/` delivery
   layer (subject to ADR-0004's filter, so an onboarded existing repo gets exactly
   `feature-delivery` + `post-merge`). These are regenerable from the factory checkout and are safe
   to overwrite — this is exactly how `upgrade-project.sh` already treats them.
2. **Repo-owned — seed copy-if-absent, never overwrite:** root `CODEOWNERS`; the lifecycle dirs
   (`specs/`, `tickets/`, `verification/`, `prs/`, `knowledge/` and their contents); `knowledge/
   *.yaml`; `Makefile`; `docs/delivery-ledger.md`; `.github/ISSUE_TEMPLATE/` and
   `.github/PULL_REQUEST_TEMPLATE.md`. When the target already exists it is **preserved
   byte-for-byte**; when absent it is created with the same content bootstrap seeds today.
3. **Mechanism = a copy-if-absent primitive, not an enumerated skip-list.** Every convention seed is
   guarded by `test -e "$target"` (skip if present) rather than by an author-maintained list of
   files to avoid. The primitive is structurally safe: it cannot clobber *anything* that already
   exists — enumerated or not — because "already exists → skip" is the default for all seeds. The
   enumerated never-overwrite list in the spec is the *minimum set to test with sentinels*; the
   primitive is what makes the behavior exhaustive.
4. **Idempotent:** a second `--target-existing` run changes nothing and adds nothing (every seed is
   guarded; the factory-owned overwrite is deterministic).
5. **Greenfield unchanged:** the copy-if-absent behavior is gated behind `--target-existing`.
   Default `bootstrap` keeps its unconditional seed/overwrite for the greenfield `<repo>-delivery`
   case — the greenfield path is byte-for-byte unchanged. `--target-existing` is purely additive.

## Consequences

Positive:
- Onboarding an existing repo can never destroy the repo's own `CODEOWNERS`, knowledge, `Makefile`,
  or lifecycle artifacts — the Medium data-loss risk is reduced to near-zero by the primitive,
  independent of how complete the enumerated list is.
- The factory still fully controls (and can upgrade) the method bundle, so an onboarded repo tracks
  the method exactly like a greenfield one.
- The ownership boundary is a single, reusable rule that governs all future install/upgrade
  behavior — future maintainers have one line to not cross: *never move a repo-owned artifact into
  the always-overwrite class.*

Negative / trade-offs:
- Copy-if-absent means the factory cannot *update* a convention file (e.g. a new default `Makefile`
  target) in an existing repo — it will not overwrite the repo's version. This is the intended
  safety trade: divergence is the operator's to reconcile, not the tool's to clobber.
- Two policies by target class add a little conditional logic to the install path. Mitigated by the
  small shared primitive rather than per-file special-casing.

## Alternatives considered

- **Enumerated skip-list only.** Rejected as the *mechanism*: it is only as complete as the
  author's memory of every repo artifact, and a missed file type (e.g. a custom `.github/
  workflows/`) is exactly the data-loss hazard. The copy-if-absent primitive subsumes it.
- **A single always-overwrite policy with a warning.** Rejected: warnings do not prevent data loss,
  and an existing repo's files are not the factory's to overwrite.
- **A separate `upgrade-existing` script.** Rejected as needless surface: the ownership boundary is
  the same idea `upgrade-project.sh` already applies to the method bundle; a mode flag on
  `bootstrap` keeps one install entry point.
