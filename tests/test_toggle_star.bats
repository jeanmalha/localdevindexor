#!/usr/bin/env bats

load helpers

setup()    { setup_test_home; }
teardown() { teardown_test_home; }

SCRIPT="$ROOT/toggle-star.sh"

@test "adds a project to stars" {
  run bash "$SCRIPT" "myapp"
  [ "$status" -eq 0 ]
  grep -qxF "myapp" "$HOME/.dev_projects/stars"
}

@test "removes a project that is already starred" {
  echo "myapp" > "$HOME/.dev_projects/stars"
  run bash "$SCRIPT" "myapp"
  [ "$status" -eq 0 ]
  ! grep -qxF "myapp" "$HOME/.dev_projects/stars"
}

@test "toggling twice returns to unstarred" {
  bash "$SCRIPT" "myapp"
  bash "$SCRIPT" "myapp"
  run grep -qxF "myapp" "$HOME/.dev_projects/stars"
  [ "$status" -ne 0 ]
}

@test "handles nested project keys with slashes" {
  run bash "$SCRIPT" "Product/demo"
  [ "$status" -eq 0 ]
  grep -qxF "Product/demo" "$HOME/.dev_projects/stars"
}

@test "does not affect other starred projects" {
  echo "other" > "$HOME/.dev_projects/stars"
  bash "$SCRIPT" "myapp"
  grep -qxF "other" "$HOME/.dev_projects/stars"
}
