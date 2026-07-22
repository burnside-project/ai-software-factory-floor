Runbook: Ongoing Building Projects

Purpose

This runbook provides a structured process for building and maintaining projects using the AI delivery system and its agents. It outlines how to initiate a new feature, manage the lifecycle of development artifacts (specs, tickets, tests, and documentation), and ensure consistent delivery standards across multiple repositories.

Scope

This document covers the per-feature delivery loop only (idea → PR → merge). One-time repo setup — provisioning the factory, landing `.github/` + CODEOWNERS, and activating the GitHub enforcement gates (rulesets flip from `evaluate` to `active`) — is out of scope here and lives in PROVISIONING.md, the single canonical onboarding runbook. For operating the native Claude Code flow, RUNBOOK-claude-code.md is the current "Start here"; this prose overview mirrors the same delivery flow.

Workflow Overview

Here's the complete A-to-Z provisioning workflow:
A-to-Z Provisioning Workflow

Phase 0: Prerequisites (run from ai-software-factory repo)
cd /Applications/my_projects/dataalgebra_AI_POC/ai-software-factory
./scripts/check-readiness.sh
Verify: gh authenticated with project,read:org,repo scopes, jq and openssl installed.

Phase 1: One-time per GitHub org (run from ai-software-factory repo)
1.1 Create GitHub App builder

# Follow the interactive steps in:

open https://github.com/orgs/dataalgebra-engineering/settings/apps/new

# Or run: templates/factory/RUNBOOK-github-app.md

Artifact: GitHub App installed with Workflows: write permission.

1.2 Set up CODEOWNERS teams
templates/factory/scripts/setup-teams.sh --create
Verify: All teams referenced by CODEOWNERS exist and are non-empty.

1.3 Create host/tracking repo
templates/factory/scripts/setup-host-repo.sh --dry-run # review plan
templates/factory/scripts/setup-host-repo.sh --apply # create

1.4 Create org Project
templates/factory/scripts/setup-project.sh
Verify: Project exists with Stage and Spec fields.

Phase 2: Per-repo provisioning (run from ai-software-factory repo)

2.1 Provision the repo
./scripts/provision.sh dataalgebra-engineering/burnside-project-my-dial-pad-web
Verify: Labels created, rulesets in evaluate mode, .ai/ method installed.

2.2 Flip rulesets to enforcing
ENFORCEMENT=active ./templates/factory/scripts/setup-repo.sh dataalgebra-engineering/burnside-project-my-dial-pad-web
Verify: Rulesets show active in GitHub Settings ▸ Rules.

2.3 Add production environment reviewer

- Go to repo Settings ▸ Environments ▸ production
- Add required reviewers (minimum 1 human)
- (Optional) Set wait timer

2.4 Seed sync-issues.yml workflow (optional, for board auto-sync)

# Copy manually or use --stage-files:

./templates/factory/scripts/setup-repo.sh dataalgebra-engineering/burnside-project-my-dial-pad-web --stage-files

# Then merge the open PR

Phase 3: Verify gates are working

3.1 Open a test PR

- Create a branch
- Make a small change
- Open a PR to main

3.2 Verify required checks run:

- lint ✓
- test ✓
- build ✓
- verification ✓
- audit ✓
- CODEOWNERS review requested ✓

3.3 Verify gates block:

- Force-push blocked ✓
- Branch protection enforced ✓

Phase 4: Deliver first feature

4.1 Open Claude Code in the project
cd /Applications/my_projects/dataalgebra_AI_POC/burnside-project-my-dial-pad-web
claude

4.2 Run feature delivery
/feature-delivery <your feature idea>

4.3 After human approval and merge
/post-merge SPEC-XXX
Key Files Reference
File Purpose
PROVISIONING.md This canonical runbook
README.md Project overview, links to provisioning
runbook.md OUTDATED - delivery flow only, missing provisioning
RUNBOOK-claude-code.md Day-to-day operation with Claude Code
templates/factory/ACTIVATE.md Go-live checklist
scripts/provision.sh Single-command orchestrator
scripts/check-readiness.sh Pre-flight check
"Am I done?" Checklist

