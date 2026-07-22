#!/usr/bin/env bash
# Create Project board (AI Factory Delivery Pipeline).
# Usage: ./project-setup.sh <org>
set -euo pipefail

if [ -z "$1" ]; then
  echo "Usage: $0 <org>"
  exit 1
fi

ORG="$1"

echo ">> Creating Project board for $ORG"

# Check gh authentication
if ! gh auth status &> /dev/null; then
  echo "ERROR: Not authenticated with GitHub. Run: gh auth login"
  exit 1
fi

PROJECT_TITLE="AI Factory Delivery Pipeline"

# Check if project already exists
if gh project view --owner "$ORG" --json title 2>/dev/null | grep -q "$PROJECT_TITLE"; then
  echo "  Project already exists: $PROJECT_TITLE"
  echo "  View at: https://github.com/orgs/$ORG/projects"
  exit 0
fi

# Create the Project board
echo "  Creating Project: $PROJECT_TITLE"
gh project create "$PROJECT_TITLE" --owner "$ORG" --body "AI Factory Delivery Pipeline — Track features from idea to production" --readme "## AI Factory Delivery Pipeline

Track features from idea to production using the AI-First Software Factory.

### Stages
- Brief: Idea definition
- Spec: Specification writing
- Architecture: Architecture review
- Security: Security review
- Tickets: Task breakdown
- Test Plan: Test planning
- Code: Implementation
- Test: Running tests
- Verify: Verification
- Audit: Independent audit
- Review: Human review
- Deploy: Deployment"

# Add fields to the Project
echo "  Adding fields to Project..."

# Stage field (single-select)
gh project field-create "$PROJECT_TITLE" --owner "$ORG" --name "Stage" --single-select "Brief,Spec,Architecture,Security,Tickets,Test Plan,Code,Test,Verify,Audit,Review,Deploy"

# Spec field (text)
gh project field-create "$PROJECT_TITLE" --owner "$ORG" --name "Spec" --text

# Repo field (text)
gh project field-create "$PROJECT_TITLE" --owner "$ORG" --name "Repo" --text

# Owner/Agent field (text)
gh project field-create "$PROJECT_TITLE" --owner "$ORG" --name "Owner/Agent" --text

# Iteration field (text)
gh project field-create "$PROJECT_TITLE" --owner "$ORG" --name "Iteration" --text

# Risk field (single-select)
gh project field-create "$PROJECT_TITLE" --owner "$ORG" --name "Risk" --single-select "Low,Medium,High,Critical"

# Gate field (single-select)
gh project field-create "$PROJECT_TITLE" --owner "$ORG" --name "Gate" --single-select "Blocked,Pending,Passed"

# Work Type field (single-select)
gh project field-create "$PROJECT_TITLE" --owner "$ORG" --name "Work Type" --single-select "Spec,Ticket,Epic,Bug,Feature Request"

# Priority field (single-select)
gh project field-create "$PROJECT_TITLE" --owner "$ORG" --name "Priority" --single-select "P0,P1,P2,P3"

echo ""
echo "✓ Project board created: $PROJECT_TITLE"
echo "  View at: https://github.com/orgs/$ORG/projects"
echo ""
