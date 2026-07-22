# ADR-0013: One board path, the Stage vocabulary as data, and no second upgrade verb

Status: Accepted
Date: 2026-07-18
Deciders: Architect (Phase 2) + Security Architect (Phase 3), via SPEC-016
Related: SPEC-016 (GitHub as factory floor), SPEC-014 (factory conveyor belt — **superseded**
by SPEC-016), SPEC-013b (`provision.sh` orchestrator), ADR-0012 (provisioning automation —
§(c) applied and §(d) **reaffirmed**, not superseded), ADR-0006 (data-driven ruleset selection
— the precedent this ADR follows for `stage-map.tsv`), ADR-0005 (install file-ownership
boundary — its "Alternatives considered" rejection of a standalone upgrade script is
**reaffirmed**), ADR-0002 (autonomous floor motor), ADR-0001 (gate identity model).


## Context

A "template pack" was drafted proposing a second Projects v2 provisioning path, a second label
path, a dedicated GitHub-side upgrade script, and a `gate:*` enforcement workflow. Reviewing it
against the shipped factory surfaced that most of it duplicated working machinery, and that the
duplication was not benign — the two label paths had already produced observable drift. None of
the pack's duplicate paths were adopted onto the SPEC-016 integration base; this ADR records
*why* they were declined, so the same shapes are not re-proposed.

Four things were true at the same time, and each forces a decision worth recording:

1. **Two board paths and two label paths were on the table.** `setup-project.sh` provisions the
   org Project; `setup-repo.sh` provisions labels. The pack added `scripts/project-setup.sh` and
   `scripts/label-setup.sh` alongside them. The label duplication had already drifted:
   `setup-repo.sh` used `gh label create --force` (overwrite) while `label-setup.sh` skipped
   existing labels, so **`stage:spec`'s colour depended on which script ran first**. That is a
   provisioning result that varies by invocation order — the exact failure mode ADR-0012 §(c)'s
   "one owner per concern" rule exists to prevent.

2. **The Stage vocabulary existed in five copies in three shapes.** `setup-project.sh`,
   `board-sync.sh`, `metrics.sh`, `setup-repo.sh` and `PROJECTS.md` each carried their own
   spelling of the option list, held in step only by a source comment reading "must match
   setup-project.sh". It had already drifted: `PROJECTS.md` documented a *different,
   seven-option* vocabulary. A comment is not a contract.

3. **A dedicated GitHub-side upgrade script was drafted** on the premise that upgrade was "a true
   gap with no precedent to copy". It was not a gap. `provision.sh --upgrade` had been the
   GitHub-side upgrade leg since SPEC-013b, named deliberately in ADR-0012 §(d), and covered by a
   tested orchestrator (`tests/factory/provision-dry-run.sh`, 96 assertions).

4. **A `gate:*` enforcement workflow was drafted** that could not enforce anything, in a repo
   whose established posture is report-only-before-active.

## Decision

### (a) One board path, one label path

**`setup-project.sh` is the single Projects v2 provisioning path. `setup-repo.sh` is the single
label path.** `scripts/project-setup.sh` and `scripts/label-setup.sh` are declined; neither is
adopted.

`project-setup.sh` was never functional. It invoked `gh project create --repo`/`--body` and
`gh project list --repo --json` — **none of these are real flags** — and its failures were
swallowed by `>/dev/null 2>&1`, so a script that could never succeed reported success. Declining
it removes no capability because it had none.

`label-setup.sh` did work, which is why it was the more dangerous of the two: it produced the
order-dependent `stage:spec` colour above. One owner per concern, idempotency delegated downward
(ADR-0012 §(c)).

### (a2) The board stays ORG-level, not repo-level

Repo-level scoping is superficially attractive: it would drop the `PROJECTS_TOKEN` requirement,
since a repo-scoped project is reachable with the workflow's own `GITHUB_TOKEN`. **Rejected**, and
the justification is mechanical rather than aesthetic:

`templates/factory/scripts/lib/sync-issues.sh` resolves *one org project* (`gh project list
--owner "$ORG"`, matched by `PROJECT_TITLE`) and then projects issues from *many* repos onto it,
driven by each artifact's **`repo:` front-matter key** — an artifact with no `repo:` is skipped
with a notice, and an artifact's `repo:` names where its issue lives. `metrics.sh` and
`board-sync.sh` resolve the project the same way. A host-repo-authored ticket whose `repo:` names
a *different* repo is a meaningful board item today and **meaningless on a repo-scoped board**.

