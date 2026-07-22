# Factory Metrics

`scripts/metrics.sh` reports how the line is flowing, straight from the org Project
and the code-repo issues — no extra bookkeeping. The Project + artifact files stay the
source of truth; this only reads.

## What it reports

- **Items by Stage** — count of board items in each Stage (`Brief … Done`), plus an
  in-flight total (everything not yet `Done`). This is your current WIP across all repos.
- **Throughput** — `task` issues closed in the last 7 / 30 days and all-time, aggregated
  over every code repo that appears on the board.
- **Cycle time** — created→closed for closed tasks: average, min, and max in days.

## Usage

```bash
cd templates/factory
ORG=your-org PROJECT="Your Factory Board" \
  scripts/metrics.sh                 # markdown to stdout
scripts/metrics.sh metrics.md        # or write to a file
```

Requires `gh` (authenticated, with `project` scope: `gh auth refresh -s project`) and `jq`.

## Optional: weekly snapshot in the host repo

To post metrics to the Actions run summary on a schedule, copy the shipped template
[`templates/factory/.github/workflows/metrics.yml`](.github/workflows/metrics.yml) into
the **host repo** (`roadmap`) — it has org-wide visibility of the Project. This is a
host-repo workflow, **not** a per-code-repo drop-in.

The workflow runs on `schedule` (`0 6 * * 1`, Mondays 06:00 UTC) + `workflow_dispatch`,
requests `permissions: contents: read` only, and runs `metrics.sh` into
`$GITHUB_STEP_SUMMARY`. It requires a repo secret `PROJECTS_TOKEN` — a PAT scoped
`project` + `repo:read` (no write). If the token is unset the run posts a skip notice
instead of failing.

Read-only: it never commits or pushes, so it never conflicts with branch rulesets.

## Notes / limits

- Assumes `gh project item-list --format json` exposes the Stage single-select under
  `.stage` (gh ≥ 2.x). If your `gh` differs, adjust the `.stage` selector in the script.
- Throughput/cycle time count issues labeled `task` (per `setup-repo.sh`). Epics are
  excluded so the numbers reflect shipped work, not umbrellas.
