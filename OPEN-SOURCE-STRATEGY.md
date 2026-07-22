# Open Source Strategy for ai-software-factory

## Goal
Create an open-source repo that:
1. **Peaks interest** — demonstrates value proposition clearly
2. **Doesn't give away the secret sauce** — keeps proprietary IP protected
3. **Works as a blog post hook** — provides tangible example readers can try
4. **Drives to closed-source version** — positions the full version as the "real" solution

---

## What Makes ai-software-factory Unique (The Secret Sauce)

### 1. The Independent Audit Gate (DeepSeek CI Integration)
- Runs DeepSeek (different model than Claude builder) in CI
- **Secret**: The calibration prompt that prevents false positives
- **Secret**: The loop guards and safe-degrade mechanisms
- **Secret**: The "sticky comment" pattern for PR reviews

### 2. The 14-Phase Gated Flow
- **Secret**: The specific gate definitions and transitions
- **Secret**: The issue-label-to-stage mapping logic
- **Secret**: The board sync and metrics collection system

### 3. The Autonomous Floor Motor
- **Secret**: The state machine that drives the label-based workflow
- **Secret**: The event-to-phase routing logic
- **Secret**: The kill switches and loop prevention

### 4. The Template Pack System
- **Secret**: The 30+ label naming convention and organization
- **Secret**: The ruleset mapping and data-driven selection
- **Secret**: The Project v2 field configuration

---

## Open Source Strategy

### Option A: "The Gate Framework" (Recommended)
**Focus**: GitHub-native gates only (no AI agents)

**What's Open Source**:
- 14-phase SDLC flow documentation
- GitHub-native gates (branch rulesets, CODEOWNERS, required checks)
- Issue templates and label system
- Project board configuration
- CI workflow templates (generic lint/test/build/verify)

**What's Closed**:
- AI agent definitions (`.claude/agents/`)
- DeepSeek audit integration
- Autonomous floor motor
- Template pack provisioning scripts

**Value Proposition**: "See how we enforce gates. Want the AI agents? Contact us."

**Blog Hook**: "How we built a 14-phase gated SDLC using only GitHub-native features"

---

### Option B: "The Phase Reference Implementation"
**Focus**: One phase at a time (product manager only)

**What's Open Source**:
- Product Manager agent (spec creation workflow)
- Spec templates and conventions
- Brief → Epic → Spec → Ticket hierarchy
- Acceptance criteria patterns

**What's Closed**:
- All other agents (architect, security-architect, etc.)
- Audit gate
- Floor motor
- Full provisioning system

**Value Proposition**: "Try our spec-first approach. Want the full SDLC? Contact us."

**Blog Hook**: "How we enforce spec-first development with AI agents"

---

### Option C: "The Gate Playground"
**Focus**: Interactive demo of gate concepts

**What's Open Source**:
- Minimal GitHub repo setup script
- Interactive tutorial (markdown-based)
- "Build your own gates" workshop
- Reference implementation of one phase

**What's Closed**:
- Full agent suite
- DeepSeek integration
- Floor motor
- Complete provisioning

**Value Proposition**: "Learn how to build gated SDLCs. Want the production version? Contact us."

**Blog Hook**: "Interactive workshop: Build your own gated SDLC in 30 minutes"

---

## Recommended Approach: Option A + Option B Hybrid

### Phase 1: The Gate Framework (Open Source)
**Repo**: `dataalgebra-engineering/ai-software-factory-gates`

**Contents**:
```
ai-software-factory-gates/
├── README.md                    # Gate overview, no AI mentions
├── PHASES.md                    # 14-phase flow documentation
├── GATES.md                     # Gate definitions and patterns
├── TEMPLATES/                   # Issue templates, labels, workflows
│   ├── ISSUE_TEMPLATE/
│   ├── .github/workflows/
│   └── ruleset*.json
├── scripts/                     # Generic provisioning (no AI)
│   ├── setup-gates.sh
│   ├── setup-project.sh
│   └── validate-gates.sh
└── docs/
    ├── getting-started.md
    ├── architecture.md
    └── reference.md
```

**Key Documentation**:
- **PHASES.md**: "The 14-phase delivery flow" (text only, no code)
- **GATES.md**: "GitHub-native gates for each phase" (ruleset examples)
- **README.md**: "Enforce your SDLC with GitHub-native gates"

**Value**: Readers get the gate framework, see the phase structure, but can't run AI agents.

---

### Phase 2: The Product Manager Agent (Open Source)
**Repo**: `dataalgebra-engineering/ai-software-factory-pm-agent`

**Contents**:
```
ai-software-factory-pm-agent/
├── README.md                    # PM agent overview
├── AGENT.md                     # Product Manager agent definition
├── templates/
│   ├── spec-template.md
│   ├── brief-template.md
│   └── acceptance-criteria.md
├── examples/
│   ├── example-brief.md
│   ├── example-spec.md
│   └── example-ticket.md
└── docs/
    └── how-it-works.md
```

