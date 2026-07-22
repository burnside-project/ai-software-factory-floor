---
id: TICKET-XXX
type: task
spec: SPEC-XXX
repo: <repo-name>
owner: <owner>
stage: Ready
status: Ready
estimate: <n> day
---

# Ticket: <title>

Ticket ID: TICKET-XXX
Spec: SPEC-XXX
Status: Ready
Estimate: <n> day

<!--
FRONT-MATTER IS REQUIRED — do not delete the block above.

`templates/factory/scripts/validate-artifacts.sh` backs the `factory-naming` required
status check in every repo the factory provisions. It reads the YAML front-matter
`id:` and fails the check when it is missing or does not match the filename:

  tickets/<state>/TICKET-NNN-<slug>.md   ->   id: TICKET-NNN

`lib/sync-issues.sh` also keys on `id:` and `repo:` to project this file onto a GitHub
Issue and the org Project board. Without them the file is skipped silently — no Issue,
no board card, and no error to tell you why.

This is an AUTHORING template for a delivery artifact. It is NOT a GitHub issue form;
issue forms live in `templates/issues/`. Do not add issue-form keys
(`name:`/`about:`/`labels:`/`projects:`) here — they render as YAML noise in the issue
body and displace the keys the gate actually requires.
-->

## User story
As a <role>, I want <goal> so that <benefit>.

## Task
What needs to be built? Be specific about files, functions, and data structures.

## Repo
<repo-name>

## Files likely touched
- `<path>`

## Dependencies
- Blocked by: <TICKET-NNN, or none>
- Blocks: <TICKET-NNN, or nothing>

## Implementation notes
Constraints, gotchas, and anything the implementer should not have to rediscover.

## Acceptance criteria
- [ ] AC1: <specific, testable, verifiable>
- [ ] AC2: <specific, testable, verifiable>

## Verification command
```bash
# the exact command(s) that prove the ACs
```

## Definition of done
- [ ] Implements only this ticket
- [ ] Acceptance criteria pass
- [ ] Tests updated where behaviour changed
- [ ] Docs updated where behaviour changed
- [ ] Test evidence recorded (e.g. `verification/results/TICKET-XXX.md`)
