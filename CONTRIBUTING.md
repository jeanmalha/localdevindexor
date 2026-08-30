# Contributing to localdevindexor

Thanks for your interest. This is a small shell tool — contributions should stay in that spirit: focused, portable, no new dependencies.

## Reporting bugs

Open an issue with:
- Your OS and zsh version (`zsh --version`)
- Your Ollama model (`ollama list`)
- The exact command that failed and what you expected

## Suggesting features

Open an issue first before writing code. This tool has an intentionally small scope — a navigator for local projects, nothing more. If it fits, great. If it's better as a separate tool, say so and we'll discuss.

## Contributing code

```bash
# Fork, then clone your fork
git clone https://github.com/<you>/localdevindexor
cd localdevindexor

# Install to a test location to iterate
INSTALL_DIR=~/.dev_projects_test ./install.sh

# Make your changes, test manually
bash ~/.dev_projects_test/reindex.sh
source ~/.dev_projects_test/shell.zsh
guide
```

Open a PR against `main`. Keep it to one concern per PR.

## Guidelines

**Portability first.** Scripts run on macOS and Linux. Test both if you can. `stat` flags differ (`-f %m` vs `-c %Y`) — the existing pattern handles this; don't break it.

**No new runtime dependencies.** The required stack is `zsh`, `bash`, `jq`, `fzf`, `curl`, and `ollama`. Optional: `eza`. Don't add to this list.

**Security matters.** All `git` calls in untrusted directories must use `GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null`. All writes to shared files must use `mktemp` on the same filesystem as the target. LLM output must be sanitized before display. See the existing patterns.

**Shell style.** Double-quote all variable expansions. Use `command ls` or `/bin/ls` instead of `ls` (may be aliased). Use `jq --arg` for user data, never string interpolation into jq filters.

**Summaries stay local.** Nothing should send data to external services. `$OLLAMA_URL` must always resolve to loopback.

## Release process

Releases are gated on CI. The workflow is:

1. Merge to `main` — CI (lint + tests) must be green
2. Tag and release:
   ```bash
   make release VERSION=v0.2.0-beta.1
   ```
   This runs lint and tests locally first, then pushes the tag. GitHub Actions picks it up, runs CI again, and creates the GitHub release automatically. Tags containing `beta`, `alpha`, or `rc` are marked pre-release.

## What's in scope

- Better project detection heuristics
- Improved age/mtime formatting
- Additional fzf keybindings
- Fish shell support (a `shell.fish` alongside `shell.zsh`)
- bash completion alongside zsh completion
- Linux-specific fixes

## What's out of scope

- Cloud sync of the index
- Remote Ollama endpoints as a default
- GUI / TUI beyond what fzf provides
- Package manager distribution (Homebrew formula is the eventual goal; PyPI/npm are not)
