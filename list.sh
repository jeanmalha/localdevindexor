#!/bin/bash
# Generates the fzf-ready project list: starred first, both groups sorted by mtime.
# Output format (tab-delimited): key<TAB>display_line
# fzf uses --with-nth=2 to show only display_line, {1} for the key.

index="${HOME}/.dev_projects/index.json"
stars_file="${HOME}/.dev_projects/stars"
[[ ! -f "$stars_file" ]] && touch "$stars_file"

format_age() {
  local mtime="$1" now diff
  now=$(date +%s)
  diff=$(( now - mtime ))
  if   (( diff < 60 ));      then echo "just now"
  elif (( diff < 3600 ));    then echo "$(( diff / 60 ))m ago"
  elif (( diff < 86400 ));   then echo "$(( diff / 3600 ))h ago"
  elif (( diff < 172800 ));  then echo "yesterday"
  elif (( diff < 604800 ));  then echo "$(( diff / 86400 ))d ago"
  else
    date -r "$mtime" "+%b %d" 2>/dev/null || date -d "@$mtime" "+%b %d" 2>/dev/null || echo "old"
  fi
}

starred=()
regular=()

while IFS=$'\t' read -r key path summary; do
  [[ -z "$key" ]] && continue
  mtime=$(stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null || echo 0)
  age=$(format_age "$mtime")

  if grep -qxF "$key" "$stars_file" 2>/dev/null; then
    starred+=("$(printf '%010d\t%s\t★ %-28s  %-10s  %s' "$mtime" "$key" "$key" "$age" "$summary")")
  else
    regular+=("$(printf '%010d\t%s\t  %-28s  %-10s  %s' "$mtime" "$key" "$key" "$age" "$summary")")
  fi
done < <(jq -r 'to_entries[] | [.key, .value.path, (.value.summary // "")] | @tsv' "$index" 2>/dev/null)

# Starred first, each group sorted newest first; strip the sort-key prefix
[ ${#starred[@]} -gt 0 ] && printf '%s\n' "${starred[@]}" | sort -r | cut -f2-
[ ${#regular[@]} -gt 0 ] && printf '%s\n' "${regular[@]}" | sort -r | cut -f2-
true
