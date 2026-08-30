#!/bin/bash
# Scans ~/Documents/Dev (2 levels deep) and generates summaries via Ollama.
# A directory is a project if it has .git or a project marker file.
# A directory with no markers is treated as a container — its subdirs are indexed instead.

DEV_DIR="$HOME/Documents/Dev"
INDEX="$HOME/.dev_projects/index.json"
MODEL="llama3.2:latest"
OLLAMA_URL="http://localhost:11434/api/generate"
STARS_FILE="$HOME/.dev_projects/stars"

# Prevent concurrent runs from corrupting the index
exec 9>"$HOME/.dev_projects/.reindex.lock"
flock -n 9 || { echo "reindex already running"; exit 0; }

[[ ! -f "$INDEX" ]] && echo '{}' > "$INDEX"

indexed=0
skipped=0

is_project() {
  local dir="$1"
  [[ -d "$dir/.git" ]] && return 0
  for f in package.json go.mod Cargo.toml pyproject.toml README.md CLAUDE.md Makefile main.py main.go index.html; do
    [[ -f "$dir/$f" ]] && return 0
  done
  return 1
}

index_project() {
  local key="$1"      # relative path used as index key, e.g. "mapmaker" or "Product/demo"
  local dir="$2"      # absolute path to project dir
  local summary_file="$dir/.dev-summary.md"

  local is_starred=false
  grep -qxF "$key" "$STARS_FILE" 2>/dev/null && is_starred=true

  last_mod=$(stat -f %m "$dir" 2>/dev/null || stat -c %Y "$dir" 2>/dev/null)
  # For starred git repos, use last commit time so new commits trigger re-indexing
  if $is_starred && [[ -d "$dir/.git" ]]; then
    last_git=$(GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
      git -C "$dir" -c core.fsmonitor= log -1 --format="%ct" 2>/dev/null)
    [[ -n "$last_git" && "$last_git" -gt "$last_mod" ]] && last_mod="$last_git"
  fi
  existing_indexed=$(jq -r --arg k "$key" '.[$k].indexed_at // 0' "$INDEX" 2>/dev/null)
  existing_summary=$(jq -r --arg k "$key" '.[$k].summary // ""' "$INDEX" 2>/dev/null)

  if [[ -n "$existing_summary" && "$last_mod" -le "$existing_indexed" ]]; then
    skipped=$((skipped + 1))
    return
  fi

  # Priority: .dev-summary.md in the project root (user-editable, skips Ollama)
  if [[ -f "$summary_file" ]]; then
    local file_summary
    file_summary=$(grep -v '^[[:space:]]*$' "$summary_file" 2>/dev/null \
      | head -1 | tr -d '\000-\037' | sed 's/^[[:space:]]*//' | cut -c1-100)
    if [[ -n "$file_summary" ]]; then
      now=$(date +%s)
      tmp=$(mktemp "${INDEX}.XXXXXX")
      jq --arg k "$key" --arg path "$dir" --arg summary "$file_summary" --argjson now "$now" \
        '.[$k] = {"path": $path, "summary": $summary, "indexed_at": $now, "source": "file"}' \
        "$INDEX" > "$tmp" && mv "$tmp" "$INDEX"
      echo "  [file] $key → $file_summary"
      indexed=$((indexed + 1))
      return
    fi
  fi

  # Starred projects get more thorough context gathering
  local readme_lines=60 config_lines=20 commit_count=8 tree_lines=25
  $is_starred && { readme_lines=120; config_lines=40; commit_count=20; tree_lines=50; }

  # Gather context — layered by signal strength
  context=""

  # Doc files
  for file in README.md CLAUDE.md README.txt OVERVIEW.md; do
    fp="$dir/$file"
    [[ -f "$fp" ]] && context+="=== $file ===\n$(head -$readme_lines "$fp")\n\n"
  done

  # Config files (name/description fields)
  for file in package.json pyproject.toml go.mod Cargo.toml; do
    fp="$dir/$file"
    [[ -f "$fp" ]] && context+="=== $file ===\n$(head -$config_lines "$fp")\n\n"
  done

  # Git log (commit messages are often the best description)
  if [[ -d "$dir/.git" ]]; then
    gitlog=$(GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
      git -C "$dir" -c core.fsmonitor= log --oneline -$commit_count 2>/dev/null)
    [[ -n "$gitlog" ]] && context+="=== Recent commits ===\n$gitlog\n\n"
  fi

  # Peek at main source files if no context yet (always for starred)
  if $is_starred || [[ -z "$context" ]]; then
    for file in main.py app.py index.js main.go main.ts index.ts src/main.py src/app.py; do
      fp="$dir/$file"
      if [[ -f "$fp" ]]; then
        context+="=== $file (first 30 lines) ===\n$(head -30 "$fp")\n\n"
        break
      fi
    done
  fi

  # File tree as last resort
  filetree=$(find "$dir" -maxdepth 2 \
    -not -path '*/.*' \
    -not -path '*/node_modules/*' \
    -not -path '*/__pycache__/*' \
    -not -path '*/venv/*' \
    -not -path '*/dist/*' \
    2>/dev/null | sed "s|$dir/||" | sort | head -$tree_lines)
  [[ -n "$filetree" ]] && context+="=== File tree ===\n$filetree\n"

  # If truly empty, note that
  [[ -z "$context" ]] && context="(empty directory — no files found)"

  system="You are a terse project summarizer. You ALWAYS output exactly one sentence under 80 characters describing what this project does. You NEVER ask for clarification. You NEVER say you lack information. When context is sparse, infer from the project name and file names. Output only the summary sentence, nothing else."
  prompt="Project name: $key\n\n$context"

  response=$(curl -sf "$OLLAMA_URL" \
    -H "Content-Type: application/json" \
    -d "{\"model\":\"$MODEL\",\"system\":$(echo "$system" | jq -Rs .),\"prompt\":$(echo "$prompt" | jq -Rs .),\"stream\":false}" 2>/dev/null)

  if [[ $? -ne 0 || -z "$response" ]]; then
    echo "  [skip] $key — Ollama unavailable"
    return
  fi

  # Strip control characters (incl. ANSI escapes) before storing
  summary=$(echo "$response" | jq -r '.response // empty' \
    | tr -d '\000-\037' | sed 's/^[[:space:]]*//' | cut -c1-100)
  [[ -z "$summary" ]] && { echo "  [skip] $key — empty model response"; return; }
  now=$(date +%s)

  # For starred projects, capture recent commits with dates for the preview panel
  local recent_commits_json="null"
  if $is_starred && [[ -d "$dir/.git" ]]; then
    local recent_commits
    recent_commits=$(GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
      git -C "$dir" -c core.fsmonitor= log --format="%ad  %s" --date=short -10 2>/dev/null)
    [[ -n "$recent_commits" ]] && recent_commits_json=$(printf '%s' "$recent_commits" | jq -Rs .)
  fi

  # Write to .dev-summary.md so the user can edit it, and gitignore it by default
  printf '%s\n' "$summary" > "$summary_file"
  local gitignore="$dir/.gitignore"
  if [[ -f "$gitignore" ]] && ! grep -qxF '.dev-summary.md' "$gitignore"; then
    printf '\n.dev-summary.md\n' >> "$gitignore"
  fi

  # mktemp on same filesystem as INDEX so mv is atomic
  tmp=$(mktemp "${INDEX}.XXXXXX")
  jq --arg k "$key" --arg path "$dir" --arg summary "$summary" --argjson now "$now" \
    --argjson commits "$recent_commits_json" \
    '.[$k] = {"path": $path, "summary": $summary, "indexed_at": $now, "source": "ai"} |
     if $commits != null then .[$k].recent_commits = $commits else . end' \
    "$INDEX" > "$tmp" && mv "$tmp" "$INDEX"

  echo "  [ai]   $key → $summary"
  indexed=$((indexed + 1))
}

