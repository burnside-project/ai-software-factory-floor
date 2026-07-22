# Template Pack System

The ai-software-factory uses a structured template pack for consistent issue management, workflow automation, and board synchronization.

## Overview

The template pack consists of:

- **Issue templates**: Feature, Bug, Task, Epic
- **Labels**: 30+ for workflow stages, gates, priorities, types, status, scope
- **Project board**: AI Factory Delivery Pipeline (Org-level)
- **Discussion categories**: General, Ideas, Announcements, Feedback
- **Workflows**: CI, deploy, sync-issues, metrics, board-sync

## Provisioning

Run from the ai-software-factory repo root:

```bash
# Single command to provision everything
./scripts/factory-setup.sh

# Or provision step-by-step
./scripts/label-setup.sh           # Create all labels (30+)
./scripts/project-setup.sh         # Create Project board
./scripts/discussion-setup.sh      # Create Discussion categories
./scripts/milestone-setup.sh       # Create milestones (v0.4.0, v0.5.0)
```

## Issue Templates

### Feature
Used for new feature requests and specifications.

### Bug
Used for defect reports and incident tracking.

### Task
Used for individual work items (TICKET-XXX).

### Epic
Used for multi-spec umbrella issues (SPEC-XXX).

## Labels

### Lifecycle
- `epic` (6f42c1) — SPEC-XXX umbrella
- `task` (0e8a16) — TICKET-XXX work item
- `gate:blocked` (b60205) — a required gate is failing
- `audit:pass` (0e8a16) — audit cleared
- `audit:fail` (b60205) — audit found blocking issues
- `incident` (d93f0b) — from Observe stage
- `skip-ticket` (ededed) — bypass the PR ticket-reference check

### Type
- `type:spec` (6f42c1) — a SPEC-XXX specification issue
- `type:ticket` (6f42c1) — a TICKET-XXX work item
- `type:epic` (6f42c1) — a multi-spec umbrella
- `type:bug` (6f42c1) — a defect report
- `type:feature-request` (6f42c1) — pre-spec intake

### Priority
- `priority:p0` (d93f0b) — production break or security issue
- `priority:p1` (f97583) — major feature blocked
- `priority:p2` (fef2c0) — important but not urgent
- `priority:p3` (fef2c0) — nice to have

### Stage
- `stage:spec` (fbca04) — being written
- `stage:arch` (c5def5) — architecture review
- `stage:security` (bfe5bf) — security review
- `stage:ticket` (f9d0c4) — tickets being created
- `stage:plan` (e1f6ff) — test plan
- `stage:code` (fbca04) — being implemented
- `stage:test` (c5def5) — running tests
- `stage:verify` (bfe5bf) — verification doc
- `stage:audit` (f9d0c4) — under auditor review
- `stage:review` (1d76db) — waiting on human
- `stage:done` (5319e7) — merged and closed

## Project Board

**Name**: AI Factory Delivery Pipeline

**Fields**:
- `Stage` (single-select: Brief, Spec, Architecture, Security, Tickets, Test Plan, Code, Test, Verify, Audit, Review, Deploy)
- `Spec` (text: SPEC-XXX)
- `Repo` (text: repository name)
- `Owner/Agent` (text: claude-code, deepseek, human)
- `Iteration` (text: v0.4.0, v0.5.0, etc.)
- `Risk` (single-select: Low, Medium, High, Critical)
- `Gate` (single-select: Blocked, Pending, Passed)

**Views**:
- Board grouped by Stage (the factory floor)
- Table filtered by Spec (traceability)
- Roadmap by Iteration (delivery forecast)

## Discussion Categories

- **General**: Team announcements, questions, and discussion
- **Ideas**: Feature suggestions and enhancements
- **Announcements**: Important updates and releases
- **Feedback**: User feedback and improvement suggestions

## Workflows

### CI Workflow
Runs on PR and main branch pushes:
- Lint checks
- Unit tests
- Contract tests
- Integration tests
- Verification checks

### Deploy Workflow
Runs on main branch merges:
- Auto-deploys to staging on green main
- Production requires environment approval

### Sync-Issues Workflow
Runs on push to main touching specs/** or tickets/**:
- Projects file front-matter onto Issues
- Updates Project Stage field

### Metrics Workflow
Optional weekly run:
- Reads WIP, throughput, cycle time from Project
- Reports to metrics dashboard

### Board-Sync Workflow
Runs on stage:* label changes:
- Updates Project Stage field
- Keeps board in sync with file status

## Setup

Apply to a repo:

```bash
./templates/factory/scripts/setup-repo.sh <org>/<repo>
```

This creates:
- All labels (30+)
- Issue templates
- CODEOWNERS
- CI/deploy workflows
- Branch ruleset

## Configuration

Create `.factory/factory.config.yaml` at repo root:

```yaml
apiVersion: factory.sh/v1
kind: FactoryConfig
metadata:
  name: my-factory
spec:
  org: my-org
  hostRepo: roadmap
  project: AI Factory Delivery Pipeline
  runnerLabels:
    - factory
  ruleset:
    enforcement: evaluate
```

## Troubleshooting

- **Labels not appearing**: Run `./scripts/label-setup.sh` again
- **Board not syncing**: Check `PROJECTS_TOKEN` secret is set
- **Workflows not running**: Verify `.github/workflows/` files exist
- **Ruleset not enforcing**: Flip from `evaluate` to `active` in repo settings