So going repo-level is not a board setting. It is a **rewrite of the projection contract** that
`sync-issues.sh`, `metrics.sh` and `board-sync.sh` all depend on, and it would delete the
cross-repo roll-up that is the board's reason to exist. The `PROJECTS_TOKEN` cost is real, small,
already paid, and fails soft everywhere it is consumed (`sync-issues.sh` emits a `::notice::` and
syncs Issues only when no project resolves).

### (b) The Stage vocabulary is DATA, not convention — `stage-map.tsv`

The vocabulary lives in **`templates/factory/stage-map.tsv`**, consumed by `setup-project.sh`,
`board-sync.sh`, `metrics.sh` and `setup-repo.sh`. This follows **ADR-0006** exactly: the same
argument that replaced the hard-coded ruleset `case` with `ruleset-map.tsv` applies unchanged
here — adding a Stage should be a data edit, not four coordinated code edits held together by a
comment. TSV for the same reasons ADR-0006 gives (jq-free, Bash-3.2-native, fail-safe, and
unambiguously a small table).

Two properties of the contract must be recorded, because both have already been stated wrongly:

**The options are byte-identical to the pre-change vocabulary.** This is a convert-then-retire
change (ADR-0006 §4), not a redesign. No board is re-optioned; no card moves. Renaming a
Projects v2 option does not migrate existing cards, so order and spelling are load-bearing.

**The contract is directional, not bijective.** Every `stage:*` label maps to exactly one Stage
option, and two labels may share one option (`stage:spec`/`stage:spec-review` → `Spec`;
`stage:verify`/`stage:audit` → `Verify`). The converse does not hold: four options — **`Brief`,
`Tickets`, `Deploy`, `Observe`** — have **no label and are recorded as INTENTIONALLY UNMAPPED**
(column 1 is `-`). They are positions on the line set by means other than label sync: pre-spec
intake, the tech-lead breakdown step, `deploy.yml` environment progression, and post-deploy
observation. SPEC-016's AC5 as originally drafted asserted a bijection that never held; the
unmapped four are the counterexample and are written down so a future maintainer does not "fix"
the gap by inventing four labels nothing writes.

The residual hazard the data file does *not* remove: a Stage option added to the TSV without a
corresponding `board-sync.sh` arm silently stops moving cards (`board-sync.sh` exits 0 on a label
it cannot map — deliberately, but quietly). The mitigation is that the TSV is now the single place
to look, plus a contract note in the file itself.

**Board field names are a partially reserved namespace, and collisions are FATAL, not
degrading.** A `Type` field was proposed and created via `gh project field-create --name "Type"`.
`Type` is a **reserved Projects v2 field name** and the API rejects it; the field is named
**`Work Type`**. The failure mode is what makes this ADR-worthy: under `set -euo pipefail` the
rejected call aborted `setup-project.sh` *before* the subsequent `Priority` field was created,
and because `provision.sh` treats `setup-project.sh` as a HARD step, the whole provisioning run
hard-failed. A cosmetic field-name choice took down provisioning. **Therefore: any future board
field addition must be smoke-tested against a throwaway board before it reaches a provisioning
path.** The reserved set is undocumented, so it cannot be checked by reading.


### (b2) Authoring templates are not issue templates

`templates/specs/` and `templates/tickets/` are **authoring** templates, governed by
`validate-artifacts.sh`. `templates/issues/` are **GitHub issue** templates, governed by GitHub's
own schema. These are two different contracts that happen to share the word "template", and
`bootstrap-project.sh` copied both through one code path — the **root cause** of the
`factory-naming` regression, not merely its location.

The fan-out hazard is what made landing the fix urgent rather than merely correct: ADR-0005's
copy-if-absent primitive means a wrong template, once seeded into a target repo, is **never
overwritten by a later upgrade**. Copy-if-absent makes bad seeds sticky. A template defect is
therefore time-sensitive in a way that a script defect is not.


### (c) No new upgrade verb — `provision.sh --upgrade` is the GitHub-side upgrade path

**This decision REAFFIRMS ADR-0005 and ADR-0012 §(d). It does not contradict or supersede
either.**

`provision.sh --upgrade` already implements the GitHub-side upgrade leg: `gh repo view` existence
check → `upgrade-project.sh` for the `.ai/` filesystem leg → idempotent `setup-project.sh` →
`setup-repo.sh`. ADR-0012 §(d) named this deliberately. Once additional board fields land in
`setup-project.sh`, `provision.sh --upgrade` delivers them to every already-provisioned repo with
**zero new script**, because the orchestrator delegates idempotency downward and the sub-script is
where the change lives.