- check-readiness.sh exits 0
- GitHub App installed and working
- setup-teams.sh passed (all CODEOWNERS teams exist)
- provision.sh completed successfully
- Rulesets are active (not evaluate)
- production environment has required reviewers
- Test PR shows required checks + CODEOWNERS review

Follow this workflow for each new feature or project:

1. Intake & Feature Request: Create a feature request document that captures the problem, goal, user stories, and acceptance criteria. Place it in specs/draft with a unique feature ID.

2. Spec Creation: Use the Product Manager agent to refine the feature request into a detailed specification. Include problem statement, goal, non-goals, user stories, scope, repos affected, data impact, security/governance impact, acceptance criteria, test plan, documentation impact, rollback plan, risks, and open questions.

3. Architecture Review: Use the Architect agent to review the spec — repo boundaries, interfaces, contracts, data models, and any architecture decision records (ADRs).

4. Security Review: Use the Security Architect agent to review secrets management, IAM roles, authentication/authorization flows, audit requirements, and compliance.

5. Ticket Planning: Use the Tech Lead agent to break the spec into small, incremental tickets. Each ticket should include a user story, task description, repos and files affected, dependencies, acceptance criteria, and a clear definition of done.

6. Test Planning: The QA Engineer agent creates a test plan (unit tests, integration tests, and Docker/local tests) in verification/test-plans/. Identify failure handling and expected outcomes.

7. Spec Gate: Before any implementation, confirm the spec is approved and scoped — the agile-spec-builder gate must pass (spec reviewed, sliced into small increments, acceptance criteria agreed). Implementation begins only against an approved spec; this is a gate, not a formality.

8. Implementation: Developers work on the tickets. The Backend Engineer and Data Engineer follow the spec and tickets precisely, without scope changes or unrelated refactors. They run local tests and Docker-based integration tests to ensure changes meet acceptance criteria.

9. Verification: The Test Engineer runs the test plan and records results in verification/results/.

10. Audit: The Auditor reviews the diff for bugs, security vulnerabilities, architecture drift, edge cases, and missing tests. Produces an audit report with blocking/non-blocking issues. Blocking issues must be fixed before proceeding to PR.

11. Documentation & Knowledge Update: Update user-facing documentation (README, runbooks), architecture docs, and ADRs. Record the delivery in docs/delivery-ledger.md and update knowledge files (knowledge/features.yaml, knowledge/tests.yaml, knowledge/repos.yaml).

12. Pull Request: Use the Release Engineer to create a PR. The PR must reference the spec, list completed tickets, include test results, the audit report, and documentation updates, and provide rollback instructions.

13. Compliance Gate: The Compliance Reviewer confirms the spec, tickets, tests, documentation, and PR are complete, consistent, and free of unrelated scope. This is the final gate before a human-approved merge — stop and wait for human approval before merging.

14. Post-Merge Archive: After the PR is merged, move the spec to specs/completed, archive verification results, update the ledger and knowledge files, and ensure no active tickets remain for that spec.

Intake & Spec Creation

Create a Feature Request

1. Use the feature request template in .ai/prompts (e.g., feature-request-template.md).

2. Fill out the fields: title, problem, user, first useful version, non-goals, expected interface (CLI/API/UI), example usage, data impact, security impact, test expectations, and definition of done.

3. Save the feature request in specs/draft/ with a unique feature ID (e.g., SPEC-001-aws-marketplace-agent.md).

Product Manager Intake

The Product Manager agent prompts you to answer the intake questionnaire:

