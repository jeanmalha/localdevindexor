## Dev project navigator
_DEV_DIR="$HOME/Documents/Dev"
_DEV_INDEX="${HOME}/.dev_projects/index.json"

_guide_cd() {
  # Given a key (e.g. "mapmaker" or "Product/demo"), cd using the indexed path
  local key="$1"
  local index="${_DEV_INDEX:-$HOME/.dev_projects/index.json}"
  local stored_path
  stored_path=$(jq -r --arg k "$key" '.[$k].path // ""' "$index" 2>/dev/null)
  if [[ -n "$stored_path" && -d "$stored_path" ]]; then
    cd "$stored_path"
    return 0
  fi
  # Fallback: try direct path
  if [[ -d "$_DEV_DIR/$key" ]]; then
    cd "$_DEV_DIR/$key"
    return 0
  fi
  return 1
}

function guide() {
  local base="$_DEV_DIR"
  local index="${_DEV_INDEX:-$HOME/.dev_projects/index.json}"

  # With argument: find best match by key
  if [[ $# -gt 0 ]]; then
    local query="$1"

    # 1. Exact key match
    if _guide_cd "$query" 2>/dev/null; then return; fi

    # 2. Case-insensitive prefix on the basename (last segment)
    local match
    match=$(jq -r 'keys[]' "$index" 2>/dev/null \
      | awk -F/ -v q="${query:l}" 'tolower($NF) ~ "^"q {print; exit}')
    if [[ -n "$match" ]] && _guide_cd "$match" 2>/dev/null; then return; fi

    # 3. Substring on full key
    match=$(jq -r 'keys[]' "$index" 2>/dev/null \
      | awk -v q="${query:l}" 'tolower($0) ~ q {print; exit}')
    if [[ -n "$match" ]] && _guide_cd "$match" 2>/dev/null; then return; fi

    echo "No project matching '$query'"
    return 1
  fi

  # No argument: fzf picker (starred first, then by mtime)
  local list
  list=$(bash ~/.dev_projects/list.sh)

  if [[ -z "$list" ]]; then
    echo "No projects indexed yet — run: dev-reindex"
    return 1
  fi

  local selected
  selected=$(printf '%s\n' "$list" | fzf \
    --prompt="  project > " \
    --height=60% \
    --reverse \
    --ansi \
    --delimiter=$'\t' \
    --with-nth=2 \
    --nth=2 \
    --preview="~/.dev_projects/preview.sh {1}" \
    --preview-window="right:45%:wrap" \
    --bind="ctrl-s:execute-silent(bash ~/.dev_projects/toggle-star.sh {1})+reload(bash ~/.dev_projects/list.sh)" \
    --bind="ctrl-e:execute(bash ~/.dev_projects/edit-summary.sh {1})+reload(bash ~/.dev_projects/list.sh)" \
    --header="enter:cd  ctrl-s:★ star  ctrl-e:✎ edit desc  esc:cancel"
  )

  [[ -z "$selected" ]] && return
  local key
  key=$(printf '%s' "$selected" | cut -f1)
  _guide_cd "$key"
}

# Tab completion — completes on index keys (handles "Product/demo" etc.)
_guide_complete() {
  local -a keys
  keys=($(jq -r 'keys[]' "$HOME/.dev_projects/index.json" 2>/dev/null))
  compadd -a keys
}
# compdef requires compinit; register lazily if not yet available
if (( ${+functions[compdef]} )); then
  compdef _guide_complete guide
else
  autoload -Uz compinit && compinit -C 2>/dev/null
  (( ${+functions[compdef]} )) && compdef _guide_complete guide
fi

# Reindex alias
alias dev-reindex="bash ~/.dev_projects/reindex.sh"
