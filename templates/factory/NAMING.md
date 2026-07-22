# Naming Conventions (gated)

The factory standardizes names across repos, projects, and artifacts, and enforces
them where GitHub supports it. "Hard" = a check blocks; "soft" = template/audit flags.

## Conventions

| Entity | Pattern | Example | Gate |
|---|---|---|---|
| Method/factory repo | `ai-software-factory` | — | audit (soft) |
| Delivery instance repo | `<project>-delivery` | `burnside-aws-marketplace-keys-delivery` | bootstrap + audit (soft) |
| Product/code repo | `product-<name>` | `product-pg-cdc` | bootstrap + audit (soft) |
| Portfolio roadmap repo | `roadmap` | — | audit (soft) |
| GitHub Project | `Burnside — <project> Delivery` | — | convention |
| Epic / Spec | `SPEC-NNN` (3-digit) | `SPEC-005` | CI validator (hard) |
| Ticket | `TICKET-NNN` (3-digit) | `TICKET-044` | CI validator (hard) |
| Spec dir | `specs/<status>/SPEC-NNN-<slug>/` | `specs/draft/SPEC-005-container-marketplace-golive/` | CI validator (hard) |
| Ticket file | `tickets/<state>/TICKET-NNN-<slug>.md` | `tickets/ready/TICKET-044-validate-registerusage-live.md` | CI validator (hard) |
| Branch | `<type>/<slug>` (`feat|fix|chore|docs|refactor|test|perf|ci|factory`) | `feat/spec005-registerusage` | ruleset `branch_name_pattern` (hard) |
| PR title | conventional + references a `TICKET-NNN`/`SPEC-NNN` | `feat: validate RegisterUsage (TICKET-044)` | PR-lint Action (hard) |
| Issue / Epic title | `[EPIC] SPEC-NNN: …` / `[TASK] TICKET-NNN: …` | — | issue templates (soft→hard) |

Allowed repo-name regexes (audit): `^ai-software-factory$`, `^roadmap$`,
`^.+-delivery$`, `^product-.+$`. Legacy exceptions: `license-go`,
`aws-marketplace-keys`.

## Enforcement mechanisms

| File | Enforces |
|---|---|
| `ruleset.naming.json` | branch names (all non-default branches) |
| `.github/workflows/pr-lint.yml` | PR title: conventional + ticket/spec reference (label `skip-ticket` escapes) |
| `.github/workflows/factory-naming.yml` + `scripts/validate-artifacts.sh` | spec/ticket IDs, filenames, front-matter id↔filename match |
| `scripts/audit-org-naming.sh` | org repo names vs the allowed patterns (run scheduled or ad-hoc) |
| `.github/ISSUE_TEMPLATE/{epic,task}.yml` | issue/epic title prefixes |

`setup-repo.sh` applies `ruleset.naming.json` alongside the per-repo gate ruleset.
`bootstrap-project.sh` (in ai-software-factory) should validate the new repo name
against the allowed patterns before creating it.
