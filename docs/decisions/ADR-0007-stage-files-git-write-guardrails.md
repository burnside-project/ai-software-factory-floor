# ADR-0007: Factory git-write to a target repo — `--stage-files` guardrails (open-only, bounded blast radius)

Status: Accepted
Date: 2026-07-09
Deciders: Architect (via SPEC-008)
Related: SPEC-008 (`--stage-files` + retire the ruleset switch), SPEC-005/006/007 (governance floor),
ADR-0003 (best-effort external calls), ADR-0005 (install file-ownership boundary),
ADR-0002 (autonomous floor motor — never-auto-merge),
ADR-0012 (provisioning automation — deliberately EXTENDS guardrail 4 to one workflow, `sync-issues.yml`)

## Context

Every GitHub side effect the factory's setup scripts have performed to date mutates a target repo's
**config/metadata surface** via `gh api` POST/PUT — labels, rulesets, deploy environments
(`setup-repo.sh`). `setup-host-repo.sh` clones/pushes, but only the factory's **own** workspace to a
repo it just created. No factory script has ever written to a *third-party target repo's git
contents*.

SPEC-008's `--stage-files` is the first: to close a real governance gap (the applied ruleset's
`require_code_owner_review` is inert until a `CODEOWNERS` file lands in the repo, and today that copy
is a hand-printed manual step at `setup-repo.sh:40-43`), it **clones the target repo, creates a
branch, commits the governance files, pushes the branch, and opens a PR** via the App token. That is
the largest GitHub-mutation surface in the factory: it can push a branch to a live code repo.

Existing decisions cover *parts* of this but not the whole:
- **ADR-0003** governs best-effort/exit-code (warn-and-continue) — not git-write guardrails.
- **ADR-0005** governs copy-if-absent file ownership for a *local* install — not remote git-write.
- **The SPEC-005/006/007 floor** is the agent/human boundary and command-coupling rule — prose, not
  a recorded git-write contract.

A new capability class this consequential — and one future factory scripts writing to target repos
should inherit verbatim — warrants its own recorded boundary. (This is the Q4 call: **two ADRs**.
ADR-0006 covers ruleset selection; this covers the git-write capability, because it *adds* guardrails
none of ADR-0003/0005 or the floor record, not merely applies them.)

## Decision

**Factory code that writes to a target repo's git does so under a fixed set of guardrails. The
`--stage-files` capability is the reference implementation; the guardrails bound its blast radius to
"a spurious open PR + a pushed feature branch, both trivially reversible, zero merged state."**

1. **Opt-in, default OFF.** `--stage-files` is a flag. Without it, `setup-repo.sh` prints the manual
   copy instructions exactly as today (`:40-43`) — no existing invocation changes behaviour and no
   clone/branch/push/PR occurs.

2. **Open-only — never merge, approve, or self-approve.** The only PR verb is `gh pr create`. No
   `gh pr merge`, no `--auto`, no `gh pr review --approve`, no self-approval. A human reviews and
   merges. This is the SPEC-005/006/007 floor and ADR-0002's never-auto-merge, applied verbatim to a
   git-write path.

3. **Safe git — never write a protected/default branch directly, never force.** Push only the
   deterministic `factory/…` feature branch; never push to the repo's default or any protected
   branch. No `git push --force` / `--force-with-lease`. The branch name
   `factory/stage-governance-files` is **verified to satisfy the factory-naming ruleset**
   (`^(…|factory)/[a-z0-9][a-z0-9._/-]*$`) — the factory pushes a branch its own naming gate accepts.

4. **Copy-if-absent (ADR-0005 applied to a remote clone).** Stage only the **governance subset** —
   `CODEOWNERS`, `.github/ISSUE_TEMPLATE/`, `.github/PULL_REQUEST_TEMPLATE.md` — and only where the
   target path is **absent**. The repo's own files are never overwritten. This is the same repo-owned
   copy-if-absent class ADR-0005 defines, now enforced against a cloned working tree. **No workflows**
   are staged (SPEC-008 Q1 / SPEC-004 C7): injecting the factory build into a repo that keeps its own
   CI is high blast-radius and is the very thing `reconcile-ci-checks.sh` exists to avoid.
   > **Later extended (ADR-0012 / SPEC-013b).** This "no workflows are staged" guardrail was
   > deliberately, security-reviewed, EXTENDED to cover **exactly one** workflow — `sync-issues.yml`,
   > seeded by `provision.sh` on its own `factory/seed-sync-issues-workflow` branch under this same
   > guardrail skeleton (open-only, copy-if-absent, no-force). All other guardrails here are unchanged;
   > see [ADR-0012](ADR-0012-factory-provisioning-automation.md) for the reasoning.