# Track which keys were seen this run — remove stale entries afterward
seen_keys=()

for top_dir in "$DEV_DIR"/*/; do
  [[ ! -d "$top_dir" ]] && continue
  top_name=$(basename "$top_dir")
  [[ "$top_name" == .* ]] && continue

  if is_project "$top_dir"; then
    seen_keys+=("$top_name")
    index_project "$top_name" "$top_dir"
  else
    # Container: look one level deeper for sub-projects
    found_sub=false
    for sub_dir in "$top_dir"/*/; do
      [[ ! -d "$sub_dir" ]] && continue
      sub_name=$(basename "$sub_dir")
      [[ "$sub_name" == .* ]] && continue
      if is_project "$sub_dir"; then
        key="$top_name/$sub_name"
        seen_keys+=("$key")
        index_project "$key" "$sub_dir"
        found_sub=true
      fi
    done
    # If nothing matched inside, index the container itself
    if ! $found_sub; then
      seen_keys+=("$top_name")
      index_project "$top_name" "$top_dir"
    fi
  fi
done

# Remove stale keys (projects that no longer exist)
current_keys=$(jq -r 'keys[]' "$INDEX" 2>/dev/null)
while IFS= read -r key; do
  found=false
  for seen in "${seen_keys[@]}"; do
    [[ "$seen" == "$key" ]] && found=true && break
  done
  if ! $found; then
    tmp=$(mktemp "${INDEX}.XXXXXX")
    jq --arg k "$key" 'del(.[$k])' "$INDEX" > "$tmp" && mv "$tmp" "$INDEX"
    echo "  [rm]   $key (no longer exists)"
  fi
done <<< "$current_keys"

echo ""
echo "Done: $indexed indexed, $skipped skipped (up to date)"
