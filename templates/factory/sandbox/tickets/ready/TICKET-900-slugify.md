---
id: TICKET-900
type: task
spec: SPEC-900
repo: <your-sandbox-repo>
owner: backend-engineer
stage: ticket
status: ready
---

# Ticket: Implement slugify utility

Ticket ID: TICKET-900
Spec: SPEC-900
Status: Ready
Estimate: 0.5 days

> Sandbox fixture for the floor-motor T7 smoke test. Set `repo:` in the front-matter to
> your sandbox repo before syncing it to an issue.

## User story

As a developer, I want a `slugify(string)` helper so that I can turn human text into
lowercase, hyphen-separated ASCII slugs without hand-rolling string cleanup.

## Task

Add a single pure `slugify` function per SPEC-900, plus a unit test covering the spec's
acceptance examples. One shippable slice — no CLI, no extra scope.

## Repo

`<your-sandbox-repo>`

## Files likely touched

- the repo's utility/string module (language of the sandbox repo)
- its unit-test file

## Dependencies

- Blocked by: none
- Blocks: none

## Implementation notes

Implement in the sandbox repo's own stack. Apply the SPEC-900 rules exactly and in order:
lowercase → collapse `[^a-z0-9]+` runs to a single `-` → strip leading/trailing `-`.
No external dependencies. Wire the test into `make verify` (or the repo's `test-local`).

## Acceptance criteria

- [ ] `slugify` returns the exact outputs for all six SPEC-900 examples.
- [ ] A unit test asserts each example and passes under `make verify`.
- [ ] No scope beyond this function + its test.

## Verification command

```bash
make verify
```

## Definition of done

- [ ] Code implements only this ticket (no extra scope)
- [ ] Acceptance criteria pass
- [ ] Tests added and green
- [ ] Docs updated if behavior changed (a usage note by the function)
- [ ] Spec updated if behavior diverged from spec
