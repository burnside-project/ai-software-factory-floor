---
id: SPEC-XXX
type: spec
repo: <repo-name>
owner: <owner>
stage: Draft
status: Draft
---

# Spec: <feature name>

Feature ID: SPEC-XXX
Status: Draft
Author: <author>
Date: YYYY-MM-DD

<!--
FRONT-MATTER IS REQUIRED — do not delete the block above.

`templates/factory/scripts/validate-artifacts.sh` backs the `factory-naming` required
status check. For specs it asserts that the front-matter `id:` matches the directory:

  specs/<state>/SPEC-NNN-<slug>/spec.md   ->   id: SPEC-NNN

It also requires the "## Problem", "## Goal" and "## Acceptance criteria" sections
below (audit finding N4 — naming alone let an empty-but-well-named spec pass the gate).
Keep those three headings even while the spec is a stub.

Note the validator FAILS OPEN on a missing spec `id:`: a spec with no front-matter
passes silently, unlike a ticket, which fails closed. Do not rely on the gate to catch
a missing `id:` here.

This is an AUTHORING template for a delivery artifact. It is NOT a GitHub issue form;
issue forms live in `templates/issues/`. Do not add issue-form keys
(`name:`/`about:`/`labels:`/`projects:`) here.
-->

## Problem
What hurts today? Why now?

## Goal
What outcome should this achieve?

## Non-goals
What is explicitly out of scope?

## Scope for this increment
Which repos/files are affected? What must NOT be coupled to this?

## Repos affected

| Repo | Change |
|---|---|
| `<repo>` | <what changes> |

## Interfaces / contracts
APIs, CLI signatures, file formats, and event shapes this establishes or changes.

## Data impact
Schema, migration, and data-shape consequences. State "none" if there are none.

## Security / governance impact
Credentials, scopes, permissions, gates, and egress. State "none" if there are none.

## Acceptance criteria
- [ ] AC1: <specific, testable, verifiable>
- [ ] AC2: <specific, testable, verifiable>

## Test plan
- Unit / integration tests: <files>
- Local / Docker commands: <commands>
- Failure scenarios: <list>

## Documentation impact
Which docs need updating? (README, runbooks, ADRs, architecture notes)

## Rollback plan
How do we roll this back, and what is the mitigation if it breaks?

## Risks
What could go wrong, and what is the impact?

## Open questions
- Q1: <question>

## Related
- Tickets: <TICKET-NNN, ...>
- ADR: <docs/decisions/ADR-NNNN-*.md>
