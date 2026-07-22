#!/usr/bin/env bash
# Shared ADR-0007 git-write staging helper — the SINGLE implementation of the
# "clone a target repo, copy a file set copy-if-absent, open a review PR" flow.
# Extracted from setup-repo.sh's stage_governance_files() (SPEC-008, C1-C8) so
# BOTH setup-repo.sh (the governance subset) and a future provision.sh workflow
# seed reuse ONE audited guardrail skeleton instead of a divergent second copy
# (the ADR-0007-forbidden outcome). This file is SOURCED, never executed:
#
#   . "$(dirname "${BASH_SOURCE[0]}")/lib/stage-files.sh"
#   ( stage_files_pr "$repo" "$branch" "$title" "$body" my_copy_fn 0 )   # in a subshell
#
# stage_files_pr(repo, branch, pr-title, pr-body, copy-fn, needs-workflow-scope):
#   - repo      : owner/name of the target repo (shape-guarded before any clone/push).
#   - branch    : the deterministic factory/… branch to push (a fixed caller literal).
#   - pr-title  : the PR title (a fixed caller literal).
#   - pr-body   : the PR body (a fixed caller literal).
#   - copy-fn   : the name of a caller function `copy_fn <clone-dir>` that stages the
#                 caller's file set into the clone using stage_files_cp_if_absent
#                 (copy-if-absent). This is the ONLY data variation to WHAT is staged.
#   - needs-workflow-scope : 0 (default gh credential helper, as today) or 1 (a HOOK for
#                 a caller that must WIDEN the credential to push a workflow file — filled
#                 in by TICKET-063). It may only WIDEN the credential; it NEVER relaxes or
#                 skips a guardrail — every guardrail below runs on both paths.
#
# EVERY ADR-0007 guardrail lives ONCE here and is UNCONDITIONAL (security-review C-LIB):
#   C1 token hygiene — clone/push over `gh` (its git credential helper); NEVER a
#      token-in-URL (no `x-access-token:$TOKEN@…`); token never echoed; NO `set -x`/GIT_TRACE
#      near auth; the warn path names the failed step WITHOUT echoing token-bearing argv.
#   C2 open-only — `gh pr create` and nothing else (no merge/approve/--auto/activation).
#   C3 no force-push — plain `git push` of the factory/… branch ONLY; an existing remote
#      branch or open PR is a SKIP/REUSE signal, never a reset-and-repush.
#   C4 ephemeral clone — `mktemp -d` + `trap … EXIT` (fires on every path incl. failure);
#      NO `eval`; $REPO + the temp path always quoted, never in a command position. `dir`
#      is deliberately NOT `local` (see the note below).
#   C5 no untrusted repo content in a command position — branch/commit/PR title+body are
#      fixed caller literals; values read back from git/gh are captured + used only quoted.
#   C6 copy-if-absent — the caller stages via stage_files_cp_if_absent (`test -e`-guarded);
#      existing repo files preserved byte-for-byte; no-diff → skip (no empty commit/PR).
#   C8 best-effort — any failure warns LOUDLY on stderr (names the step) and returns
#      non-zero to the caller's subshell; never swallowed to /dev/null, never masked as
#      "already staged". The caller runs this in a subshell so the EXIT trap cleans the
#      clone on every path.
set -euo pipefail

# stage_files_cp_if_absent <src> <dest> — the ONE copy-if-absent primitive (C6). Copies
# src -> dest ONLY when dest is absent; an existing target file is preserved byte-for-byte
# and NEVER overwritten. There is no "force" parameter: no caller can clobber through it.
stage_files_cp_if_absent() {
  local src="$1" dest="$2"
  [ -e "$dest" ] || cp "$src" "$dest"
}

# stage_files__clone <repo> <dir> <needs-workflow-scope> — C1 clone transport. The
# needs-workflow-scope selector may only WIDEN the credential; it relaxes no guardrail.
# The clone (a READ) always goes over `gh`'s credential helper — byte-for-byte as SPEC-008,
# NO token in any URL, token never echoed — on BOTH paths. For needs-workflow-scope=1
# (TICKET-063: a workflow-file seed), the eventual PUSH needs `workflow` scope, which the
# global HTTPS `insteadOf` token LACKS; so we WIDEN only the *push* credential by pointing
# origin's push URL at the `github-dataalgebra:` SSH host alias (key-based auth — carries NO
# token in the URL/argv/env, the cleanest option per security-review C-WFAUTH). The fetch URL
# stays over gh; the ephemeral-clone, quoting, and no-token-in-URL guarantees are identical
# on both paths, and NO guardrail is relaxed — this only changes which credential the push uses.
stage_files__clone() {
  local repo="$1" dir="$2" needs_ws="$3"
  gh repo clone "$repo" "$dir" -- --quiet || return 1
  case "$needs_ws" in
    1) git -C "$dir" remote set-url --push origin "github-dataalgebra:$repo.git" ;;
    *) : ;;
  esac
}

# stage_files__push <dir> <branch> <needs-workflow-scope> — C3 push transport. Plain push
# of the factory/… branch ONLY: NO --force/--force-with-lease/+refs, never a default/
# protected branch. C1: no token in a URL. For needs-workflow-scope=1 the push transparently
# routes over the widened workflow-scope PUSH remote already selected in stage_files__clone
# (the `github-dataalgebra:` SSH alias) — same `git push -u origin` on both paths, no token in
# argv, no fallback to a token-in-URL. A rejected push (e.g. missing `workflow` scope)
# propagates a non-zero here and is surfaced LOUD by stage_files_pr (C1/C-WFAUTH/C8).
stage_files__push() {
  local dir="$1" branch="$2" needs_ws="$3"
  case "$needs_ws" in
    1) : "workflow-scope push routes over the origin push URL widened in stage_files__clone" ;;
    *) : ;;
  esac
  git -C "$dir" push -u origin "$branch"
}