A dedicated GitHub-side upgrade script with its own `--dry-run`/`--apply` was drafted
(TICKET-072, TICKET-073) and **REJECTED**. It re-proposed two interfaces that prior ADRs had
already declined:

- **ADR-0005**, "Alternatives considered", rejected a standalone `upgrade-existing` script as
  "needless surface" — one install entry point, mode flags rather than new verbs.
- **ADR-0012 §(d)** rejected giving sub-scripts their own `--dry-run`, "as out of scope and
  higher-risk", because gating all delegation at the orchestrator is a simpler, provable
  zero-mutation contract.

Landing it would have been a silent contract break: a second upgrade entry point is precisely the
drift both ADRs exist to prevent.

#### Why the mistake was made — the part worth reading

This is recorded because the error was *reasonable*, and a reasonable error will recur.

**`upgrade-project.sh`, read in isolation, looks like the whole upgrade path.** Its name says
upgrade; it is the only script with "upgrade" in its name; and it plainly does not touch GitHub.
An author who reads it and stops there correctly concludes that GitHub-side upgrade is missing —
and then writes the missing half.

The conclusion is wrong because `upgrade-project.sh` is **only the local-filesystem leg**, invoked
*by* `provision.sh --upgrade`. The upgrade path is not the script named after it; it is the
orchestrator that calls it. The gap was already closed, one level up, under a different name.

**The boundary that does stay** — and which explains why two scripts exist at all:

| Leg | Script | Touches | Credential | Risk |
|---|---|---|---|---|
| Local filesystem | `upgrade-project.sh` | `.ai/` bundle in a checkout | none (offline) | low |
| GitHub | `provision.sh --upgrade` | org project, labels, rulesets | `gh` auth, `PROJECTS_TOKEN` | higher |

Different credentials, different blast radius. That is **one leg too few to invent, not one too
many**. The lesson for the next reader: before concluding a capability is missing, grep for its
*callers*, not its name.

**Dry-run ergonomics convention** (three conventions were in use across four scripts; this is the
rule going forward): *orchestrators default to apply with `--dry-run`; one-shot bootstrap verbs
default to dry-run with `--apply`; leaf scripts have neither.*

The additive-only, never-destructive property still matters, but it belongs to
`setup-project.sh` and `setup-repo.sh` — those are what actually mutate on upgrade.

**Corollary — ship-then-verify earns its cost here.** The reserved-`Type`-field defect in §(b)
was found by running the provisioning path against a live board. Review, `shellcheck`, and the
hermetic dry-run tests all passed over the same code and all missed it, because the failure lives
in an undocumented remote API constraint that no local artifact encodes. That is a *class* of
defect, not a one-off: anything whose contract is held by GitHub rather than by this repo is
invisible to hermetic testing. It reinforces this ADR's own posture — prefer one orchestrator
that is actually exercised end-to-end over additional scripts that are only reasoned about.

### (d) No machine enforcement of `gate:*` labels

`gate-enforcer.yml` is **dropped**, and **after SPEC-016 there is no machine enforcement of
`gate:*` labels at all.** That sentence is the decision; it is stated plainly because the
alternative — leaving the impression that something still checks — is worse than the absence.

Dropping it weakens nothing real, because it was **fail-open four ways**:

1. Skippable via its own `if:` condition.
2. Never registered as a required status check, so a red run blocked no merge.
3. It verified **self-applied labels** — the actor being gated applies the label being checked.
4. It called `gh pr view --labels`, which is not a valid flag, so it **errored on the first gate
   whenever it ran at all**.

A control with four independent fail-open paths, one of which is unconditional, is not a control.

Gate state is surfaced by reporting only. Reporting is **not enforcement**, and this ADR makes no
claim that any dashboard covers the enforcer's intent. An earlier draft asserted such coverage;
that claim is **withdrawn** as overstating what ships.

**Provisioning therefore creates no `gate:*` labels.** Creating labels for a control that does not
exist is worse than their absence: labels are read as evidence of a mechanism, and the
*appearance* of gate coverage must not survive the enforcer that failed to provide it.

One exception, which is not an exception to the rule but a different thing wearing a similar name:
**`gate:blocked` remains** — provisioned by `setup-repo.sh` and written by `deepseek audit.yml`. It
is a **motor status signal**, not a gate control. It reports that the motor stopped; it gates
nothing.


### (e) DEFERRED: the `gate-auto-transition.yml` × `deepseek audit.yml` collision

