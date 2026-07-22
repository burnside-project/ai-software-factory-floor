# ADR-0004: Classify slash commands delivery vs provisioning by a `provisioning/` subdirectory

Status: Accepted
Date: 2026-07-09
Deciders: Architect (via SPEC-007)
Related: SPEC-007 (`/onboard-repo` + factory-only command filter), SPEC-005 (provisioning slash
commands), SPEC-006 (`/activate-gates`), ADR-0005 (install file-ownership boundary)

## Context

The factory ships two kinds of slash command:

- **Delivery** — `feature-delivery`, `post-merge` — run *inside a delivered project* to drive its
  work.
- **Provisioning** — `onboard-project`, `check-readiness`, `activate-gates`, and now `onboard-repo`
  — run *from the `ai-software-factory` root* to orchestrate `PROVISIONING.md` and mutate org/repo
  gates. They are meaningless (and a footgun) inside a delivered project.

`bootstrap-project.sh` and `upgrade-project.sh` copied the **entire** `.claude/commands/` directory
into every delivered project (`cp -R ".claude/commands/." …`), so all provisioning commands leaked
into every project. The only guard was an in-body factory-root sentence per command (the SPEC-005
C8 mitigation) — a mitigation, not a fix. SPEC-007 replaces it with a real filter, and needs a
**durable classification rule** governing which bucket a command is in, with a stated design goal:
*adding a new command must not require editing the copy loops' logic.*

Options considered: (a) a `provisioning/` subdirectory; (b) a naming prefix; (c) an explicit
allow/deny list in the copy loops; (d) a front-matter `scope:` tag greppable by the loops.

## Decision

**Classify by file location: provisioning commands live in `.claude/commands/provisioning/`;
delivery commands stay at the top level of `.claude/commands/`. The copy loops in
`bootstrap-project.sh` and `upgrade-project.sh` ship top-level `*.md` files only.**

1. Move `onboard-project.md`, `check-readiness.md`, `activate-gates.md`, and `onboard-repo.md`
   into `.claude/commands/provisioning/`. `feature-delivery.md` and `post-merge.md` stay at the top
   level.
2. The copy loops select **top-level files only** and carry **no per-name logic**:
   ```sh
   for f in .claude/commands/*.md; do
     [ -e "$f" ] || continue     # nullglob-safe (Bash 3.2)
     cp "$f" "$PROJECT_DIR/.claude/commands/"
   done
   ```
   `agents/` remains a recursive `cp -R` (subagents are delivery-side and ship whole).
3. **Adding a command requires no copy-loop edit** — drop a `.md` at top level (delivery) or in
   `provisioning/` (provisioning). Location *is* the classification.
4. **Remove-on-upgrade:** `upgrade-project.sh`'s pre-existing `rm -rf` of the target commands dir,
   followed by the filtered rebuild, means a **previously-leaked** provisioning command is removed
   on the next upgrade. Upgraded projects converge to the clean delivery-only set.
5. The delivered `.claude/commands/` contains **exactly** `feature-delivery.md` + `post-merge.md`
   and none of the provisioning commands — asserted by a behavioral exact-set test on every install
   path (delivery pair `test -f` ×2; recursive `find -name` empty for each named provisioning
   command).

### Claude Code discovery and command namespacing (shipped outcome)

Commands in subdirectories of `.claude/commands/` are discovered by Claude Code, which **namespaces
them by subdirectory**. As shipped and verified at build time (2026-07-09), the four provisioning
commands invoke as **`/provisioning:onboard-project`, `/provisioning:check-readiness`,
`/provisioning:activate-gates`, `/provisioning:onboard-repo`**; the delivery pair
`/feature-delivery` + `/post-merge` stay top-level and unchanged. The provisioning commands are only
ever run from the factory root — where the subdirectory is present — so they remain fully usable.

The `provisioning:` prefix is a **rename** of the invocation names, and it is **accepted, not a
regression** (human decision, 2026-07-09): the namespace makes the delivery-vs-provisioning
separation visible directly in the command UI, reinforcing the filter's intent, and these commands
are new this session so the rename cost is low. The subdirectory mechanism is therefore adopted as
shipped, namespacing included.

### Fallback

The **explicit allow-list** in the copy loops (ship only `feature-delivery` + `post-merge`) remains
the documented fallback **only** for the narrow case where a future Claude Code version stops
discovering nested command directories entirely. It yields the identical delivered outcome and is
*fail-closed* (a new command does not ship unless allowed), at the cost of one loop edit per new
command. It is a fallback for *loss of discovery*, not for the namespacing — the `provisioning:`
prefix is the accepted steady state, not a trigger to switch mechanisms.

## Consequences

Positive:
- Provisioning commands (org/repo gate mutators) no longer leak into delivered projects — the
  footgun surface is removed at the source, not merely guarded in prose.
- Adding commands never touches the copy loops; classification is a file's location, visible to any
  reviewer.
- Upgraded projects self-heal, dropping previously-leaked commands.
- The in-body factory-root guards remain as defense-in-depth for not-yet-upgraded installs.
- The `provisioning:` namespace makes the delivery-vs-provisioning split visible in the command UI,
  reinforcing the filter's intent (accepted human decision, 2026-07-09).

Negative / trade-offs:
- Subdirectory namespacing **renames** the provisioning commands to `/provisioning:<name>` (e.g.
  `/provisioning:onboard-repo`). Accepted, not a regression: the grouping is desirable and the
  commands are new this session, so the rename cost is low. Any doc/UX reference to a provisioning
  command must use the namespaced form.
- An author who mistakenly drops a *new* provisioning command at the top level would leak it
  (subdirectory is not fail-closed). Mitigation: convention + review + the exact-set behavioral
  test (which, note, only names the *known* provisioning commands — a future addition relies on the
  author placing it in `provisioning/`).
- Relocating files requires updating any test/doc that referenced a provisioning command's old
  top-level path. Verified low: no script references those specific paths; only completed
  SPEC-005/006 artifacts do, and those are historical.

## Alternatives considered

- **Naming prefix (b).** Rejected: no common prefix exists across the four provisioning commands
  and it would rename the slash commands operators type — colliding with the SPEC-007 non-goal
  against renaming command content.
- **Explicit allow/deny list (c).** Allow-list is fail-closed and Bash-3.2-trivial but violates the
  stated goal (every new command edits the loop). Kept as the documented fallback (above), not the
  primary.
- **Front-matter `scope:` tag (d).** Rejected: adds a third front-matter key, breaking the
  exactly-`description`+`argument-hint` contract the commands hold and that tests diff against
  `feature-delivery.md`; ships the tag into delivered projects; and grep-parsing YAML in Bash 3.2 is
  fragile.
