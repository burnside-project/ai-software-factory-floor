# ai-software-factory-floor

**GitHub-native gates for your SDLC — no AI agents required.**

See how we enforce a 14-phase delivery flow using only GitHub-native features:
branch rulesets, CODEOWNERS, required checks, and issue templates.

> **Note**: This is an **open source teaser**. The full AI-First Software Factory with 14 AI agents, DeepSeek audit integration, and autonomous floor motor is available under commercial license. [Contact us](mailto:sales@dataalgebra.engineering) for the production version.

## What You Get (Open Source)

- ✅ 14-phase SDLC flow documentation
- ✅ GitHub-native gate definitions (rulesets, CODEOWNERS, required checks)
- ✅ Issue templates and labels (30+ for workflow stages, gates, priorities)
- ✅ Project board configuration (org-level)
- ✅ Product Manager agent (spec-first approach)
- ✅ Generic agents (architect, security, backend, QA, etc.)
- ✅ CI workflow templates
- ✅ Provisioning scripts (setup gates, labels, project)

## What's NOT Included (Closed Source)

- ❌ Full orchestration (`.claude/commands/feature-delivery.md`)
- ❌ DeepSeek audit integration
- ❌ Autonomous floor motor
- ❌ Template pack provisioning system
- ❌ Complete agent suite with orchestration

## Quick Start

```bash
# Provision gates on your repo
./scripts/setup-repo.sh your-org/your-repo

# View the 14-phase flow
cat docs/architecture/ai-software-factory.md

# See gate definitions
cat templates/factory/README.md
```

## Why Gates?

Most AI SDLCs lack enforcement. Specs get ignored. Code gets merged without review.

Gates fix this by making each SDLC stage **machine-enforced**, not just convention.

## Open Source Teaser

This repo demonstrates the **GitHub-native gates** portion of the AI-First Software Factory:

- **14-phase flow**: idea → spec → architecture & security review → tickets → test plan → code → test → verify → docs → PR → merge
- **GitHub-native enforcement**: Branch rulesets, CODEOWNERS, required checks, issue templates
- **Spec-first approach**: Product Manager agent creates thin specs with acceptance criteria

## Next Steps

- Read [`docs/architecture/ai-software-factory.md`](docs/architecture/ai-software-factory.md) to understand the 14-phase flow
- Read [`templates/factory/README.md`](templates/factory/README.md) for gate definitions
- Try the Product Manager agent: `.claude/agents/product-manager.md`
- Want the full system? [Contact us](mailto:sales@dataalgebra.engineering) for the commercial version

## What's in here

| Path | What it is |
|---|---|
| `.claude/agents/` | 13 native Claude Code subagents (one per role), with scoped tools |
| `.claude/commands/` | `/post-merge` (archive only - orchestration is closed source) |
| `agents/`, `workflows/` | Human-readable source-of-truth role cards and workflow |
| `templates/` | Spec, ticket, and verification-report templates |
| `templates/factory/` | GitHub enforcement layer — CODEOWNERS, issue + PR templates, rulesets |
| `docs/` | Architecture, getting-started, delivery-ledger |
| `scripts/` | Provisioning scripts (setup gates, labels, project) |
| `knowledge/` | Knowledge base |

## Core invariants (open source)

- No code before an accepted spec and a `Ready` spec gate.
- One ticket = one shippable slice; no unrelated refactors.
- Every acceptance criterion has recorded test evidence.
- Agents open PRs; **humans merge.**
- Gates are checks; **no agent approves its own gate.**

## License

MIT

## Contact

For the full AI-First Software Factory with 14 AI agents, DeepSeek audit integration, and autonomous floor motor:

- Email: sales@dataalgebra.engineering
- Website: https://dataalgebra.engineering
