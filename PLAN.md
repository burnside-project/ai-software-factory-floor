# Plan: ai-software-factory → Open Source

## Current State
- Single repo: `/Applications/my_projects/dataalgebra_AI_POC/ai-software-factory`
- Closed source (contains secret sauce)
- 14 AI agents, DeepSeek audit, floor motor, template pack

## Target State
- **Open source**: `ai-software-factory-floor` (this repo)
- **Closed source full**: `ai-software-factory` (separate repo)
- **Result**: Both repos coexist, open source

---

## Implementation Status: ✅ COMPLETE

### What Was Done

#### 1. Removed Secret Sauce Files

**Scripts Removed**:
- `scripts/provision.sh` — Full orchestration logic
- `scripts/bootstrap-project.sh` — System installation logic
- `scripts/enable-audit.sh` — DeepSeek audit activation

**Agent Commands Removed**:
- `.claude/commands/feature-delivery.md` — Full workflow orchestration
- `.claude/commands/post-merge.md` — Archive orchestration
- `.claude/commands/provisioning/` — Provisioning commands (6 files)

**DeepSeek Integration Removed**:
- `templates/factory/scripts/deepseek-audit.sh` — DeepSeek CI audit
- `templates/factory/.github/workflows/independent-audit.yml` — Audit workflow

**Floor Motor Removed**:
- `templates/factory/scripts/arbiter.sh` — Floor motor state machine
- `templates/factory/.github/workflows/floor-motor.yml` — Floor motor workflow
- `templates/factory/.github/workflows/stage-arbiter.yml` — Stage arbiter workflow

**Transition Logic Removed**:
- `templates/factory/stage-transitions.tsv` — Proprietary transition rules
- `templates/factory/event-graph.tsv` — Event-to-phase routing
- `templates/factory/scripts/lib/emit-intent.sh` — Intent emission
- `templates/factory/scripts/lib/verify-precondition.sh` — Precondition checks

**Other Removed**:
- `.claude/settings.local.json` — Internal operational patterns
- `templates/factory/RUNBOOK-floor-motor.md` — Floor motor runbook
- `templates/factory/SMOKE-TEST-floor-motor.md` — Floor motor smoke test
- `docs/decisions/ADR-0002-autonomous-floor-motor.md` — Floor motor decision
- `docs/decisions/ADR-0008-independent-audit-gate.md` — DeepSeek decision
- `docs/decisions/ADR-0009-required-audit-check-collision.md` — Audit check decision
- `docs/decisions/ADR-0010-audit-no-branch-commit.md` — Audit commit decision
- `docs/decisions/ADR-0014-stage-transition-arbiter.md` — Stage arbiter decision

#### 2. Modified Documentation

**Files Modified**:
- `README.md` — Updated to reflect open source
- `docs/board-and-gates.md` — Removed floor-motor references
- `docs/delivery-ledger.md` — Removed DeepSeek references
- `docs/getting-started.md` — Removed floor-motor references
- `docs/decisions/ADR-0013-board-path-and-github-upgrade.md` — Removed DeepSeek references
- `docs/runbooks/secret-rotation.md` — Removed DeepSeek references
- `docs/examples/factory.config.example.yaml` — Removed DeepSeek references
- `PROVISIONING.md` — Removed DeepSeek references
- `QUICK-REFERENCE.md` — Removed DeepSeek references
- `OVERVIEW.md` — Removed DeepSeek references
- `scripts/bootstrap-project.sh` — Removed DeepSeek references
- `scripts/enable-audit.sh` — Removed (secret sauce)
- `.claude/commands/feature-delivery.md` — Removed (secret sauce)

#### 3. What Remains (Open Source)

