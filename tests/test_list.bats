#!/usr/bin/env bats

load helpers

setup()    { setup_test_home; }
teardown() { teardown_test_home; }

SCRIPT="$ROOT/list.sh"

@test "empty index produces no output" {
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "outputs project name and summary" {
  proj=$(make_project "myapp")
  add_to_index "myapp" "$proj" "A test application"
  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"myapp"* ]]
  [[ "$output" == *"A test application"* ]]
}

@test "first field is the index key (tab-delimited)" {
  proj=$(make_project "myapp")
  add_to_index "myapp" "$proj" "A test application"
  run bash "$SCRIPT"
  first_field=$(printf '%s' "$output" | cut -f1)
  [ "$first_field" = "myapp" ]
}

@test "starred project appears before unstarred" {
  proj1=$(make_project "alpha")
  proj2=$(make_project "beta")
  add_to_index "alpha" "$proj1" "Alpha"
  add_to_index "beta"  "$proj2" "Beta"
  echo "beta" > "$HOME/.dev_projects/stars"

  run bash "$SCRIPT"
  [ "$status" -eq 0 ]
  beta_line=$(printf '%s\n' "$output" | grep -n "beta"  | cut -d: -f1 | head -1)
  alpha_line=$(printf '%s\n' "$output" | grep -n "alpha" | cut -d: -f1 | head -1)
  [ "$beta_line" -lt "$alpha_line" ]
}

@test "displays a non-empty age tag" {
  proj=$(make_project "myapp")
  add_to_index "myapp" "$proj" "A test application"
  run bash "$SCRIPT"
  # Age can be "just now", "Xm ago", a date, etc. — just verify it's non-empty
  display=$(printf '%s' "$output" | cut -f2)
  [[ "$display" == *"ago"* ]] || [[ "$display" == *"now"* ]] || \
  [[ "$display" == *"yesterday"* ]] || [[ "$display" =~ [A-Z][a-z]{2}\ [0-9]+ ]]
}
