#!/bin/bash
project="$1"
index="$HOME/.dev_projects/index.json"
stars_file="$HOME/.dev_projects/stars"

project_path=$(jq -r --arg k "$project" '.[$k].path // ""' "$index" 2>/dev/null)
[[ -z "$project_path" ]] && project_path="$HOME/Documents/Dev/$project"

summary=$(jq -r --arg k "$project" '.[$k].summary // ""' "$index" 2>/dev/null)
starred=""
grep -qxF "$project" "$stars_file" 2>/dev/null && starred=" ★"

echo "$project$starred"
echo "────────────────────────────────────────"

if [[ -n "$summary" ]]; then
  echo "$summary"
else
  echo "(not indexed yet — run: dev-reindex)"
fi

echo ""

# Show git info if it's a repo
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
