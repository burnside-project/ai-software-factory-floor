# ADR-0006: Data-driven ruleset selection — a TSV manifest replaces the hard-coded switch

Status: Accepted
Date: 2026-07-09
Deciders: Architect (via SPEC-008)
Related: SPEC-008 (`--stage-files` + retire the ruleset switch), SPEC-007 (`RULESET=` override +
`reconcile-ci-checks.sh`), ADR-0001 (gate identity model), ADR-0003 (best-effort external calls)

## Context

`templates/factory/scripts/setup-repo.sh` picks which branch-ruleset JSON to POST for a target repo.
Today (`setup-repo.sh:58-63`) that pick is a hard-coded `case "${REPO##*/}"` with three literal
arms plus a greenfield `*` fallback:

```sh
case "${REPO##*/}" in
  aws-marketplace-keys)     RULESET="$HERE/ruleset.amk.json" ;;
  license-go)               RULESET="$HERE/ruleset.license-go.json" ;;
  burnside-project-pg-cdc)  RULESET="$HERE/ruleset.pg-cdc.json" ;;
  *)                        RULESET="$HERE/ruleset.json" ;;
esac
```

Two problems. (1) Adding a tailored-ruleset repo means **editing code** (a new `case` arm) rather
than editing data. (2) The variant filenames deliberately do **not** match the repo basenames
(`ruleset.amk.json` ≠ `aws-marketplace-keys`, `ruleset.pg-cdc.json` ≠ `burnside-project-pg-cdc`), so
no filename convention can replace the map without a rename churn.

SPEC-007 added the `RULESET=<path>` override (highest-precedence selector) and
`reconcile-ci-checks.sh`, and explicitly **kept** the `case` as a fallback (SPEC-007 review §7, Q6),
deferring its retirement. This is that follow-up. The switch is now redundant with a data-driven
map, but it **cannot simply be deleted**: the three pinned repos gate live `main` and must keep
resolving to their exact current ruleset (a wrong pick fail-opens or over-requires the gate).

## Decision

**Replace the `case` with a lookup against a TSV manifest `templates/factory/ruleset-map.tsv`,
keyed on the repo basename, resolved under a fixed precedence, and converted-then-retired behind a
four-outcome regression test.**

### 1. Format — TSV, not JSON

The manifest is a two-column tab-separated file at the factory bundle root:

```
# repo-basename<TAB>ruleset-file   (relative to the factory bundle root; # lines and blanks ignored)
aws-marketplace-keys	ruleset.amk.json
license-go	ruleset.license-go.json
burnside-project-pg-cdc	ruleset.pg-cdc.json
```

TSV over JSON, even though `jq` is already a script dependency:

- **The lookup stays jq-free and Bash-3.2-native.** A `while IFS=$'\t' read -r key file` loop (or a
  fixed-literal `grep`) resolves the pick with **no external process**, mirroring the script's
  existing `while IFS='|' read` labels idiom (`setup-repo.sh:20`). Selection is control flow, not
  data transformation — keeping it out of `jq` means a malformed manifest cannot make `jq` error
  under `set -e`, and the pick degrades to the safe greenfield fallback (below) rather than aborting.
- **Fail-safe degradation is simpler.** A malformed or unmatched TSV row simply does not match and
  falls through to the greenfield `ruleset.json` (report-only `evaluate`, the safe default). A
  malformed JSON manifest would require its own `jq -e` validation gate to avoid an abort.
- **It is unambiguously data.** A flat key→value map is exactly a two-column table; a JSON object is
  heavier, needs a `_comment` hack for the header (JSON has no comments — the same workaround the
  ruleset files use), and invites future logic. TSV keeps "add a repo = add a line" honest.
- **`make verify` cost is nil.** The `.tsv` is data, not a script (no `bash -n`), and needs no JSON
  validity check; the only portability requirement is that the *parser* stays Bash-3.2 (`$'\t'`,
  `read -r`, `< file` redirect — no `mapfile`).

### 2. Match key — repo basename (`${REPO##*/}`)

**The match key is the repo basename, `${REPO##*/}`** — byte-for-byte the same key the current
`case` matches on. Column 1 of the manifest holds basenames; the lookup compares `${REPO##*/}`
against column 1 by exact string equality (no case-folding, no globbing).

- **Regression parity is the priority.** Convert-then-retire (below) requires *provably identical*
  resolution before the `case` is deleted. Keying on the basename reproduces today's semantics with
  zero behavioral delta. Keying on the full `owner/name` would change the key, force the pinned
  repos' full org paths into the manifest, and introduce a **new** fail-open mode (an org rename, or
  the same repo cloned under a different org, would silently miss the map and fall to greenfield).
- **No collision exists today.** The three pinned basenames are unique across the orgs the factory
  operates. The residual hazard — two repos sharing a basename across orgs both resolving to the same
  variant — requires a maintainer to add a colliding basename row, which is caught at
  manifest-edit review (the manifest is a small curated list, currently three rows).
