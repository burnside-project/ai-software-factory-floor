# AI Engineering Automation Pipeline

Production-ready autonomous repository audit, feature planning, implementation, and deployment workflow powered by AI coding agents.

---

## Overview

This project turns AI coding agents into a structured engineering workflow.

Instead of allowing an agent to freely modify an entire repository, this pipeline introduces:

- Repository auditing
- Spec generation
- Controlled feature implementation
- Git worktree isolation
- Human review boundaries
- Safe deployment workflows

The result is a safer and more scalable approach to AI-assisted software engineering.

![audit](audit.png)


---

# Architecture

```text
Existing Repository
        │
        ▼
┌─────────────────────┐
│   AI Repository     │
│      Audit          │
└─────────────────────┘
        │
        ▼
┌─────────────────────┐
│ Markdown Audit      │
│ Report Generation   │
└─────────────────────┘
        │
        ▼
┌─────────────────────┐
│ AI Feature Planner  │
│ Generates Specs     │
└─────────────────────┘
        │
        ▼
┌────────────────────────────────────┐
│ One Git Worktree Per Feature Spec │
└────────────────────────────────────┘
        │
        ▼
┌─────────────────────┐
│ AI Feature          │
│ Implementation      │
└─────────────────────┘
        │
        ▼
┌─────────────────────┐
│ Human Review        │
│ + Merge             │
└─────────────────────┘
        │
        ▼
┌─────────────────────┐
│ Local / Remote      │
│ Deployment          │
└─────────────────────┘
```

---

# Why This Exists

Most AI coding workflows today are:

- prompt-driven
- unstructured
- difficult to review
- unsafe for production repositories

This project introduces engineering discipline into AI-assisted development.

---

# Key Features

- AI-powered repository auditing
- Markdown-based implementation specs
- Git worktree isolation per feature
- Parallel feature implementation
- Structured deployment pipeline
- Human-review-first workflow
- Docker deployment support
- Local and remote deployment modes
- JSONL audit and execution logs

---

# Repository Structure

```text
project/
├── automate.sh
├── audit/
│   └── reports/
├── features/
│   ├── 01-example.md
│   ├── 02-example.md
│   ├── HUMAN-ACTIONS.md
│   └── DEFERRED.md
├── logs/
│   └── automate/
├── docker-compose.yml
└── application-source/
```

---

# Requirements

## Required Software

- Bash
- Git
- Docker
- Docker Compose
- jq
- rsync
- SSH
- Claude CLI

---

# Installation

## Clone Repository

```bash
git clone <repo-url>
cd <repo>
```

## Make Script Executable

```bash
chmod +x automate.sh
```

---

# Workflow Stages

## 1. Audit

```bash
./automate.sh audit
```

Generates:

```text
audit/reports/YYYY-MM-DD.md
```

---

## 2. Feature Planning

```bash
./automate.sh plan-features
```

Outputs implementation specs.

---

## 3. Feature Implementation

```bash
./automate.sh features
```

Creates isolated Git worktrees per feature.

---

## 4. Deployment

### Local

```bash
./automate.sh deploy
```

### Remote

```bash
DEPLOY_REMOTE=1 \
REMOTE_HOST=my-server \
REMOTE_PATH=/srv/my-app \
./automate.sh deploy
```

---

# Full Pipeline

```bash
./automate.sh all
```

---

# Safety Model

This workflow intentionally separates:

## AI-Safe Tasks

- isolated code fixes
- test generation
- validation improvements
- dependency updates

## Human-Governed Tasks

- credential rotation
- production infrastructure
- compliance decisions
- large architecture changes

---

# Philosophy

AI should not replace engineering discipline.

AI should strengthen engineering workflows.

```text
AI coding is useful.

AI engineering is transformational.
```

---

# License

MIT License
