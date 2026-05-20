#!/usr/bin/env bash
set -euo pipefail

# This gets all of the comments for a PR, helpful when writing with an agent.
# Expects your environment to have GITHUB_TOKEN with a PAT that can access the API.

if [ -z "${GITHUB_TOKEN:-}" ]; then
  echo "Error: GITHUB_TOKEN environment variable is not set." >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed." >&2
  exit 1
fi

PROJECT="rancher/terraform-rancher2-aws"
PULL_ID=${1:-}

if [ -z "$PULL_ID" ]; then
  echo "Error: PR ID argument is required." >&2
  echo "Usage: $0 <pr-id>" >&2
  exit 1
fi

OWNER=$(echo "$PROJECT" | cut -d/ -f1)
REPO=$(echo "$PROJECT" | cut -d/ -f2)

# The GitHub REST API doesn't expose resolution status. We switch to GraphQL to filter by 'isResolved'.
JSON_PAYLOAD=$(jq -n \
  --arg q 'query($owner: String!, $name: String!, $pr: Int!) { repository(owner: $owner, name: $name) { pullRequest(number: $pr) { reviewThreads(first: 100) { nodes { isResolved comments(first: 50) { nodes { path line diffHunk body } } } } } } }' \
  --arg owner "$OWNER" \
  --arg name "$REPO" \
  --argjson pr "${PULL_ID:-0}" \
  '{ query: $q, variables: { owner: $owner, name: $name, pr: $pr } }')

curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  -X POST -d "$JSON_PAYLOAD" \
  "https://api.github.com/graphql" | \
  jq -r '.data.repository.pullRequest.reviewThreads.nodes[]? | select(.isResolved == false) | .comments.nodes[]? | "File: \(.path)\nLine: \(.line)\nDiff:\n\(.diffHunk)\n\nComment:\n\(.body)\n\n========================================\n"'
