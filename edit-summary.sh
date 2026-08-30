#!/bin/bash
# Opens .dev-summary.md for the selected project in $EDITOR,
# then immediately updates the index so the fzf list reflects the change.
key="$1"
index="${HOME}/.dev_projects/index.json"

project_path=$(jq -r --arg k "$key" '.[$k].path // ""' "$index" 2>/dev/null)
[[ -z "$project_path" ]] && project_path="${HOME}/Documents/Dev/$key"

summary_file="$project_path/.dev-summary.md"

# Seed the file with the current summary if it doesn't exist yet
if [[ ! -f "$summary_file" ]]; then
  current=$(jq -r --arg k "$key" '.[$k].summary // ""' "$index" 2>/dev/null)
  printf '%s\n' "$current" > "$summary_file"
  # Gitignore it by default
  gitignore="$project_path/.gitignore"
  if [[ -f "$gitignore" ]] && ! grep -qxF '.dev-summary.md' "$gitignore"; then
    printf '\n.dev-summary.md\n' >> "$gitignore"
  fi
fi

${EDITOR:-nano} "$summary_file"

# Read the first non-empty line back and update the index immediately
new_summary=$(grep -v '^[[:space:]]*$' "$summary_file" 2>/dev/null | head -1 \
  | tr -d '\000-\037' | sed 's/^[[:space:]]*//' | cut -c1-100)

if [[ -n "$new_summary" ]]; then
  now=$(date +%s)
  tmp=$(mktemp "${index}.XXXXXX")
  jq --arg k "$key" --arg s "$new_summary" --argjson now "$now" \
    '.[$k].summary = $s | .[$k].indexed_at = $now | .[$k].source = "file"' \
    "$index" > "$tmp" && mv "$tmp" "$index"
fi
