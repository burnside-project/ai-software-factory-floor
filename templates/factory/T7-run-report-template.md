# T7 run report — floor motor end-to-end dry run

Fill this in as you work `SMOKE-TEST-floor-motor.md`. One page; it's the sign-off record
for epic #4 T7. Copy to `verification/results/T7-<date>.md` in the sandbox repo (or attach
to the epic) when done.

## Run context

| field | value |
|---|---|
| Date | `<YYYY-MM-DD>` |
| Operator | `@<you>` |
| Sandbox repo | `<owner>/<repo>` |
| Method version | `<cat VERSION>` (motor added in v0.3.0) |
| Model | `FLOOR_MODEL = <claude-sonnet-4-6 / …>` |
| Turn caps | `FLOOR_MAX_TURNS_SPEC=<80>` · `FLOOR_MAX_TURNS_CODE=<60>` |
| Timeout | `FLOOR_TIMEOUT_MINUTES=<45>` |
| Fixtures | SPEC-900/TICKET-900 (build) · BRIEF-901 (upstream) |

## Preconditions (all must be true before starting)

- [ ] App installed; secrets set (`ANTHROPIC_API_KEY`, `FLOOR_APP_ID`, `FLOOR_APP_PRIVATE_KEY`, `PROJECTS_TOKEN`)
- [ ] `main` branch protection **active** · `setup-teams.sh` passes · `FLOOR_MOTOR_ENABLED` unset

## Results

| # | Test | Expected | Result | Run link | Notes |
|---|---|---|---|---|---|
| 1 | Kill switch | motor OFF → no run | ⬜ pass / ⬜ fail | | |
| 2 | Build phase | implement→verify→audit→PR, issue `stage:review`, run summary | ⬜ / ⬜ | | |
| 3 | Stops at human gate | PR open, **not merged**; no bot approval; `main` untouched | ⬜ / ⬜ | | |
| 4 | Failure isn't silent | broken ticket → `gate:blocked` + `incident` issue | ⬜ / ⬜ | | |
| 5 | Cost caps | stops at turn/timeout ceiling | ⬜ / ⬜ | | |
| 6 | Upstream phase | BRIEF-901 → spec+reviews+tickets+test-plan PR, `stage:spec-review`, gate **not self-approved**, security review flags CSPRNG | ⬜ / ⬜ | | |
| 7 | Board sync | Project `Stage` field tracks the label | ⬜ / ⬜ / ⬜ n/a | | |

## Artifacts produced

- Build PR (Test 2): `<url>`
- Upstream PR (Test 6): `<url>`
- Incident issue (Test 4): `<url>`

## Verdict

- Tests 1–5 pass → **build-side motor trusted**: ⬜ yes / ⬜ no
- Tests 6–7 pass → **upstream autonomy + board sync trusted**: ⬜ yes / ⬜ no / ⬜ not run
- **Overall:** ⬜ T7 signed off · ⬜ blocked (see follow-ups)

## Follow-ups (for any ⬜ fail)

| test | what went wrong | action / issue |
|---|---|---|
| | | |

## Sign-off

Signed: `@<you>` · Date: `<YYYY-MM-DD>` · then check **T7** on epic #4 and note the run
links there.
