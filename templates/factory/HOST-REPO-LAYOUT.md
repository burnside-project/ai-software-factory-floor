# Host Repo Layout — `your-org/roadmap`

The cross-cutting home that the per-code-repo model needs (Issues can't be
repo-less; cross-repo Epics + the method need somewhere to live). Created by
`scripts/setup-host-repo.sh --apply`.

## What it holds

```
roadmap/                      (= today's delivery workspace, pushed)
  .ai/                        the factory method: agents, templates, workflows  ← engine, now backed up
  docs/
    architecture/             ai-software-factory.md (the model)
    briefs/                   BRIEF-XXX.md            ← Product Brief stage
    specs.md, delivery-ledger.md
  specs/                      cross-repo specs (drafts/implementing/completed)
  tickets/                    ticket files (canonical; synced to Issues in their repo:)
  verification/               cross-repo verification index
  knowledge/                  features.yaml etc.
  repos/                      (gitignored) local checkouts of code repos
```

Issues hosted here: **cross-repo Epics** (one per SPEC-XXX) and **Briefs**.
Per-repo Tasks live in their code repo (`repo:` front-matter) but appear as
sub-issues of the host Epic and on the one org Project.

## Why a dedicated repo (vs `.github`)

- `.github` is fine too — same scripts, set `HOST_REPO=.github`.
- A named `roadmap` repo reads better in the org repo list and keeps the
  delivery method/history as a first-class, reviewable repo (PRs on specs work).

## Relationship to code repos

```
roadmap (host)                aws-marketplace-keys / license-go / pg-cdc
  Epic #(SPEC-005) ───────────▶ sub-issue Task #(TICKET-044)  [repo: amk]
  spec.md / brief (files)        code + PR + CI gates + Release
        \___________________ org Project (spans all) ___________________/
```

## .gitignore note

`repos/` (local code checkouts) must stay ignored — the code lives in its own
repos, not vendored here. Confirm `.gitignore` excludes `repos/` before the first
push (it already does in the current workspace).
