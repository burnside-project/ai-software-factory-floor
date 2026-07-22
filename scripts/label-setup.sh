#!/usr/bin/env bash
# Create all labels for workflow stages, gates, priorities, types, status, scope.
# Usage: ./label-setup.sh <org>
set -euo pipefail

if [ -z "$1" ]; then
  echo "Usage: $0 <org>"
  exit 1
fi

ORG="$1"

echo ">> Creating labels for $ORG"

# Check gh authentication
if ! gh auth status &> /dev/null; then
  echo "ERROR: Not authenticated with GitHub. Run: gh auth login"
  exit 1
fi

# Labels that are NOT part of the Stage line
while IFS='|' read -r name color desc; do
  case "$name" in ''|\#*) continue ;; esac
  echo "  Creating label: $name"
  gh label create "$name" --repo "$ORG/ai-software-factory" --color "$color" --description "$desc" --force
done <<'LABELS'
# lifecycle
epic|6f42c1|SPEC-XXX umbrella
task|0e8a16|TICKET-XXX work item
gate:blocked|b60205|a required gate is failing
audit:pass|0e8a16|audit cleared
audit:fail|b60205|audit found blocking issues
incident|d93f0b|from Observe stage
skip-ticket|ededed|bypass the PR ticket-reference check
# type:* — one row per option of the board's "Work Type" single-select field
type:spec|6f42c1|Type=Spec — a SPEC-XXX specification issue
type:ticket|6f42c1|Type=Ticket — a TICKET-XXX work item
type:epic|6f42c1|Type=Epic — a multi-spec umbrella
type:bug|6f42c1|Type=Bug — a defect report
type:feature-request|6f42c1|Type=Feature Request — pre-spec intake
# priority:* — one row per option of the board's "Priority" single-select field
priority:p0|d93f0b|Priority=P0 — production break or security issue
priority:p1|f97583|Priority=P1 — major feature blocked
priority:p2|fef2c0|Priority=P2 — important but not urgent
priority:p3|fef2c0|Priority=P3 — nice to have
# stage:* — one row per stage in the delivery pipeline
stage:spec|fbca04|Spec phase — being written
stage:arch|c5def5|Architecture review
stage:security|bfe5bf|Security review
stage:ticket|f9d0c4|Tickets being created
stage:plan|e1f6ff|Test plan
stage:code|fbca04|Code phase — being implemented
stage:test|c5def5|Test phase — running tests
stage:verify|bfe5bf|Verify phase — verification doc
stage:audit|f9d0c4|Audit phase — under auditor review
stage:review|1d76db|Review phase — waiting on human
stage:done|5319e7|Done phase — merged and closed
LABELS

echo ""
echo "✓ Created 30+ labels"
echo ""