- **Forward-compatible escape hatch (documented, NOT built now).** If cross-org disambiguation ever
  becomes necessary, the lookup can be upgraded to a **superset**: try an exact match on the full
  `$REPO` (`owner/name`) *first*, then fall back to the basename. Existing basename rows keep working
  unchanged; a maintainer who needs to pin one org's `api` distinctly writes `some-org/api` as the
  column-1 key. This preserves the four-outcome regression proof (all current rows are basenames) and
  is a pure additive enhancement — deferred, not adopted, to keep this increment's proof trivial.

### 3. Precedence (confirmed, unchanged outcome)

1. **`RULESET=<path>` explicit override** — highest, unchanged from SPEC-007. Validated (`-f` +
   `jq -e`) exactly as today (`setup-repo.sh:52-54`).
2. **`ruleset-map.tsv` basename lookup** — the manifest pick (replaces the `case`).
3. **Greenfield `ruleset.json` fallback** — any repo not in the manifest (and any manifest read that
   fails to match) resolves here. Also the fallback if the manifest file itself is absent — a
   packaging error must not fail-open to a *tailored* pick; it degrades to the report-only greenfield
   default and the `using ruleset.json` line makes it visible.

### 4. Convert-then-retire safety (hard constraint)

The manifest is seeded with **exactly** the three current mappings, and the lookup is proven to
resolve all four current outcomes to the **byte-identical** ruleset before the `case` is deleted, in
the **same commit**. Verification is a table-driven behavioral regression test (mocked `gh`,
SPEC-002/007 tier) enumerating all four resolutions plus the override:

| Input repo (mocked `gh`) | Expected resolved file | Proof |
|---|---|---|
| `…/aws-marketplace-keys` | `ruleset.amk.json` | `using ruleset.amk.json` + captured POST body byte-identical to today's |
| `…/license-go` | `ruleset.license-go.json` | `using ruleset.license-go.json` + byte-identical POST body |
| `…/burnside-project-pg-cdc` | `ruleset.pg-cdc.json` | `using ruleset.pg-cdc.json` + byte-identical POST body |
| `…/<any-unlisted-repo>` | `ruleset.json` (greenfield) | `using ruleset.json` |
| any pinned repo with `RULESET=<temp>` | `<temp>` (override wins) | `using <override-basename>` |

Plus a **manifest-integrity** assertion: every column-2 file exists (`test -f`), and the manifest
contains exactly the three expected rows (guards against an accidental added/deleted row silently
mis-gating a live repo). Because the manifest points at the *same* variant files the `case` named,
the POST body is trivially identical — the only realistic defect is a typo in the manifest, which
the `using <basename>` line and the `test -f` check both catch. The `case` is not removed until this
test is green in the same increment (SPEC-008 AC "the `case` is gone").

### 5. Where it lives + adding a repo

The manifest lives at `templates/factory/ruleset-map.tsv`, alongside the ruleset variants and inside
`setup-repo.sh`'s `$HERE` bundle root, so column-2 paths resolve relative to `$HERE`. **Adding a
pinned repo is a two-step data edit, no code change:** (1) drop the tailored `ruleset.<x>.json` next
to the others; (2) add one `basename<TAB>ruleset.<x>.json` line to the manifest. The lookup, the
precedence, and the tests are untouched.

## Consequences

Positive:
- Onboarding a tailored-ruleset repo is a data edit (one TSV line), not a code edit — the stated goal.
- No renames, no re-onboarding of the three pinned repos, no change to `reconcile-ci-checks.sh` or
  the `RULESET=` override contract.
- The pick stays jq-free, Bash-3.2-portable, and fail-safe (degrades to the report-only greenfield
  default, never to a wrong tailored pick).

Negative / trade-offs:
- Basename keying cannot disambiguate same-named repos across orgs. Accepted for regression parity;
  the documented dual-key superset (§2) is the escape hatch if that ever bites.
- A second data file to keep in sync with the variant JSONs. Mitigated by the manifest-integrity
  test (`test -f` every referenced file) failing CI on a dangling row.

## Alternatives considered

- **JSON manifest.** Rejected as the format: needs `jq` in the selection control-flow (a new
  fail-under-`set -e` surface), a `_comment` hack for the header, and gives no benefit over a flat
  two-column table. `jq` stays for the ruleset *payload* transform, not the *pick*.
- **(b) Rename variants to `ruleset.<basename>.json` + a filename convention.** Rejected: forces
  `ruleset.amk.json` → `ruleset.aws-marketplace-keys.json` etc. and touches every reference — churn
  with no data-driven benefit.
- **(c) Require `RULESET=`/reconciliation always (drop the default map).** Rejected: removes the
  zero-config onboarding the three pinned repos rely on and forces a reconcile step for repos that
  already have a correct file — an ergonomics regression.
- **Keep the `case`.** Rejected: it is the exact code-not-data coupling this ADR removes, and
  SPEC-007 kept it only as an interim fallback pending this follow-up.
