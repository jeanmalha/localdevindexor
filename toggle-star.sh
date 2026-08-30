#!/bin/bash
key="$1"
stars_file="${HOME}/.dev_projects/stars"
touch "$stars_file"

if grep -qxF "$key" "$stars_file"; then
  tmp=$(mktemp "${stars_file}.XXXXXX")
  grep -vxF "$key" "$stars_file" > "$tmp" && mv "$tmp" "$stars_file"
else
  echo "$key" >> "$stars_file"
fi
