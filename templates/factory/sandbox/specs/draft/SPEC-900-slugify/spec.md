---
id: SPEC-900
type: spec
status: draft
---

# Spec: Slugify utility

Feature ID: SPEC-900
Status: Draft

> Sandbox fixture for the floor-motor T7 smoke test (`SMOKE-TEST-floor-motor.md`).
> A deliberately tiny, deterministic, language-neutral feature — enough to exercise the
> motor end to end without real complexity. Not a real product feature.

## Problem

Code that turns human strings into URL/file-safe identifiers keeps reinventing the same
ad-hoc lowercasing + character-stripping, with subtle disagreements (double hyphens,
trailing separators). We want one small, well-specified helper.

## Goal

A pure `slugify(input) -> string` function that maps an arbitrary string to a lowercase,
hyphen-separated ASCII slug, with no external dependencies.

## Non-goals

- Unicode transliteration (accented letters, non-Latin scripts) — out of scope.
- Configurable separators or max length.

## User stories

- As a developer, I want `slugify("Hello World")` to return `hello-world` so I can build
  clean URLs/filenames without hand-rolling string cleanup.

## Scope for this increment

One function + its unit test. No CLI, no packaging beyond the repo's normal layout.

## Interfaces / contracts

`slugify(s: string) -> string`, defined by these rules, applied in order:
1. lowercase the input;
2. replace every run of non-alphanumeric characters (`[^a-z0-9]+`) with a single `-`;
3. strip leading and trailing `-`.

## Acceptance criteria

- [ ] `slugify("Hello World")` == `"hello-world"`
- [ ] `slugify("  Trim  Me  ")` == `"trim-me"`
- [ ] `slugify("Foo_Bar 123")` == `"foo-bar-123"`
- [ ] `slugify("A  &  B")` == `"a-b"`  (runs collapse to one hyphen)
- [ ] `slugify("--edge--")` == `"edge"`  (leading/trailing separators stripped)
- [ ] `slugify("")` == `""`
- [ ] A unit test covers every example above and is green under `make verify`.

## Docker test plan

`make verify` (the sandbox repo's test target runs the slugify unit test).

## Documentation impact

A one-line usage note next to the function; no user-facing docs.

## Rollback plan

Revert the PR — the function is additive and imported nowhere else.

## Risks

Minimal. The only ambiguity (diacritics) is explicitly a non-goal.

## Open questions

None — this is a closed, example-driven spec by design.