Both workflows write `stage:*` labels on `issues: labeled`. This is a real collision and it is
**deferred, not solved.** It is recorded here with its cost so the next maintainer understands why
nothing shipped, not merely that nothing did.

**The collision model must be stated correctly**, because the initial framing was wrong in two
ways. Architecture review found that `deepseek audit.yml` **does** have a concurrency guard
(`group: deepseek audit-<issue-number>`, `cancel-in-progress: false`), and that the motor's `stage:*`
writes are mostly performed **by Claude inside a phase**, not by workflow-level steps. Both facts
constrain the fix.

**The real hazard** is not a stale board card. `gate-auto-transition.yml` fires on
`issues: labeled` with **no concurrency group at all** and adds `stage:code` mid-phase, which
**re-triggers `deepseek audit.yml` into a second motor run**. On a $0 Actions budget with a single
self-hosted runner, that is a *cost and queue* event, not merely a display inconsistency.

Candidate shapes, with why each is not yet actionable:

- **Single arbiter workflow as the sole writer of `stage:*`.** Preferred shape. Requires
  `deepseek audit.yml` to emit transition *intents* rather than labels — which means changing the
  motor, and SPEC-016 holds "motor untouched" as a non-goal. An arbiter cannot be introduced
  without that change, because the writes it must arbitrate originate inside Claude prompts.
- **Shared concurrency group.** **Rejected.** Joining `deepseek audit-<issue>`
  (`cancel-in-progress: false`, 45-minute ceiling) head-of-line-blocks a single self-hosted
  runner for up to 45 minutes behind an unrelated gate transition.
- **Gates advisory-only.** A non-answer: it restates the deferral as a design.

`gate:blocked` is the one exception, and it is a **motor status signal** rather than a gate
control (see §(d)).

**Recommendation: this gets its own thin spec**, explicitly permitted to change the motor. It is
small, well-understood, and blocked only by a non-goal that belongs to a different spec. SPEC-016
AC13 bars any retained workflow from writing `stage:*` precisely to keep the problem from growing
while it waits.

**The follow-on spec's input already exists.** Four SPEC-014 tickets are `stage:*` writers or
their integration test and are deliberately **left in `tickets/ready/`** rather than retired —
see §(j). Retiring them would have deleted the requirements for the very spec this section
recommends.


### (f) Script injection is the top security finding, and the control is durable

Recorded as an **invariant, not a patch**: **no workflow interpolates `${{ github.event.* }}`
inside a `run:` block.** Untrusted event fields reach a shell only through `env:` bindings.
Enforced by a test that runs over **committed** workflows as well as templates — a template-only
test would leave the live attack surface unchecked.

**Why `deepseek audit.yml` was brought in scope despite the "motor untouched" non-goal:** the
non-goal protects phase **behaviour** — what Claude and DeepSeek do inside a phase — not the
file's **security posture**. The motor is the highest-privilege workflow in the repo
(`contents`/`pull-requests`/`issues` write, plus Claude and DeepSeek credentials), so exempting it
from the injection invariant would exempt the one file where injection matters most.

**The amplifier that made it urgent:** an unscoped token may carry `checks`/`statuses: write` —
enough to **forge the `factory-naming` and `independent-audit` contexts that ADR-0001 relies on**.
That is gate forgery, not merely token theft: an attacker who can write statuses can make an
unreviewed change present as gated.

**The invariant's scope is `run:` blocks, and that boundary is deliberate.** As landed,
`tests/factory/test-workflow-injection.sh` enforces it across every committed workflow and
template. `deepseek audit.yml`'s one genuine shell sink (`:137`) is converted. Its four
`with: prompt:` interpolations are **NOT** converted, and this is not an oversight:

1. `claude-code-action` performs no shell expansion on `prompt`, so an `env:` binding would
   deliver the literal seven characters `$ISSUE_TITLE` to the model instead of the title —
   breaking behaviour, which the non-goal above genuinely does protect.
2. The security benefit would be zero. Those lines are a **prompt**-injection surface, not a
   shell-injection one. `env:` indirection is a control for *shell parse context*; the
   attacker's text reaches the model identically either way.

An earlier instruction on this work directed converting all five sites. That instruction was
wrong, and the distinction matters more than the fix: **applying a shell-injection control to a
prompt-injection surface produces the appearance of coverage with none of the substance** — the
precise failure this ADR objects to elsewhere (§d, gate labels for a control that does not exist).
Prompt injection into the motor is a real and unresolved exposure; it needs a different control
(author-association gating on the triggering label write, or delimiting untrusted text inside the
prompt) and belongs to the follow-on spec in §(e), not here.

