# Sandbox fixtures — floor-motor T7 dry run

A pre-staged, deliberately tiny feature (a `slugify` utility) for the end-to-end smoke
test in [`../SMOKE-TEST-floor-motor.md`](../SMOKE-TEST-floor-motor.md). It gives the motor
something real to build without real complexity. **Not a product feature.**

```
specs/draft/SPEC-900-slugify/spec.md   # build test: a finished spec + one buildable ticket
tickets/ready/TICKET-900-slugify.md
briefs/BRIEF-901-token.md              # upstream test: a raw idea (the motor writes the spec)
```

Two fixtures for the two motor entry points:
- **`stage:code`** (build test) → SPEC-900 / TICKET-900: a *finished* spec the motor implements.
- **`stage:spec`** (upstream test) → BRIEF-901: a raw *idea* the motor turns into a spec +
  reviews + tickets + test plan.

## Use it

1. **Pick a sandbox repo** with the factory installed (`bootstrap-project.sh`) and the
   `.github/` workflows + `CODEOWNERS` committed. Never use a production repo.
2. **Copy the fixtures** into it:
   ```bash
   cp -R templates/factory/sandbox/specs/*   <sandbox>/specs/
   cp -R templates/factory/sandbox/tickets/* <sandbox>/tickets/
   ```
3. **Set the ticket's `repo:`** front-matter to `<owner>/<sandbox-repo>` (currently
   `<your-sandbox-repo>`). Commit the spec + ticket via a PR and merge (the spec must be
   merged so the build phase has a `Ready` ticket with a merged spec).
4. **Create the tracking issues** — either by hand, or:
   ```bash
   scripts/sync-issues.sh <sandbox>/tickets
   ```
5. **Run the smoke test.** Follow `../SMOKE-TEST-floor-motor.md`:
   - **Build phase (Test 2):** add `stage:code` to the `TICKET-900` issue → the motor
     implements slugify + a unit test, runs `make verify`, audits, opens a PR, stops at
     `stage:review`.
   - **Upstream phase (Test 6):** create an **epic issue** with `briefs/BRIEF-901-token.md`
     as the body, then add `stage:spec`. The motor drafts `SPEC-901` (spec + architecture
     + security reviews + tickets + test plan), opens a PR, and stops at `stage:spec-review`
     with a verdict. The security review should call out the CSPRNG requirement — that's
     the point of picking a token generator. **You** approve the spec gate (the motor must
     not), then add `stage:code` to a resulting ticket to hand it to the build phase.

## Expected slugify behavior (what the motor must produce)

| input | output |
|---|---|
| `Hello World` | `hello-world` |
| `  Trim  Me  ` | `trim-me` |
| `Foo_Bar 123` | `foo-bar-123` |
| `A  &  B` | `a-b` |
| `--edge--` | `edge` |
| `` (empty) | `` |

If the motor's PR reproduces these and stops for your review without merging, the
build-side motor passes the smoke test.
