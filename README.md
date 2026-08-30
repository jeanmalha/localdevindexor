# localdevindexor

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

A local project navigator for developers. Type `guide` to fuzzy-search all your projects with AI-generated summaries, and jump into any of them instantly.

```
  project >                                               backend/api
  ──────────────────────────────────────────────────────  ──────────────────────────────────────
  my-saas-app           SaaS dashboard with billing       REST API for the main platform service.
  research-tool         AI-powered research workspace
  mobile-app            Cross-platform React Native app   git: main | 2 days ago — fix auth flow
  backend/api           REST API for the main platform
  backend/workers       Async job processing service      Permissions Size  Name
  data-pipeline         ETL pipeline for analytics        drwxr-xr-x    -   src
  side-project          Browser extension for bookmarks   drwxr-xr-x    -   tests
  ...                                                     drwxr-xr-x    -   scripts
```

## Features

- **`guide`** — opens an fzf picker showing all projects sorted by most recently touched, with summaries
- **`guide <name>`** — cd directly into a project (prefix/substring match, case-insensitive)
- **Tab completion** — completes project names including nested ones like `Product/demo`
- **Two-level scanning** — detects container folders and indexes their sub-projects individually
- **AI summaries** — uses a local Ollama model to generate one-line descriptions automatically
- **Nightly cron** — re-indexes modified projects every night so summaries stay fresh
- **Last modified tag** — each project shows how long ago it was touched (5m ago, yesterday, Aug 15)
- **Star projects** — press `ctrl-s` in the picker to star/unstar; starred projects always appear first
- **fzf preview panel** — shows summary, star status, git branch + last commit, and file listing

## Requirements

- **zsh**
- **[jq](https://jqlang.github.io/jq/)** — JSON processing
- **[fzf](https://github.com/junegunn/fzf)** — fuzzy finder
- **[Ollama](https://ollama.com)** — local AI model runner
- A small Ollama model: `ollama pull llama3.2` (2 GB, fast)
- **curl**
- Optional: **[eza](https://github.com/eza-community/eza)** — nicer file listing in the preview panel

```bash
brew install jq fzf curl eza
brew install ollama
ollama pull llama3.2
```

## Installation

```bash
git clone https://github.com/jeanmalha/localdevindexor
cd localdevindexor
chmod +x install.sh
./install.sh
```

The installer will:
1. Copy scripts to `~/.dev_projects/`
2. Ask for your projects directory (default: `~/Documents/Dev`)
3. Ask which Ollama model to use
4. Add `source ~/.dev_projects/shell.zsh` to your `.zshrc`
5. Optionally set up a nightly cron to keep summaries fresh

Then run the initial index:
```bash
bash ~/.dev_projects/reindex.sh
exec zsh
guide
```

## Usage

| Command | Action |
|---|---|
| `guide` | Open interactive fzf picker |
| `guide map` | cd into the first project matching "map" |
| `guide backend/api` | cd into an exact sub-project |
| `guide <TAB>` | Tab-complete project names |
| `dev-reindex` | Re-scan all projects and update summaries |

Inside the fzf picker: type to filter, `enter` to cd, `ctrl-s` to toggle star, `esc` to cancel. Starred projects always float to the top.

## How it works

**Project detection** (`reindex.sh`): Scans one or two levels deep in your projects directory. A folder is treated as a project if it contains `.git`, `package.json`, `go.mod`, `README.md`, `CLAUDE.md`, or other common markers. Folders with none of these are treated as containers and their subdirectories are scanned instead.

**Context gathering** for summaries (in priority order):
1. `README.md`, `CLAUDE.md`, `README.txt`
2. `package.json`, `pyproject.toml`, `go.mod`, `Cargo.toml`
3. Git log (recent commit messages)
4. First 30 lines of main source file
5. File tree

**Summarization**: sends context to a local Ollama model with a strict system prompt that forces a single sentence output regardless of how sparse the context is. Incremental — only re-indexes projects modified since the last run.

**Navigation** (`shell.zsh`): the `guide` function reads the index, builds a list sorted by real filesystem mtime, and pipes it to fzf. Selecting a project calls `cd` using the stored absolute path.

## Configuration

Edit `~/.dev_projects/shell.zsh` to change the projects directory:

```zsh
_DEV_DIR="$HOME/Documents/Dev"   # change this
```

Edit `~/.dev_projects/reindex.sh` to change the model:

```bash
MODEL="llama3.2:latest"   # any Ollama model
```

To force a full re-index from scratch:
```bash
echo '{}' > ~/.dev_projects/index.json
dev-reindex
```

## File structure

```
~/.dev_projects/
├── index.json        # project metadata and summaries (gitignored)
├── stars             # list of starred project keys (gitignored)
├── reindex.sh        # scanner + Ollama summarizer
├── shell.zsh         # guide() function and tab completion
├── list.sh           # generates the fzf list (age tags, starred-first sorting)
├── preview.sh        # fzf preview panel helper
└── toggle-star.sh    # called by fzf ctrl-s to star/unstar a project
```
