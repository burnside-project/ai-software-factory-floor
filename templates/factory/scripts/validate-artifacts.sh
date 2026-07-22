#!/usr/bin/env bash
# Validate delivery-artifact naming + front-matter id↔filename consistency.
# Exit non-zero on any violation (used as a CI gate). Run from a delivery repo root.
set -euo pipefail

fail=0
err(){ echo "::error::$*"; fail=1; }

fm_id(){ awk '/^---[[:space:]]*$/{n++;next} n==1 && /^id:/{sub("^id:[[:space:]]*","");print;exit}' "$1"; }

# 1. Spec directories: specs/<status>/SPEC-NNN-<slug>/
if [ -d specs ]; then
  while IFS= read -r d; do
    base="$(basename "$d")"
    [[ "$base" =~ ^SPEC-[0-9]{3}-[a-z0-9-]+$ ]] || err "spec dir not 'SPEC-NNN-<slug>': $d"
  done < <(find specs -mindepth 2 -maxdepth 2 -type d ! -name '.*')
fi

# 2. Ticket files: tickets/<state>/TICKET-NNN-<slug>.md, id matches filename
if [ -d tickets ]; then
  while IFS= read -r f; do
    base="$(basename "$f")"
    if [[ ! "$base" =~ ^TICKET-[0-9]{3}-[a-z0-9-]+\.md$ ]]; then
      err "ticket file not 'TICKET-NNN-<slug>.md': $f"; continue
    fi
    fid="$(fm_id "$f")"
    fnid="$(echo "$base" | grep -oE '^TICKET-[0-9]{3}')"
    if [ -z "$fid" ]; then err "ticket missing front-matter id: $f"
    elif [ "$fid" != "$fnid" ]; then err "front-matter id ($fid) != filename ($fnid): $f"; fi
  done < <(find tickets -name 'TICKET-*.md' -type f)
fi

# 3. Spec files: id matches dir AND the required sections are present.
# Naming alone let an empty-but-well-named spec.md pass the gate (audit finding N4);
# require the core sections so a spec has real content. Names match spec-template.md.
SPEC_SECTIONS=("## Problem" "## Goal" "## Acceptance criteria")
if [ -d specs ]; then
  while IFS= read -r f; do
    dir="$(basename "$(dirname "$f")")"
    [[ "$dir" =~ ^SPEC-[0-9]{3} ]] || continue
    sid="$(echo "$dir" | grep -oE '^SPEC-[0-9]{3}')"
    fid="$(fm_id "$f")"
    [ -n "$fid" ] && [ "$fid" != "$sid" ] && err "spec front-matter id ($fid) != dir ($sid): $f"
    for section in "${SPEC_SECTIONS[@]}"; do
      grep -qiF "$section" "$f" || err "spec missing required section '$section': $f"
    done
  done < <(find specs -name 'spec.md' -type f)
fi

if [ "$fail" -ne 0 ]; then echo "naming validation FAILED"; exit 1; fi
echo "naming validation OK"