5. **Idempotent, no duplicates, no force.** Before staging, detect prior state and skip rather than
   duplicate: an existing **open** PR on head `factory/stage-governance-files`
   (`gh pr list --head … --state open`) → report/reuse its URL, skip; an existing **remote branch** →
   reuse/skip (see the force-push caveat in Consequences); **no diff** after copy-if-absent → skip (no
   empty commit, no empty PR, report "already staged"). A second run opens no second PR.

6. **Best-effort per ADR-0003.** The whole `--stage-files` block is warn-and-continue: any failure
   (clone/branch/commit/push/PR-create) prints a visible warning and lets the rest of the run
   (labels already done; rulesets, naming, environments still to come) complete. Staging never aborts
   the run; the exit-code contract (exit 0 == run reached completion) is unchanged. The steps are
   ordered so a mid-sequence failure is safe to retry (idempotent) and never leaves a half-pushed
   state that looks successful.

7. **Ephemeral clone, always cleaned.** Clone to a `mktemp -d`; remove it via `trap … EXIT` so it is
   gone even on the warn-and-continue failure path. No orphaned clones, no local dirty state leaks
   into the commit (the tree is a fresh clone; the commit is exactly the copy-if-absent diff).

8. **Token & injection hygiene.** Authenticate over the transport `gh` already uses; the App token is
   **never echoed, logged, or embedded in a remote URL** (a URL-embedded token leaks via `ps`/logs) —
   use `gh`'s git credential helper. No `eval`. The only repo-controlled input is `$REPO` (the script
   arg) and the temp clone path — both quoted, never placed in a command position.

## Consequences

Positive:
- **Bounded worst case.** A wrong `$REPO` (typo) clones + pushes a `factory/stage-governance-files`
  branch to the wrong repo and opens a PR there. Because staging is open-only (nothing merges → the
  wrong repo's `main` is untouched), copy-if-absent (only adds files, on a branch, in a reviewable
  PR), and no-force (the deterministic branch is trivially identifiable and deletable), the damage is
  a spurious open PR + a feature branch — both closable/deletable by a human, **zero merged state**.
  The App token's scope bounds which repos are even writable.
- **Closes a governance gap:** the CODEOWNERS the ruleset requires actually lands (via a reviewed PR)
  instead of depending on a human remembering the manual hand-copy.
- **A reusable contract:** any future factory script that writes to a target repo inherits these eight
  guardrails. This ADR is the reference.

Negative / trade-offs:
- **Existing-remote-branch reuse vs. no-force is a genuine tension.** If the remote
  `factory/stage-governance-files` already exists with commits, "reset to default + re-commit +
  push" would need a force push (non-fast-forward) — which guardrail 3 forbids. The safe resolution
  (a Tech-Lead implementation constraint flagged in the SPEC-008 review) is to treat an existing
  remote head as a **skip/reuse** signal and *not* attempt a repush, rather than reset-and-force.
  This trades a small loss of "refresh the branch" convenience for an absolute no-force guarantee.
  Residual concurrency window (two runs racing before either pushes) is SPEC-008 Q3 — accepted as
  low-likelihood for an operator-invoked script.
- Staging runs after the labels block (so the `skip-ticket` PR label exists) and before the ruleset
  blocks — an ordering dependency to preserve when editing `setup-repo.sh`.

## Alternatives considered

- **No ADR — treat `--stage-files` as just ADR-0003 + ADR-0005 + the floor.** Rejected: those cover
  best-effort, local file ownership, and the agent/human boundary respectively, but **none** records
  the git-write guardrails that actually bound this capability — open-only on a pushed branch, no
  force-push, deterministic naming-ruleset-compliant branch, temp-clone cleanup, token-in-credential-
  helper-not-URL. Those are new and reusable; they belong in a recorded decision.
- **Auto-merge the staged PR.** Rejected outright — violates the never-auto-merge floor (ADR-0002,
  SPEC-005/006/007). Humans merge.
- **Stage the factory workflows too.** Rejected (SPEC-008 Q1 / non-goal): clobbers/duplicates a live
  repo's own CI; `reconcile-ci-checks.sh` adapts the ruleset to the repo's real checks precisely so
  the factory does not have to inject its build.
- **Make `--stage-files` the default.** Rejected: it is the largest mutation surface; opt-in keeps
  every existing invocation unchanged.
