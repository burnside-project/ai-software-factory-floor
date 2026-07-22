# Quick Reference — ai-software-factory

## Command Line

### Provisioning
```bash
# Check prerequisites
./scripts/check-readiness.sh

# Bootstrap a new project
./scripts/bootstrap-project.sh /path/to/new-project

# Upgrade existing project
./scripts/upgrade-project.sh /path/to/existing-project

# Full provisioning (all-in-one)
./templates/factory/scripts/setup-repo.sh <org>/<repo>
```

### GitHub Setup
```bash
# Create all labels
./scripts/label-setup.sh

# Create Project board
./scripts/project-setup.sh

# Create Discussion categories
./scripts/discussion-setup.sh

# Create milestones
./scripts/milestone-setup.sh
```

### CI Checks
```bash
# Reconcile CI checks
./scripts/reconcile-ci-checks.sh

# Validate artifacts
./templates/factory/scripts/validate-artifacts.sh

# Audit naming
./templates/factory/scripts/audit-org-naming.sh
```

## Claude Code Commands

### Delivery
- `/feature-delivery <feature idea>` — Full feature flow
- `/post-merge <SPEC-XXX>` — Archive after merge

### Provisioning (factory-root only)
- `/provisioning:check-readiness` — Pre-flight check
- `/provisioning:onboard-project` — Full onboarding
- `/provisioning:onboard-repo` — Existing repo onboarding
- `/provisioning:activate-gates` — Gate activation

## GitHub-native Gates

### Required Checks
- `lint` — Code style and formatting
- `test` — Unit tests
- `contract` — Cross-repo contracts
- `integration` — Integration tests
- `verification` — Test evidence
- `spec-gate` — Spec approval

### CODEOWNERS
- `docs/specs/**` → architect + security-architect
- `internal/**` → backend-engineer
- `verification/**` → qa-engineer

### Environments
- `staging` — Auto-deploy on green main
- `production` — Required reviewer + wait timer

## Issue Types

| Type | Prefix | Purpose |
|------|--------|---------|
| Epic | SPEC-XXX | Multi-spec umbrella |
| Task | TICKET-XXX | Work item |
| Bug | BUG-XXX | Defect report |
| Feature Request | FR-XXX | Pre-spec intake |

## Labels Quick List

### Lifecycle
- `epic`, `task`, `gate:blocked`, `audit:pass`, `audit:fail`, `incident`

### Type
- `type:spec`, `type:ticket`, `type:epic`, `type:bug`, `type:feature-request`

### Priority
- `priority:p0`, `priority:p1`, `priority:p2`, `priority:p3`

### Stage
- `stage:spec`, `stage:arch`, `stage:security`, `stage:ticket`, `stage:plan`, `stage:code`, `stage:test`, `stage:verify`, `stage:audit`, `stage:review`, `stage:done`

## Project Board Fields

- `Stage` — Brief, Spec, Architecture, Security, Tickets, Test Plan, Code, Test, Verify, Audit, Review, Deploy
- `Spec` — SPEC-XXX reference
- `Repo` — Repository name
- `Owner/Agent` — claude-code, claude-code, human
- `Iteration` — v0.4.0, v0.5.0, etc.
- `Risk` — Low, Medium, High, Critical
- `Gate` — Blocked, Pending, Passed

## Common Workflows

### New Feature
1. `/feature-delivery <idea>` → Spec phase
2. Architecture & Security reviews
3. Tickets created
4. Test plan written
5. **Spec Gate** (must be Ready)
6. Implementation
7. Verification
8. **Audit** (independent)
9. Documentation
10. PR
11. **Compliance Gate**
12. Human merge

### Post-Merge
1. `/post-merge SPEC-XXX` → Archive
2. Update delivery ledger

### Onboarding
1. `./scripts/check-readiness.sh` → Fix missing
2. `./scripts/bootstrap-project.sh <path>` → Install
3. `./templates/factory/scripts/setup-repo.sh <repo>` → GitHub setup
4. Flip rulesets to `active`
5. Configure floor motor (optional)

## Floor Motor (Autonomous)

### Enable
1. Configure `automate.sh` with repo paths
2. Set `DEPLOY_REMOTE=1` for remote deployment
3. Run `./automate.sh all` for full cycle

### Commands
- `./automate.sh audit` — Run audit
- `./automate.sh plan-features` — Plan features
- `./automate.sh features` — Implement features
- `./automate.sh deploy` — Deploy
- `./automate.sh all` — Full cycle

## Troubleshooting

### Missing Labels
```bash
./scripts/label-setup.sh
```

### Board Not Syncing
1. Check `PROJECTS_TOKEN` secret
2. Verify workflow permissions
3. Check token scope: `project` (read+write)

### Ruleset Not Enforcing
1. Check ruleset state: `evaluate` vs `active`
2. Flip in repo Settings → Rulesets
3. Run `./templates/factory/scripts/setup-repo.sh <repo> ENFORCEMENT=active`

### Workflows Not Running
1. Check `.github/workflows/` exists
2. Verify workflow file syntax
3. Check repository settings → Actions

## Key Files

| File | Purpose |
|------|---------|
| `PROVISIONING.md` | Complete onboarding runbook |
| `templates/factory/TEMPLATE-PACK.md` | Template pack system |
| `templates/factory/ACTIVATE.md` | Go-live checklist |
| `templates/factory/RUNBOOK-floor-motor.md (optional autonomy)` | Autonomous delivery |
| `templates/factory/NAMING.md` | Naming conventions |
| `templates/factory/METRICS.md` | Metrics and reporting |

## Support

- Read `PROVISIONING.md` for end-to-end onboarding
- Read `templates/factory/TEMPLATE-PACK.md` for template details
- Read `templates/factory/RUNBOOK-floor-motor.md (optional autonomy)` for autonomy
- Check `docs/getting-started.md` for task-oriented walkthrough