### (g) The `permissions:` floor

Two controls, addressing two different populations:

- **Per-workflow least-privilege `permissions:` blocks** — the fix for what ships.
- **`default_workflow_permissions=read` at the repo/org level** — the fix for what does *not*
  ship, because with no `permissions:` key at any level the inherited scope is **externally
  controlled** (a repo or org setting outside this repo's files).

Recorded explicitly: this gap was **pre-existing and repo-wide**, not introduced by the template
pack. `ci.yml`, `deploy.yml`, `pr-lint.yml` and `factory-naming.yml` are all committed and also
lacked `permissions:` blocks. An earlier draft attributed the gap to the pack; that attribution
was wrong and would have misdirected the fix at the pack alone.


### (h) The authoring templates were never validator-conforming

The committed `ticket-template.md` was **prose with no front-matter** and never carried `id:`. The
template pack replaced one non-conforming template with a differently non-conforming one. Neither
version would have produced an artifact that `validate-artifacts.sh` accepts.

**The lesson: test a template's OUTPUT, not its keys.** A test asserting "the template contains an
`id:` key" passes for a template that emits an unusable artifact. The test that matters
instantiates the template and runs the validator over the result.

The **42 pre-existing `validate-artifacts.sh` errors** are recorded as a known, quantified backlog
with an explicit fix-or-accept decision (accept, with two tripwires) in the "Known backlog"
section of `docs/delivery-ledger.md`, rather than left as ambient noise. A validator with 42
standing errors trains its readers to ignore it; the count is written down so growth is
detectable, and any *new* artifact joining the list means the guard has failed.


### (i) No rotation procedure exists

There is **no documented rotation procedure for `PROJECTS_TOKEN` or `deepseek audit key`** anywhere
in the repo. This is **out of scope for SPEC-016** and is recorded here for one reason: so the
absence is not mistaken for coverage by a future reader who sees a credential table and assumes
lifecycle is handled. Documenting a secret's *purpose* is not documenting its *lifecycle*.

### (j) SPEC-014's open tickets: only two are superseded

SPEC-014 is retired (see Consequences), but retiring a spec does **not** retire its tickets by
default. All nine were triaged individually; **seven stay in `tickets/ready/`.** The triage is
recorded here because the default assumption — "the spec is superseded, so the tickets are" —
was checked and found **wrong**, and re-deriving it is expensive.

| Ticket | Disposition | Reason |
|---|---|---|
| TICKET-049 `spec-gate-approved.yml` | **Stays ready** | Writes `stage:code`. Input to the deferred gate-transition spec (§e). |
| TICKET-050 `pr-merged.yml` | **Stays ready** | Writes `stage:done`. Input to the deferred spec (§e). |
| TICKET-051 `post-merge.yml` | **Stays ready** | Live and uncovered by SPEC-014 or SPEC-016. |
| TICKET-052 `wip-guard.yml` | **Stays ready** | Per-stage WIP cap; reads/acts on `stage:*`. Input to the deferred spec (§e). |
| TICKET-053 `main.yml` rename + runner tag | **SUPERSEDED** | Overtaken by the `vars.RUNNER_LABELS` runner migration and SPEC-016 AC9's workflow-header/permissions contract. |
| TICKET-054 ACTIVATE.md conveyor-belt diagram | **SUPERSEDED** | Replaced by `docs/board-and-gates.md` (TICKET-074). |
| TICKET-055 conveyor-belt integration test | **Stays ready** | Tests the 049/050/052 relay; belongs with them to the deferred spec (§e). |
| TICKET-056 `change-log.yml` | **Stays ready** | Live and uncovered by either spec. |
| TICKET-057 agent consolidation 13→10 | **Stays ready** | Fully orthogonal to both specs; independently shippable. |

Two facts apply to **all nine** and must be resolved before any of them is actionable:

1. **None carries a `repo:` front-matter key.** Per §(a2) that key is what drives board
   projection, so none of them can project onto the board correctly regardless of owner —
   `sync-issues.sh` skips them with a notice.
2. **All nine target `burnside-project-marketing-site`**, SPEC-014's original subject repo. Even
   the live ones need re-scoping to `ai-software-factory` (or to an explicit target) before they
   describe work anyone can pick up.


## Consequences

Positive:

- Provisioning results no longer depend on invocation order — one owner per concern removes the
  `stage:spec` colour drift at its source rather than by reconciling two writers.
- Adding a Stage is a one-line data edit (ADR-0006's benefit, extended to the board contract), and
  the five-copy drift cannot recur because there is one copy.
- The upgrade path stays a single verb. Board features reach every already-provisioned repo
  through `provision.sh --upgrade` with no new script, no new credential, and no new test surface.
- The injection invariant is enforced by a test over committed workflows, so it is a standing
  property rather than a one-time cleanup.
- Removing a fail-open enforcer and *declining to provision its labels* leaves the security
  posture honestly represented. Nothing now implies a gate control that does not exist.
- **SPEC-014 is retired without losing its live work.** SPEC-014
  (`specs/completed/SPEC-014-factory-conveyor-belt/`) is superseded by SPEC-016 because it was
  written against a *different target repo* (`burnside-project-marketing-site`) rather than as a
  factory capability — its conveyor-belt hand-offs are absorbed here as capabilities the factory
  provisions. Seven of its nine tickets remain live (§j).

Negative / trade-offs:

- **There is no machine enforcement of `gate:*` labels.** This is a real reduction in *apparent*
  coverage, though not in actual coverage — see §(d). If gate enforcement is wanted, it must be
  built, and it must be a required status check verifying something the gated actor cannot
  self-apply. Anything less reproduces the enforcer.
- **The `gate-auto-transition` × `deepseek audit` collision remains open**, including its
  double-motor-run cost on a $0 Actions budget. Deferring it is a considered trade, not an
  oversight (§e) — and it leaves four tickets parked in `tickets/ready/` that no current spec
  owns (§j). Parked-but-visible is the deliberate choice over retired-and-forgotten.
- The Stage contract is data, but nothing yet *proves* every TSV option has a `board-sync.sh` arm.
  The failure mode (a card silently stops moving) is quiet. A conformance test is the obvious
  follow-up.
- `stage-map.tsv` is a second data file to keep in sync with its consumers — the same trade
  ADR-0006 accepted for `ruleset-map.tsv`, with the same mitigation (test the referenced targets
  exist).
- Board field additions now carry a mandatory live smoke-test step (§b). That is friction on a
  path that is otherwise offline-testable, accepted because the failure it prevents is a hard
  provisioning abort rather than a degraded board.

**Binding constraint on future authors:** this ADR **does not supersede ADR-0005 or ADR-0012 §(d)**
— it reaffirms both. If a future author revives a standalone GitHub-side upgrade script, **that ADR
must explicitly supersede ADR-0005 and ADR-0012 §(d) by name.** Silently adding a second upgrade
entry point is exactly the drift all three ADRs now exist to prevent.

## Alternatives considered

- **Keep both board/label paths and reconcile their behaviour.** Rejected: reconciling two writers
  preserves the condition that produced the drift. One of the two could not work at all (§a).
- **Move the board to repo level to drop `PROJECTS_TOKEN`.** Rejected: it is a rewrite of the
  `repo:`-keyed projection contract shared by `sync-issues.sh`, `metrics.sh` and `board-sync.sh`,
  and it deletes the cross-repo roll-up (§a2).
- **Keep the Stage vocabulary as a convention plus a "must match" comment.** Rejected: that is the
  arrangement that produced five copies in three shapes with `PROJECTS.md` already carrying a
  different seven-option list (§b).
- **A dedicated GitHub-side upgrade script with `--dry-run`/`--apply`** (TICKET-072/073). Rejected:
  ADR-0005 already declined a standalone upgrade script and ADR-0012 §(d) already declined
  sub-script dry-run. `provision.sh --upgrade` is the path (§c).
- **Fix `gate-enforcer.yml` instead of dropping it.** Rejected for this increment: making it a real
  control means a required status check verifying a signal the gated actor cannot self-apply —
  a design problem, not a bug fix, and entangled with the deferred collision (§d, §e).
- **Ship a shared concurrency group as an interim fix for the collision.** Rejected: it
  head-of-line-blocks the single self-hosted runner for up to 45 minutes (§e).
- **Ship gate enforcement in active mode.** Rejected as inconsistent with the repo's
  evaluate-before-active posture: rulesets are provisioned report-only first and flipped after
  observation. A control's first appearance should not be its enforcing appearance.
- **Retire all nine SPEC-014 tickets along with the spec.** Rejected on inspection: only two are
  actually superseded, and four of the remainder are the input to the follow-on spec §(e)
  recommends. Bulk-retiring them would have deleted that spec's requirements (§j).