stage_files_pr() {
  local repo="$1" branch="$2" title="$3" body="$4" copy_fn="$5" needs_ws="${6:-0}"
  local base prurl existing
  local warn="WARNING: stage-files"
  # `dir` is deliberately NOT `local`: the EXIT trap below fires at *subshell* exit, after
  # this function has returned, so a function-local `dir` would be out of scope and (under
  # `set -u`) make the trap error. The caller ALWAYS runs this inside a `( … )` subshell,
  # so `dir` stays confined there and never leaks to the parent shell.
  dir=""

  # C5/correct-target: $REPO must look like owner/name before any clone or push.
  case "$repo" in
    ?*/?*) case "$repo" in */*/*) echo "$warn: REPO '$repo' is not owner/name; skipping staging" >&2; return 1 ;; esac ;;
    *)     echo "$warn: REPO '$repo' is not owner/name; skipping staging" >&2; return 1 ;;
  esac

  # C4: fresh throwaway clone dir, removed on EVERY exit path (incl. the warn/failure path).
  dir="$(mktemp -d)" || { echo "$warn: could not create a temp clone dir; skipping staging" >&2; return 1; }
  trap 'rm -rf "$dir"' EXIT

  # C1: clone over gh's credential helper — NO token in any URL, token never echoed.
  if ! stage_files__clone "$repo" "$dir" "$needs_ws"; then
    echo "$warn: could not clone '$repo' (auth/network?); stage manually per the printed instructions above" >&2
    return 1
  fi

  # C3/C14 idempotency: an already-OPEN PR on the head → reuse + skip (no duplicate PR).
  existing="$(gh pr list --repo "$repo" --head "$branch" --state open --json url --jq '.[0].url // ""' 2>/dev/null || true)"
  if [ -n "$existing" ]; then
    echo ">> stage-files: PR already open on '$branch' — reusing $existing (skipping)"
    return 0
  fi
  # C3: an existing REMOTE branch is skip/reuse — never reset-and-repush (no force).
  if git -C "$dir" ls-remote --exit-code --heads origin "$branch" >/dev/null 2>&1; then
    echo ">> stage-files: remote branch '$branch' already exists — reusing it, not repushing (skipping)"
    return 0
  fi

  # PR base = the repo's default branch (the clone is checked out on it). C5: captured into
  # a quoted var, used only as a quoted argument, never spliced into a command position.
  base="$(git -C "$dir" symbolic-ref --short HEAD 2>/dev/null || true)"
  [ -n "$base" ] || { echo "$warn: could not determine '$repo' default branch; skipping staging" >&2; return 1; }

  # C5: deterministic factory/… branch (matches the factory-naming ruleset), a fixed literal.
  if ! git -C "$dir" checkout -b "$branch" >/dev/null 2>&1; then
    echo "$warn: could not create branch '$branch'; skipping staging" >&2
    return 1
  fi

  # C6 copy-if-absent: the caller stages ONLY its file set, ONLY where the target is absent,
  # via stage_files_cp_if_absent. Existing repo-owned files are left byte-for-byte untouched.
  "$copy_fn" "$dir"

  # C6 no-diff → skip: the staged diff is authoritative (files that already existed produce
  # no diff, since copy-if-absent never overwrote them). No empty commit, no empty PR.
  git -C "$dir" add -A >/dev/null 2>&1 || true
  if git -C "$dir" diff --cached --quiet; then
    echo ">> stage-files: all files already present in '$repo' — already staged (skipping)"
    return 0
  fi

  # C5: commit message + PR title/body are fixed caller-controlled literals. Local commit
  # identity is set in the ephemeral clone only (removed on exit) so the commit never
  # depends on ambient git config.
  git -C "$dir" config user.name  "factory" >/dev/null 2>&1 || true
  git -C "$dir" config user.email "factory@users.noreply.github.com" >/dev/null 2>&1 || true
  if ! git -C "$dir" commit -m "$title" >/dev/null 2>&1; then
    echo "$warn: commit failed for '$repo'; skipping staging" >&2
    return 1
  fi

  # C3: plain push of the factory/… branch ONLY — NO --force/--force-with-lease/+refs, never
  # the default/protected branch. C1: gh's credential helper, no token in a URL.
  if ! stage_files__push "$dir" "$branch" "$needs_ws"; then
    echo "$warn: could not push branch '$branch' to '$repo'; the PR was NOT opened — stage manually per the printed instructions above" >&2
    return 1
  fi

  # C2: OPEN-ONLY. gh pr create and NOTHING else (no merge/approve/--auto). Base = default
  # branch. Labelled skip-ticket (created by the caller's labels block).
  if prurl="$(gh pr create --repo "$repo" --base "$base" --head "$branch" \
        --title "$title" \
        --body "$body" \
        --label skip-ticket 2>&1)"; then
    echo ">> stage-files: opened PR: $prurl"
  else
    echo "$warn: 'gh pr create' failed for '$repo' (branch pushed as '$branch'); open the PR manually" >&2
    printf '%s\n' "$prurl" >&2
    return 1
  fi
  return 0
}