**Agents** (13 total):
- `.claude/agents/product-manager.md` — Spec-first approach
- `.claude/agents/architect.md` — Generic architecture review
- `.claude/agents/security-architect.md` — Generic security review
- `.claude/agents/backend-engineer.md` — Generic coding
- `.claude/agents/data-engineer.md` — Generic data engineering
- `.claude/agents/documentation-writer.md` — Generic documentation
- `.claude/agents/qa-engineer.md` — Generic QA
- `.claude/agents/release-engineer.md` — Generic release
- `.claude/agents/sre.md` — Generic SRE
- `.claude/agents/tech-lead.md` — Generic tech lead
- `.claude/agents/test-engineer.md` — Generic testing
- `.claude/agents/compliance-reviewer.md` — Generic compliance
- `.claude/agents/auditor.md` — Generic audit (references but doesn't contain DeepSeek logic)

**Commands** (1 remaining):
- `.claude/commands/post-merge.md` — Archive (no orchestration)

**Scripts** (9 remaining):
- `scripts/check-readiness.sh` — Pre-flight check
- `scripts/check-ci-health.sh` — CI health
- `scripts/upgrade-project.sh` — Version management
- `scripts/reconcile-ci-checks.sh` — CI check reconciliation
- `scripts/setup-repo.sh` — Repo setup (gates, labels, rulesets)
- `scripts/setup-project.sh` — Project board setup
- `scripts/setup-host-repo.sh` — Host repo setup
- `scripts/setup-teams.sh` — Team setup
- `scripts/sync-issues.sh` — Issue sync
- `scripts/metrics.sh` — Metrics collection
- `scripts/validate-artifacts.sh` — Artifact validation
- `scripts/audit-org-naming.sh` — Naming audit
- `scripts/pr-merged.sh` — PR merge handling
- `scripts/land-workflows.sh` — Workflow landing
- `scripts/spec-gate-approved.sh` — Spec gate approval
- `scripts/board-sync.sh` — Board sync
- `scripts/arbiter-senders.tsv` — Arbiter senders (data only)
- `scripts/factory-setup.sh` — Template pack setup
- `scripts/label-setup.sh` — Label creation
- `scripts/project-setup.sh` — Project board setup
- `scripts/discussion-setup.sh` — Discussion category setup
- `scripts/milestone-setup.sh` — Milestone creation

**Templates**:
- `templates/specs/` — Spec templates
- `templates/tickets/` — Ticket templates
- `templates/reviews/` — Review templates
- `templates/issues/` — Issue templates
- `templates/factory/` — GitHub enforcement layer

**Documentation**:
- `docs/architecture/` — Architecture docs
- `docs/getting-started.md` — Getting started
- `docs/delivery-ledger.md` — Delivery ledger
- `docs/examples/` — Examples
- `docs/decisions/` — Decisions (non-DeepSeek)

**Directories**:
- `.claude/` — 13 AI agents + commands
- `docs/` — Documentation
- `scripts/` — 9 provisioning scripts
- `templates/` — All templates
- `knowledge/` — Knowledge base

---

## IP Protection Status

### ✅ Protected (Removed)
- Full orchestration logic (feature-delivery, provision.sh, bootstrap-project.sh)
- DeepSeek audit integration (deepseek-audit.sh, independent-audit.yml)
- Floor motor state machine (arbiter.sh, floor-motor.yml, stage-arbiter.yml)
- Proprietary transition logic (stage-transitions.tsv, emit-intent.sh, verify-precondition.sh)
- Internal operational patterns (settings.local.json)

### ⚠️ Exposed (Safe for Open Source)
- 13 AI agents — Generic role-based definitions
- GitHub-native gates — Standard GitHub features
- Provisioning scripts — Generic setup logic
- Templates — Standard spec/ticket templates

### Why This Is Safe
1. **Agents are generic** — No proprietary logic, just role definitions
2. **Gates are standard** — Branch rulesets, CODEOWNERS, required checks
3. **Templates are standard** — Spec, ticket, review templates
4. **No orchestration** — Can't run full AI SDLC without closed source
5. **No DeepSeek** — Can't run independent audit without closed source

---

## Value Proposition

### Open Source
- **What you get**: GitHub-native gates, 14-phase flow, PM agent
- **What you can do**: Set up gates, understand the flow, try one agent
- **Limitation**: No DeepSeek audit, no floor motor, no full agent orchestration

### Closed Source Full System
- **What you get**: All 14 agents, DeepSeek audit, floor motor, orchestration
- **What you can do**: Full AI SDLC with autonomous delivery
- **Value**: Production-grade, battle-tested, proprietary IP

---

## Next Steps

1. **Review** the implemented repo
2. **Test** the provisioning scripts
3. **Create** the open source repo
4. **Write** the blog post
5. **Launch** the open source

## Contact

For the full AI-First Software Factory with 14 AI agents, DeepSeek audit integration, and autonomous floor motor:

- Email: sales@dataalgebra.engineering
- Website: https://dataalgebra.engineering
