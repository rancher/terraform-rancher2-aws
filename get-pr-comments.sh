# This gets all of the comments for a PR, helpful when writing with an agent.
# Expects your environment to have GITHUB_TOKEN with a PAT that can access the API.
PROJECT="rancher/terraform-rancher2-aws"
PULL_ID=$1
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/$PROJECT/pulls/${PULL_ID}/comments" | \
  jq -r '.[] | "File: \(.path)\nLine: \(.line)\nDiff:\n\(.diff_hunk)\n\nComment:\n\(.body)\n\n========================================\n"'
