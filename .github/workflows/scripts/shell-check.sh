#!/bin/bash
set -e

# Find files with shebangs, excluding .terraform, .git, node_modules, and non-shell files
FILES_WITH_SHEBANG=$(grep -Rl -e '^#!' --exclude-dir=".terraform" --exclude-dir=".git" --exclude-dir="node_modules" --exclude="*.md" --exclude="*.js" . || true)

# Find all .sh files in .github/workflows/scripts/
WORKFLOW_SCRIPTS=$(find .github/workflows/scripts -type f -name "*.sh" 2>/dev/null || true)

# Combine and get unique files
ALL_FILES=$(echo -e "${FILES_WITH_SHEBANG}\n${WORKFLOW_SCRIPTS}" | sort -u | grep -v '^$')

while read -r file; do
  if [ -n "$file" ]; then
    echo "checking $file..."
    shellcheck -x "$file"
  fi
done <<< "$ALL_FILES"
