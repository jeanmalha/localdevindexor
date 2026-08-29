#!/bin/bash
project="$1"
index="$HOME/.dev_projects/index.json"
dev_dir="$HOME/Documents/Dev"
project_path="$dev_dir/$project"

summary=$(jq -r ".[\"$project\"].summary // \"\"" "$index" 2>/dev/null)

echo "$project"
echo "────────────────────────────────────────"

if [[ -n "$summary" ]]; then
  echo "$summary"
else
  echo "(not indexed yet — run: dev-reindex)"
fi

echo ""

# Show git status if it's a repo
if [[ -d "$project_path/.git" ]]; then
  branch=$(git -C "$project_path" branch --show-current 2>/dev/null)
  last_commit=$(git -C "$project_path" log -1 --format="%ar — %s" 2>/dev/null)
  echo "git: $branch | $last_commit"
  echo ""
fi

# List files (use eza if available, fallback to ls)
if command -v eza &>/dev/null; then
  eza --icons --group-directories-first -lh "$project_path" 2>/dev/null | head -20
else
  ls -lhA "$project_path" 2>/dev/null | head -20
fi
