# IP Protection Strategy for Open Source Teaser

## Current State (NOT Protected)

### What's Currently Exposed
1. **`.claude/` folder** — 13 AI agents + commands
   - All agents can be copied and used
   - feature-delivery.md orchestrates full 14-phase flow
   - provisioning/ folder has guided walkthroughs

2. **`scripts/` folder** — 11 scripts
   - provision.sh (21KB) — orchestrates full provisioning
   - bootstrap-project.sh (14KB) — installs entire system
   - All setup scripts

3. **`templates/` folder** — All templates
   - Spec, ticket, and review templates
   - Issue templates

4. **`docs/` folder** — All documentation
   - Architecture, getting-started, delivery-ledger

## What Actually Constitutes IP

### Core IP (Must Stay Closed)
1. **The agent orchestration logic** — How agents work together
2. **The 14-phase workflow** — feature-delivery.md
3. **The provisioning system** — provision.sh, bootstrap-project.sh
4. **The template pack system** — How templates work together
5. **The gate enforcement logic** — How GitHub gates work

### Safe to Open Source
1. **Individual agent definitions** — Generic role-based agents
2. **Individual templates** — Standard spec/ticket templates
3. **GitHub-native features** — Branch rulesets, CODEOWNERS
4. **Documentation concepts** — How gates work (without implementation)

## IP Protection Options

### Option 1: Remove .claude/ and scripts/ entirely
**Result**: Open source teaser has NO AI agents, NO provisioning scripts

**Pros**:
- Zero IP exposure
- Clear distinction: "See how gates work, but no AI"

**Cons**:
- No value proposition (just GitHub gates)
- Can't demonstrate the AI SDLC
- Blog post would be weak

**Use case**: If we want to be extremely conservative

---

### Option 2: Keep only PM agent + remove orchestration
**Result**: Open source teaser has Product Manager agent only, no full workflow

**What stays**:
- `.claude/agents/product-manager.md` — PM agent
- `.claude/agents/architect.md` — Architect agent (generic)
- `.claude/agents/security-architect.md` — Security agent (generic)
- `.claude/agents/backend-engineer.md` — Backend agent (generic)
- `.claude/agents/qa-engineer.md` — QA agent (generic)
- `.claude/agents/documentation-writer.md` — Docs agent (generic)
- `.claude/agents/test-engineer.md` — Test agent (generic)
- `.claude/agents/release-engineer.md` — Release agent (generic)
- `.claude/agents/sre.md` — SRE agent (generic)
- `.claude/agents/tech-lead.md` — Tech lead agent (generic)
- `.claude/agents/compliance-reviewer.md` — Compliance agent (generic)
- `.claude/agents/auditor.md` — Auditor agent (generic)
- `.claude/commands/feature-delivery.md` — **REMOVE** (core IP)
- `.claude/commands/post-merge.md` — **REMOVE** (core IP)
- `.claude/commands/provisioning/` — **REMOVE** (core IP)

**What's removed**:
- `.claude/commands/feature-delivery.md` — orchestrates full workflow
- `.claude/commands/post-merge.md` — archives completed features
- `.claude/commands/provisioning/` — all provisioning commands
- `scripts/provision.sh` — orchestrates provisioning
- `scripts/bootstrap-project.sh` — installs system

**What stays**:
- Individual agent definitions (generic role-based)
- Provisioning scripts (setup-project, label-setup, etc.)
- Templates (standard spec/ticket templates)
- Documentation (concepts without implementation)

**Pros**:
- Demonstrates one agent in action
- Shows the spec-first approach
- Clear CTA: "Want the full AI SDLC? Contact us."

**Cons**:
- Still has many agents exposed
- Provisioning scripts still available
- Can't demonstrate full workflow

**Use case**: Moderate protection, good for blog post

---

### Option 3: Keep only PM agent + remove all orchestration + remove scripts
**Result**: Open source teaser has Product Manager agent only, no workflow, no provisioning

**What stays**:
- `.claude/agents/product-manager.md` — PM agent only

**What's removed**:
- All other agents
- All commands
- All scripts
- Provisioning scripts

**Pros**:
- Minimal IP exposure
- Clear demonstration of one agent
- Strong CTA

**Cons**:
- Very limited value
- Hard to demonstrate AI SDLC
- Blog post would be very short

**Use case**: Maximum protection, minimal demo

---

### Option 4: Replace orchestration with placeholder
**Result**: Open source teaser has all agents, but orchestration is replaced with "contact us"

**What's modified**:
- `feature-delivery.md` — replaced with "contact us for full workflow"
- `post-merge.md` — replaced with "contact us for archiving"
- `provisioning/` — replaced with "contact us for provisioning"
- `scripts/provision.sh` — replaced with placeholder
- `scripts/bootstrap-project.sh` — replaced with placeholder

**Pros**:
- Demonstrates all agents
- Shows the full structure
- Clear CTA for commercial version

**Cons**:
- Still exposes all agent logic
- All templates exposed
- Provisioning scripts still available

**Use case**: If we want to show the full structure but not the implementation

---

### Option 5: Create simplified open source version
**Result**: Open source teaser has simplified agents + simplified provisioning

**What's created**:
- Simplified PM agent (reduced capabilities)
- Simplified feature-delivery (reduced phases)
- Simplified provisioning (reduced gates)
- No DeepSeek integration
- No floor motor

**What's removed**:
- All other agents
- Complex orchestration
- Advanced provisioning

**Pros**:
- Real open source product
- Can be used independently
- Clear distinction from closed source

**Cons**:
- More work to create
- May compete with closed source
- Still has some IP exposed

**Use case**: If we want an actual open source product

---

## Recommended Approach: Option 2 (Moderate Protection)

### Rationale
1. **Demonstrates value** — PM agent shows spec-first approach
2. **Clear CTA** — "Want the full AI SDLC? Contact us."
3. **Low IP risk** — No orchestration logic exposed
4. **Blog-friendly** — Can write about "How we use AI for spec creation"

### Implementation

#### Remove these files:
```bash
rm .claude/commands/feature-delivery.md
rm .claude/commands/post-merge.md
rm -rf .claude/commands/provisioning/
rm scripts/provision.sh
rm scripts/bootstrap-project.sh
```

#### Modify these files:
```bash
# .claude/agents/auditor.md
# Remove reference to DeepSeek audit
# Keep generic audit instructions

# scripts/setup-repo.sh
# Remove DeepSeek audit references
# Keep generic GitHub gates
```

#### Update documentation:
```bash
# OPEN-SOURCE-TEASER-STRATEGY.md
# Update to reflect Option 2

# REFACTORING-PLAN.md
# Update to reflect Option 2

# README.md
# Update to reflect open source teaser
```

### Result

**Open source teaser has**:
- ✅ Product Manager agent (demonstrates spec-first)
- ✅ Generic agents (architect, security, etc.)
- ✅ GitHub-native gates
- ✅ Templates
- ❌ No orchestration (feature-delivery removed)
- ❌ No provisioning (provision.sh removed)
- ❌ No DeepSeek audit
- ❌ No floor motor

**Closed source has**:
- ✅ All 14 agents
- ✅ Full orchestration
- ✅ DeepSeek audit
- ✅ Floor motor
- ✅ Template pack provisioning

**Value proposition**:
- Open source: "See how we use AI for spec creation"
- Closed source: "Full AI SDLC with 14 agents and autonomous delivery"
