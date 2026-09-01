#!/bin/bash
# Generates the fzf-ready project list: starred first, both groups sorted by mtime.
# Output format (tab-delimited): key<TAB>display_line
# fzf uses --with-nth=2 to show only display_line, {1} for the key.
#
# Performance: this runs on every `guide` invocation before fzf can paint, so it
# avoids per-project subprocesses. Stars are read once, mtimes are collected in a
# single batched stat call, and lines are built with the printf builtin (no
# command-substitution subshell per project). See the loop below.

index="${HOME}/.dev_projects/index.json"
stars_file="${HOME}/.dev_projects/stars"
[[ ! -f "$stars_file" ]] && touch "$stars_file"

_NOW=$(date +%s)

# Sets global AGE from an epoch mtime. Written to avoid a command-substitution
# subshell per project; only the >1-week branch forks (once, for `date`).
format_age() {
  local mtime="$1" diff=$(( _NOW - mtime ))
  if   (( diff < 60 ));      then AGE="just now"
  elif (( diff < 3600 ));    then AGE="$(( diff / 60 ))m ago"
  elif (( diff < 86400 ));   then AGE="$(( diff / 3600 ))h ago"
  elif (( diff < 172800 ));  then AGE="yesterday"
  elif (( diff < 604800 ));  then AGE="$(( diff / 86400 ))d ago"
  else
    AGE=$(date -r "$mtime" "+%b %d" 2>/dev/null || date -d "@$mtime" "+%b %d" 2>/dev/null || echo "old")
  fi
}

# --- Load stars once into a lookup (was: one `grep` per project) ---
declare -A is_star
while IFS= read -r s; do
  [[ -n "$s" ]] && is_star["$s"]=1
done < "$stars_file"

# --- Read the index once ---
keys=(); paths=(); summaries=()
while IFS=$'\t' read -r key path summary; do
  [[ -z "$key" ]] && continue
  keys+=("$key"); paths+=("$path"); summaries+=("$summary")
done < <(jq -r 'to_entries[] | [.key, .value.path, (.value.summary // "")] | @tsv' "$index" 2>/dev/null)

# --- Batch-stat every path in a single call (was: one `stat` per project) ---
# BSD (macOS) and GNU (Linux) stat differ; both can print "<mtime> <path>" per
# line, letting us map results back by path regardless of ordering or gaps.
declare -A mtimes
if [ ${#paths[@]} -gt 0 ]; then
  if stat -f '%m' . >/dev/null 2>&1; then
    while IFS=' ' read -r m p; do
      [[ -n "$p" ]] && mtimes["$p"]=$m
    done < <(stat -f '%m %N' "${paths[@]}" 2>/dev/null)
  else
    while IFS=$'\t' read -r m p; do
      [[ -n "$p" ]] && mtimes["$p"]=$m
    done < <(stat -c '%Y	%n' "${paths[@]}" 2>/dev/null)
  fi
fi

starred=()
regular=()
line=""

for i in "${!keys[@]}"; do
  key="${keys[$i]}"
  path="${paths[$i]}"
  summary="${summaries[$i]}"
  mtime="${mtimes[$path]:-0}"
  format_age "$mtime"

  if [[ -n "${is_star[$key]}" ]]; then
    printf -v line '%010d\t%s\t★ %-28s  %-10s  %s' "$mtime" "$key" "$key" "$AGE" "$summary"
    starred+=("$line")
  else
    printf -v line '%010d\t%s\t  %-28s  %-10s  %s' "$mtime" "$key" "$key" "$AGE" "$summary"
    regular+=("$line")
  fi
done

# Starred first, each group sorted newest first; strip the sort-key prefix
[ ${#starred[@]} -gt 0 ] && printf '%s\n' "${starred[@]}" | sort -r | cut -f2-
[ ${#regular[@]} -gt 0 ] && printf '%s\n' "${regular[@]}" | sort -r | cut -f2-
true
