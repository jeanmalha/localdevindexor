#!/usr/bin/env bats

load helpers

setup() {
  setup_test_home
  # Symlink the real scripts into test HOME's PATH so subshells find them
  export INDEX="$HOME/.dev_projects/index.json"
  export DEV_DIR="$HOME/Documents/Dev"
}
teardown() { teardown_test_home; }

SCRIPT="$ROOT/reindex.sh"

run_reindex() {
  # Run with test HOME so DEV_DIR and INDEX resolve to test dirs
  HOME="$TEST_HOME" bash "$SCRIPT" "$@"
}

@test "reads .dev-summary.md and skips Ollama" {
  proj=$(make_project "myapp")
  touch "$proj/README.md"
  echo "My hand-written description." > "$proj/.dev-summary.md"

  run run_reindex
  [ "$status" -eq 0 ]
  [[ "$output" == *"[file]"* ]]
  stored=$(jq -r '.myapp.summary' "$INDEX")
  [ "$stored" = "My hand-written description." ]
}

@test "source field is 'file' when .dev-summary.md is used" {
  proj=$(make_project "myapp")
  touch "$proj/README.md"
  echo "Hand-written." > "$proj/.dev-summary.md"

  run_reindex
  source=$(jq -r '.myapp.source' "$INDEX")
  [ "$source" = "file" ]
}

@test "writes .dev-summary.md after AI generation" {
  mock_ollama "AI-generated summary."
  proj=$(make_project "myapp")
  touch "$proj/README.md"

  run run_reindex
  [ -f "$proj/.dev-summary.md" ]
  content=$(cat "$proj/.dev-summary.md")
  [ -n "$content" ]
}

@test "source field is 'ai' after Ollama generation" {
  mock_ollama "AI summary."
  proj=$(make_project "myapp")
  touch "$proj/README.md"

  run_reindex
  source=$(jq -r '.myapp.source' "$INDEX")
  [ "$source" = "ai" ]
}

@test "removes stale index entries for projects no longer on disk" {
  add_to_index "ghost" "/nonexistent/path" "Gone project"

  run run_reindex
  [ "$status" -eq 0 ]
  result=$(jq -r '.ghost' "$INDEX")
  [ "$result" = "null" ]
}

@test "detects a git repo as a project" {
  proj=$(make_project "gitapp")
  mkdir "$proj/.git"
  echo "Git project summary." > "$proj/.dev-summary.md"

  run run_reindex
  [ "$status" -eq 0 ]
  result=$(jq -r '.gitapp.summary' "$INDEX")
  [ "$result" = "Git project summary." ]
}

@test "skips already-indexed unchanged projects" {
  proj=$(make_project "myapp")
  touch "$proj/README.md"
  echo "Stable summary." > "$proj/.dev-summary.md"

  run_reindex   # first run — indexes it
  run run_reindex  # second run — should skip
  [[ "$output" == *"skipped"* ]]
}
