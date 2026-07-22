#!/usr/bin/env bash
# Shared sync-issues library — the SINGLE implementation of the spec/ticket ->
# GitHub Issue + Project projection. Both scripts/sync-issues.sh (manual) and the
# sync-issues.yml Action (event-driven) source THIS file, mirroring how
# board-sync.yml calls scripts/board-sync.sh. Do not fork the logic.
#
#   scripts/lib/sync-issues.sh <path>          # a dir or a single .md file
#   SPEC_FILTER=SPEC-013 scripts/lib/sync-issues.sh ../../../tickets
#
# Front-matter read: id, type(epic|task), spec, repo, owner, stage, status
# Requires: gh (auth + project scope), awk, jq.
#
# Contract (SPEC-013 / 013a):
#   O1 — match an existing Issue by the "<ID>:" title prefix and UPDATE; never
#        duplicate. Pure projector: reads front-matter/filename + gh queries,
#        writes Issues/Project only. Writes NOTHING back into any .md file, runs
#        no git write verb, and adds no issue-id write-back key. (contents: read.)
#   O3 — files missing required front-matter (id) or repo are skipped with a
#        ::notice:: and the loop continues; malformed YAML never crashes; exit 0.
#   O4 — the Project Stage single-select is set ONLY on the Issue-CREATE path.
#        On re-sync of an existing Issue the idempotent add-to-Project runs every
#        time, but Stage is left untouched so board-sync.yml stays the sole owner
#        of subsequent Stage transitions (no flap).
#   C3 — front-matter is UNTRUSTED input: id is bound via jq --arg (never spliced
#        into a jq program), every gh call quotes and -- terminates file-derived
#        values, and repo is validated to an owner/name-safe shape before use.
#        No file value is ever re-executed by the shell.
set -euo pipefail

# SPEC-019 (TICKET-099): ORG/PROJECT come from the compiled .factory/factory.env, never a home
# default. Source the runtime-env helper (same lib/ dir), fill from config, then fail closed.
# shellcheck source=/dev/null
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/factory-runtime-env.sh"
factory_load_config
factory_require ORG PROJECT
PROJECT_TITLE="$PROJECT"
SPEC_FILTER="${SPEC_FILTER:-}"
ROOT="${1:-}"
[ -n "$ROOT" ] || { echo "usage: sync-issues.sh <path>" >&2; exit 1; }

fm() { # fm <file> <key> -> value from YAML front-matter (bounded: prints one line, exits)
  awk -v k="$2" '
    /^---[[:space:]]*$/ {n++; next}
    n==1 && $0 ~ "^"k":" {sub("^"k":[[:space:]]*",""); print; exit}
  ' "$1"
}

pnum=$(gh project list --owner "$ORG" --format json 2>/dev/null \
       | jq -r --arg t "$PROJECT_TITLE" 'first(.projects[]|select(.title==$t)|.number) // empty' || true)
[ -n "$pnum" ] || echo "::notice::no Project resolved (token scope?) — syncing Issues only"

[ -e "$ROOT" ] || { echo "::error::path not found: $ROOT" >&2; exit 1; }

# while-read (not a Bash-4 array-read builtin) so this runs on Bash 3.2 (stock macOS).
files=()
while IFS= read -r line; do [ -n "$line" ] && files+=("$line"); done < <(
  if [ -d "$ROOT" ]; then find "$ROOT" -name '*.md'; else echo "$ROOT"; fi)

for f in "${files[@]}"; do
  id=$(fm "$f" id)
  # O3: a file with no `id` (legacy SPEC-001..012 / non-canonical) is skipped, not
  # crashed. A ::notice:: (deliberately not an error/warn annotation) keeps
  # annotation noise off the many legacy files.
  if [ -z "$id" ]; then echo "::notice::skip $f — no 'id' in front-matter"; fi
  [ -z "$id" ] && continue
  type=$(fm "$f" type)
  spec=$(fm "$f" spec)
  repo=$(fm "$f" repo)
  stage=$(fm "$f" stage)
  stage_lc="$(printf '%s' "$stage" | tr '[:upper:]' '[:lower:]')"  # Bash 3.2: lowercase via tr
  [ -n "$SPEC_FILTER" ] && [ "$spec" != "$SPEC_FILTER" ] && continue

  # O3: no repo -> skip-with-notice, keep going.
  [ -z "$repo" ] && { echo "::notice::skip $id ($f) — no 'repo' in front-matter"; continue; }

  # C3: `repo` is untrusted. It is a BARE repo-name segment used as `$ORG/$repo`
  # (so `$ORG/$repo` is the owner/name pair). Require a safe single segment BEFORE
  # any `gh` call: no whitespace, no '/', no '..' traversal, no shell/glob
  # metacharacters — mirroring the setup-repo.sh:100-103 shape-guard style. A
  # crafted `../evil`, `a b`, `org/name/extra`, or `foo;bar` is rejected here and
  # never reaches `gh issue create --repo`.
  case "$repo" in
    *..* | *[!A-Za-z0-9._-]*)
      echo "::notice::skip $id ($f) — invalid repo '$repo' (must be a bare owner/name segment)"; continue ;;
  esac

  title="$( [ "$type" = epic ] && echo "[EPIC] " || echo "[TASK] ")$id: $(basename "$f" .md | sed 's/^[A-Z]*-[0-9]*-//; s/-/ /g')"
  label=$( [ "$type" = epic ] && echo epic || echo task )

  # C3: `id` is UNTRUSTED — bind it via jq --arg and reference $id INSIDE the
  # program (mirroring the --arg s "$stage_lc" pattern below). Never splice a file
  # value into a jq program string. `--` terminates the gh call so a leading '-'
  # in a search value is data, not a flag.
  existing=$(gh issue list --repo "$ORG/$repo" --search="$id: in:title" \
             --state all --json number,title -- \
             | jq -r --arg id "$id" 'first(.[]|select(.title|startswith($id + ":"))|.number) // empty')

  created=0
  if [ -z "$existing" ]; then
    # O1: create only when no Issue matches the "<ID>:" title prefix.
    url=$(gh issue create --repo "$ORG/$repo" --title "$title" --label "$label" \
          --body "Canonical: \`$f\` · Spec: $spec")
    created=1
    echo "created $id -> $url"
  else
    # O1: match-by-title-prefix -> update path, no duplicate, no write-back.
    url="https://github.com/$ORG/$repo/issues/$existing"
    echo "exists  $id -> $url"
  fi

  # O4: add-to-Project runs on EVERY run (idempotent membership) …
  if [ -n "$pnum" ] && [ -n "$url" ]; then
    item=$(gh project item-add "$pnum" --owner "$ORG" --url "$url" --format json | jq -r '.id')
    # … but the Stage single-select is set ONLY on the just-created branch, so a
    # re-sync never resets a card the floor motor (board-sync.yml) already moved.
    if [ "$created" = 1 ]; then
      sf=$(gh project field-list "$pnum" --owner "$ORG" --format json)
      fid=$(printf '%s' "$sf" | jq -r '.fields[]|select(.name=="Stage")|.id')
      oid=$(printf '%s' "$sf" | jq -r --arg s "$stage_lc" '.fields[]|select(.name=="Stage")|.options[]|select((.name|ascii_downcase)==$s)|.id')
      pid=$(printf '%s' "$sf" | jq -r '.fields[0].projectId? // empty')
      if [ -n "$fid" ] && [ -n "$oid" ]; then
        gh project item-edit --id "$item" --project-id "$pid" \
          --field-id "$fid" --single-select-option-id "$oid" >/dev/null 2>&1 || true
      fi
    fi
  fi
done