**Key Documentation**:
- **AGENT.md**: Product Manager agent (no DeepSeek, no floor motor)
- **examples/**: Real spec examples
- **how-it-works.md**: "How the PM agent creates specs"

**Value**: Readers see one agent in action, understand the spec-first approach.

---

### Phase 3: The Blog Post
**Title**: "How We Built a 14-Phase Gated SDLC with GitHub-native Gates"

**Structure**:
1. **Problem**: "Most AI SDLCs lack enforcement. Specs get ignored. Code gets merged without review."
2. **Solution**: "We built a 14-phase gated SDLC using GitHub-native features"
3. **Demo**: "Here's how gates work" (show ruleset examples, CODEOWNERS, required checks)
4. **Agent Demo**: "We also use AI agents for each phase. Try our open-source PM agent."
5. **CTA**: "Want the full system? Contact us for the closed-source version."

**Links**:
- [ai-software-factory-gates](https://github.com/dataalgebra-engineering/ai-software-factory-gates) — GitHub gates
- [ai-software-factory-pm-agent](https://github.com/dataalgebra-engineering/ai-software-factory-pm-agent) — PM agent
- [Contact us](mailto:sales@dataalgebra.engineering) — full system

---

## What NOT to Open Source

### 1. DeepSeek Integration
- The calibration prompt (prevents false positives)
- The loop guards (cost control)
- The sticky comment pattern (PR review UX)

**Alternative**: Document the concept but not the implementation.

---

### 2. Floor Motor State Machine
- The label-to-phase routing
- The kill switches
- The event-to-state mapping

**Alternative**: Document the high-level concept but not the code.

---

### 3. Complete Provisioning System
- The factory-setup.sh scripts
- The template pack generation
- The data-driven ruleset mapping

**Alternative**: Provide minimal setup scripts that don't include the secret sauce.

---

### 4. All 14 Agents
- Only open source the PM agent
- Keep architect, security-architect, auditor, etc. closed

**Alternative**: Open source one agent as a "reference implementation."

---

## Monetization Strategy

### 1. Free Tier (Open Source)
- Gate framework (Option A)
- PM agent (Option B)
- Documentation
- Community support

### 2. Paid Tier (Closed Source)
- All 14 agents
- DeepSeek audit integration
- Floor motor autonomy
- Full provisioning system
- Priority support
- Customization services

### 3. Value Proposition
- **Free**: "See how gates work. Try one agent."
- **Paid**: "Full AI SDLC with 14 agents, autonomous delivery, and production-grade gates."

---

## Implementation Status

**Status**: ✅ **Option 2 Implemented** (Moderate Protection)

### What's Open Source
- GitHub-native gates (rulesets, CODEOWNERS, required checks)
- 14-phase SDLC flow documentation
- Product Manager agent (spec-first approach)
- Generic agents (architect, security, backend, QA, etc.)
- Provisioning scripts (setup gates, labels, project)
- Issue templates and labels
- Project board configuration

### What's Closed Source
- Full orchestration (`.claude/commands/feature-delivery.md` - REMOVED)
- DeepSeek audit integration (deepseek-audit.sh - REMOVED)
- Autonomous floor motor (floor-motor.yml, arbiter.sh - REMOVED)
- Template pack provisioning system
- Complete orchestration logic (provision.sh, bootstrap-project.sh - REMOVED)

---

## Success Metrics

### Open Source Adoption
- 100+ stars on gate framework repo
- 50+ stars on PM agent repo
- 10+ forks
- 5+ issues/PRs

### Blog Post Performance
- 1000+ views
- 100+ clicks to contact page
- 10+ demo requests

### Paid Conversions
- 5+ demo calls
- 2+ pilots
- 1+ paying customer

## IP Protection Status

### ✅ Protected (Removed)
- `scripts/provision.sh` — Full orchestration
- `scripts/bootstrap-project.sh` — System installation
- `.claude/commands/feature-delivery.md` — Full workflow orchestration
- `.claude/commands/post-merge.md` — Archive orchestration
- `.claude/commands/provisioning/` — Provisioning commands
- `templates/factory/scripts/deepseek-audit.sh` — DeepSeek integration
- `templates/factory/scripts/arbiter.sh` — Floor motor state machine
- `templates/factory/.github/workflows/floor-motor.yml` — Floor motor
- `templates/factory/.github/workflows/stage-arbiter.yml` — Stage arbiter
- `templates/factory/stage-transitions.tsv` — Transition rules
- `templates/factory/event-graph.tsv` — Event routing
- `templates/factory/scripts/lib/emit-intent.sh` — Intent emission
- `templates/factory/scripts/lib/verify-precondition.sh` — Precondition checks
- `.claude/settings.local.json` — Internal patterns

---

## Risk Mitigation

### 1. IP Leakage
- **Risk**: Someone copies the open source and claims it's their own
- **Mitigation**: Clear license, copyright notices, documentation that links to original

### 2. Feature Parity
- **Risk**: Open source has enough value that people don't buy the paid version
- **Mitigation**: Keep the secret sauce closed (DeepSeek, floor motor, all agents)

### 3. Support Burden
- **Risk**: Open source users expect free support for the full system
- **Mitigation**: Clear documentation of what's open vs closed, support tiers

---

## Conclusion

**Recommended Approach**: Option A + Option B Hybrid

**Why**:
1. **Low risk**: No secret sauce in open source
2. **High value**: Readers get tangible value
3. **Clear CTA**: Easy to see what's missing
4. **Blog-friendly**: Concrete examples for article

**Key Principle**: Open source the *concept*, not the *implementation*.

**Example**: Open source "how gates work" but not "how DeepSeek audit works."
