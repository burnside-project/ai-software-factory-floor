---
id: SPEC-901
type: epic
status: brief
---

# Feature Request: Secure random token generator

> Sandbox fixture for the floor-motor **upstream** (`stage:spec`) smoke test
> (`../SMOKE-TEST-floor-motor.md`, Test 6). This is a raw **idea**, not a spec — the
> motor's job is to turn it into a spec + architecture/security reviews + tickets + a
> test plan and stop at the spec gate. Deliberately small, with one real security angle
> so the security-review phase has something to say. **Not a product feature.**

File this as an **epic issue**, then add `stage:spec` to watch the upstream motor run.

## Problem

We keep hand-rolling short random identifiers (invite codes, idempotency keys) with
whatever RNG is handy — often a non-cryptographic one — which is a quiet security bug.
We want one small, correct helper.

## Affected user

Developers who need an unguessable short token and shouldn't have to think about RNG choice.

## First useful version

A pure function `token(n)` that returns an `n`-character string drawn from `[A-Za-z0-9]`.
That's it — no encoding options, no prefixes.

## Explicit non-goals

- UUIDs / standard formats (that's a different helper).
- Configurable alphabets or length policies.
- Persistence, uniqueness guarantees across calls, or a CLI.

## Expected interface

`token(n: int) -> string` — length exactly `n`, characters from `[A-Za-z0-9]`.
Decide behavior for `n <= 0` during spec (this is a real open question for the PM/architect).

## Example usage

```
token(8)   -> e.g. "a9Kf2ZqR"   (8 chars, alphanumeric)
token(16)  -> a 16-char alphanumeric string
```

## Data impact

None — pure function, no storage, no I/O.

## Security / governance impact

**The core requirement:** the token must be **unguessable** — generated from a
cryptographically secure RNG (the CSPRNG for the sandbox repo's stack), never a
general-purpose PRNG. The security-review phase should nail down the exact RNG, and flag
modulo-bias in the character mapping. This is the one substantive review point.

## How we'll prove it works

Unit tests: correct length, charset ⊆ `[A-Za-z0-9]`, and a basic sanity check that
repeated calls differ. `make verify` runs them.

## Definition of done

- [ ] A spec (`SPEC-901`) with Problem / Goal / Acceptance criteria, plus architecture +
      security reviews and a test plan.
- [ ] Small tickets under `tickets/ready/`.
- [ ] The spec gate returns a verdict — and a human approves it (the motor must not).