- Project identity: Name, new or existing repo, open source vs. commercial.
- Problem: What hurts today and why now.
- First useful outcome: What is the smallest useful version and what should not be included.
- Repo boundary: Which repos are affected, shared contracts, and what should not be coupled.
- Interface: Type of interface (CLI, API, web UI), inputs/outputs.
- Data: What data is read or written, schema changes, versioning.
- Security & governance: Secrets, IAM, permissions, audit logging, tenant isolation.
- Verification: How to prove it works (commands, tests).
- Agile slicing: Identify the first 1–2 day slices and what can be deferred.

The Product Manager agent consolidates these answers into a draft spec.

Architecture & Security Review

- Architect Agent: Reviews repo boundaries, data models, interfaces, contracts, and ADRs. Updates docs/decisions with ADRs if necessary.
- Security Architect Agent: Reviews secrets handling, IAM roles, authentication/authorization flows, audit requirements, and compliance.

Both agents produce documents stored next to the spec (e.g., specs/draft/SPEC-001/architecture-review.md and specs/draft/SPEC-001/security-review.md).

Ticket Creation & Agile Slicing

- Tech Lead Agent: Breaks the spec into discrete, small tickets (1–3 day slices). Each ticket lives in tickets/ready with a unique ID (e.g., TICKET-001-create-dynamo-table.md).
- Tickets should have clear acceptance criteria, dependencies, and definitions of done. They reference the spec ID.
- The Tech Lead sets an implementation order based on dependencies.

Implementation & Local Testing

- Developers: Work only on assigned tickets. If they discover scope creep or unclear requirements, they raise issues back to the Tech Lead and Product Manager.
- Developers run unit tests and integration tests. Use make verify or make test-docker as defined in your Makefile.
- The Data Engineer ensures data model changes (e.g., DynamoDB table creation) are applied correctly.

Verification & PR Creation

- Test Engineer: Executes the QA test plan. Records test results in verification/results/ and cross-checks acceptance criteria.
- Documentation Writer: Updates user guides, runbooks, and architecture docs as needed.
- Release Engineer: Creates a new branch (feature/SPEC-001-aws-marketplace-agent), commits code, updates spec and tickets with evidence, and opens a PR.
- Compliance Reviewer: Ensures the PR references the spec, includes test evidence, has no unrelated changes, and that documentation is up to date.

Ongoing Maintenance

- Monitoring & Alerts: The SRE agent sets up monitoring, logging, and alerting for new features (e.g., DynamoDB table usage, AWS API errors, Stripe subscription checks).
- Rotating Keys: Implement key rotation logic for the API key system. Keys expire after 30 days, with grace periods and automated renewal if subscription is active.
- Subscription Checks: Integrate with Stripe API to validate active subscriptions. If delinquent, deny API key validation requests.
- Rollback & Mitigation: Define rollback procedures in the spec. Keep backups of data and configurations.

Example: AWS Marketplace Integration

For your AWS Marketplace agent:

1. Feature Request: Create SPEC-001-aws-marketplace-agent.md detailing the need to publish SaaS products on AWS Marketplace, create API keys via DynamoDB, and validate subscriptions via Stripe.

2. Spec: Fill in the spec template with: DynamoDB schema, 30‑day key expiration, Stripe webhook integration for subscription status, multi‑cloud deployment considerations (on‑prem, AWS, GCP), and security implications.

3. Ticket Slicing: Break into tickets such as:
   - Create DynamoDB table for keys
   - Implement key issuance API (Lambda or container)
   - Integrate AWS Marketplace publishing workflow via Partner Central
   - Add Stripe subscription check
   - Write unit & integration tests
   - Write user documentation and runbook entry

4. Implementation & Verification: Implement each ticket, run Docker tests, and verify with the Test Engineer.

5. Delivery: Document the completed feature in docs/delivery-ledger.md, update knowledge/features.yaml, and ensure all files are archived in specs/completed after merge.

Summary

This runbook defines how to systematically move from idea to production using your AI delivery system and agents. By following these steps—intake, spec creation, architecture/security review, ticket slicing, implementation, verification, documentation, PR creation, and post‑merge archival—you ensure that features like your AWS Marketplace integration are delivered consistently and reliably.
