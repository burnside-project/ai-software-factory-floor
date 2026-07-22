#!/usr/bin/env bash
# Create milestones (v0.4.0, v0.5.0).
# Usage: ./milestone-setup.sh <org>
set -euo pipefail

if [ -z "$1" ]; then
  echo "Usage: $0 <org>"
  exit 1
fi

ORG="$1"

echo ">> Creating milestones for $ORG"

# Check gh authentication
if ! gh auth status &> /dev/null; then
  echo "ERROR: Not authenticated with GitHub. Run: gh auth login"
  exit 1
fi

MILESTONES=(
  "v0.4.0|Template pack system and autonomous floor motor"
  "v0.5.0|Enhanced metrics and reporting"
)

for milestone in "${MILESTONES[@]}"; do
  IFS='|' read -r title description <<< "$milestone"
  
  # Check if milestone already exists
  if gh milestone list --owner "$ORG" --json title 2>/dev/null | grep -q "\"title\": \"$title\""; then
    echo "  Milestone already exists: $title"
    continue
  fi
  
  echo "  Creating milestone: $title"
  gh milestone create "$title" --owner "$ORG" --description "$description" --silent
done

echo ""
echo "✓ Created milestones: v0.4.0, v0.5.0"
echo ""
