#!/usr/bin/env bash
# Create Discussion categories (General, Ideas, Announcements, Feedback).
# Usage: ./discussion-setup.sh <org>
set -euo pipefail

if [ -z "$1" ]; then
  echo "Usage: $0 <org>"
  exit 1
fi

ORG="$1"

echo ">> Creating Discussion categories for $ORG"

# Check gh authentication
if ! gh auth status &> /dev/null; then
  echo "ERROR: Not authenticated with GitHub. Run: gh auth login"
  exit 1
fi

CATEGORIES=(
  "General|We discuss anything and everything.|discussions"
  "Ideas|Share and vote on product ideas.|ideas"
  "Announcements|Important updates and releases.|announcements"
  "Feedback|Provide feedback on our products and services.|feedback"
)

for category in "${CATEGORIES[@]}"; do
  IFS='|' read -r name description emoji <<< "$category"
  
  # Check if category already exists
  if gh api "orgs/$ORG/discussions" --jq '.[].category.name' 2>/dev/null | grep -q "^${name}$"; then
    echo "  Category already exists: $name"
    continue
  fi
  
  echo "  Creating category: $name"
  gh api "orgs/$ORG/discussion_categories" \
    --method POST \
    --field "name=$name" \
    --field "description=$description" \
    --field "emoji=$emoji" \
    --silent >/dev/null
done

echo ""
echo "✓ Created Discussion categories"
echo "  View at: https://github.com/orgs/$ORG/discussions"
echo ""
