#!/bin/bash
set -e

INSTALL_DIR="$HOME/.dev_projects"
SHELL_RC="$HOME/.zshrc"
SOURCE_LINE='source ~/.dev_projects/shell.zsh'

echo "localdevindexor — install"
echo "========================="

# Check dependencies
missing=()
for dep in jq fzf curl; do
  command -v "$dep" &>/dev/null || missing+=("$dep")
done
if [[ ${#missing[@]} -gt 0 ]]; then
  echo "Error: missing dependencies: ${missing[*]}"
  echo "Install with: brew install ${missing[*]}"
  exit 1
fi

if ! curl -sf http://localhost:11434/api/tags &>/dev/null; then
  echo "Warning: Ollama not reachable at localhost:11434."
  echo "  Summaries won't be generated until Ollama is running."
  echo "  Install: https://ollama.com  then: ollama pull llama3.2"
fi

# Copy files
echo ""
echo "Installing to $INSTALL_DIR ..."
mkdir -p "$INSTALL_DIR"
cp reindex.sh     "$INSTALL_DIR/reindex.sh"
cp shell.zsh      "$INSTALL_DIR/shell.zsh"
cp preview.sh     "$INSTALL_DIR/preview.sh"
cp list.sh        "$INSTALL_DIR/list.sh"
cp toggle-star.sh "$INSTALL_DIR/toggle-star.sh"
chmod +x "$INSTALL_DIR/reindex.sh" "$INSTALL_DIR/preview.sh" \
         "$INSTALL_DIR/list.sh" "$INSTALL_DIR/toggle-star.sh"
touch "$INSTALL_DIR/stars"

[[ ! -f "$INSTALL_DIR/index.json" ]] && echo '{}' > "$INSTALL_DIR/index.json"

# Configure dev directory
echo ""
read -rp "Path to your projects directory [$HOME/Documents/Dev]: " dev_dir
dev_dir="${dev_dir:-$HOME/Documents/Dev}"
dev_dir="${dev_dir/#\~/$HOME}"

if [[ ! -d "$dev_dir" ]]; then
  echo "Error: directory does not exist: $dev_dir"
  exit 1
fi

# Patch DEV_DIR in shell.zsh if not default
if [[ "$dev_dir" != "$HOME/Documents/Dev" ]]; then
  sed -i.bak "s|Documents/Dev|${dev_dir#$HOME/}|g" "$INSTALL_DIR/shell.zsh"
  sed -i.bak "s|Documents/Dev|${dev_dir#$HOME/}|g" "$INSTALL_DIR/reindex.sh"
  sed -i.bak "s|Documents/Dev|${dev_dir#$HOME/}|g" "$INSTALL_DIR/preview.sh"
  rm -f "$INSTALL_DIR"/*.bak
fi

# Configure Ollama model
echo ""
echo "Available Ollama models:"
curl -sf http://localhost:11434/api/tags 2>/dev/null | jq -r '.models[].name' 2>/dev/null | sed 's/^/  /' || echo "  (Ollama not running)"
read -rp "Model to use [llama3.2:latest]: " model
model="${model:-llama3.2:latest}"
sed -i.bak "s|MODEL=\"llama3.2:latest\"|MODEL=\"$model\"|" "$INSTALL_DIR/reindex.sh"
rm -f "$INSTALL_DIR"/*.bak

# Add to shell rc
if [[ -f "$SHELL_RC" ]] && grep -qF "$SOURCE_LINE" "$SHELL_RC"; then
  echo ""
  echo "Shell already configured ($SHELL_RC)."
else
  echo "" >> "$SHELL_RC"
  echo "# localdevindexor — project navigator" >> "$SHELL_RC"
  echo "$SOURCE_LINE" >> "$SHELL_RC"
  echo ""
  echo "Added to $SHELL_RC."
fi

# Optional cron
echo ""
read -rp "Set up nightly auto-reindex cron at 2am? [Y/n]: " setup_cron
if [[ "${setup_cron:-Y}" =~ ^[Yy]$ ]]; then
  cron_line="0 2 * * * bash $INSTALL_DIR/reindex.sh >> $INSTALL_DIR/reindex.log 2>&1"
  if crontab -l 2>/dev/null | grep -qF "reindex.sh"; then
    echo "Cron already set up."
  else
    (crontab -l 2>/dev/null; echo "$cron_line") | crontab -
    echo "Cron added."
  fi
fi

echo ""
echo "Done! Run the initial index:"
echo "  bash ~/.dev_projects/reindex.sh"
echo ""
echo "Then reload your shell:"
echo "  exec zsh"
echo ""
echo "Then try:"
echo "  guide"
