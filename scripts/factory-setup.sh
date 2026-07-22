#!/usr/bin/env bash
# Template pack setup — single command to create all labels, Project board,
# Discussion categories, and milestones.
set -euo pipefail

echo ">> Template Pack Setup"
echo "This will create:"
echo "  - 30+ labels for workflow stages, gates, priorities, types, status, scope"
echo "  - Project board: AI Factory Delivery Pipeline"
echo "  - Discussion categories: General, Ideas, Announcements, Feedback"
echo "  - Milestones: v0.4.0, v0.5.0"
echo ""

# Check prerequisites
if ! command -v gh &> /dev/null; then
  echo "ERROR: gh CLI not found. Install from https://cli.github.com/"
  exit 1
fi

if ! gh auth status &> /dev/null; then
  echo "ERROR: Not authenticated with GitHub. Run: gh auth login"
  exit 1
fi

# Get org from user
read -p "GitHub Org (e.g., my-org): " ORG
if [ -z "$ORG" ]; then
  echo "ERROR: Org is required"
  exit 1
fi

echo ""
echo "Starting template pack setup for $ORG..."
echo ""

# Step 1: Create labels
echo ">> Creating labels (30+)"
bash "$(dirname "$0")/label-setup.sh" "$ORG"

# Step 2: Create Project board
echo ""
echo ">> Creating Project board"
bash "$(dirname "$0")/project-setup.sh" "$ORG"

# Step 3: Create Discussion categories
echo ""
echo ">> Creating Discussion categories"
bash "$(dirname "$0")/discussion-setup.sh" "$ORG"

# Step 4: Create milestones
echo ""
echo ">> Creating milestones"
bash "$(dirname "$0")/milestone-setup.sh" "$ORG"

echo ""
echo "✓ Template pack setup complete!"
echo ""
echo "Next steps:"
echo "  1. Run: ./scripts/bootstrap-project.sh /path/to/new-project"
echo "  2. Run: ./templates/factory/scripts/setup-repo.sh $ORG/<repo>"
echo "  3. See: templates/factory/ACTIVATE.md for activation checklist"
echo ""
