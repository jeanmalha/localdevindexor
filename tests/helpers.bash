#!/usr/bin/env bash
# Shared test helpers — sourced by each .bats file via `load helpers`

ROOT="$(cd "$(dirname "${BATS_TEST_FILENAME}")/.." && pwd)"

setup_test_home() {
  TEST_HOME=$(mktemp -d)
  export HOME="$TEST_HOME"
  mkdir -p "$TEST_HOME/.dev_projects"
  touch "$TEST_HOME/.dev_projects/stars"
  echo '{}' > "$TEST_HOME/.dev_projects/index.json"
  mkdir -p "$TEST_HOME/Documents/Dev"
}

teardown_test_home() {
  rm -rf "$TEST_HOME"
}

# Create a project directory under the test Dev folder and return its path
make_project() {
  local name="$1"
  local dir="$TEST_HOME/Documents/Dev/$name"
  mkdir -p "$dir"
  echo "$dir"
}

# Add a project entry to the test index
add_to_index() {
  local key="$1" path="$2" summary="${3:-Test summary}" source="${4:-ai}"
  local index="$TEST_HOME/.dev_projects/index.json"
  local tmp
  tmp=$(mktemp "${index}.XXXXXX")
  jq --arg k "$key" --arg p "$path" --arg s "$summary" --arg src "$source" \
    '.[$k] = {"path": $p, "summary": $s, "indexed_at": 0, "source": $src}' \
    "$index" > "$tmp" && mv "$tmp" "$index"
}

# Inject a fake curl into PATH that returns a canned Ollama response
mock_ollama() {
  local response="${1:-A mock AI-generated summary for testing.}"
  mkdir -p "$TEST_HOME/bin"
  printf '#!/bin/bash\necho '"'"'{"response":"%s"}'"'"'\n' "$response" \
    > "$TEST_HOME/bin/curl"
  chmod +x "$TEST_HOME/bin/curl"
  export PATH="$TEST_HOME/bin:$PATH"
}
