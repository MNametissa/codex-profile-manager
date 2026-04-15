# Codex Profile Manager

Manage multiple OpenAI Codex accounts on a single machine. Each account has isolated `CODEX_HOME`, credentials, settings, and usage tracking.

## Install

```bash
bash install.sh
source ~/.bashrc  # or ~/.zshrc
```

The installer:
- Creates a Python virtual environment
- Installs the CLI and wrapper
- Imports existing `~/.codex` as the "default" account (optional)
- Adds shell functions for `codex`, `codex-accounts`, `codex-projects`, and `codexpm`

## Quick Start

```bash
# Create an account
codex-accounts add work

# Login to the account
codex-accounts login work

# Use the account
codex -u work

# Set as default
codex-accounts default work
codex  # uses work account
```

## Account Management

```bash
codex-accounts list                  # List all accounts
codex-accounts add <name>            # Create account
codex-accounts bootstrap [name]      # Import ~/.codex as account
codex-accounts remove <name>         # Remove account
codex-accounts rename <old> <new>    # Rename account
codex-accounts default [name]        # Get/set default
codex-accounts info [account]        # Show details
codex-accounts info [account] --json # JSON output
codex-accounts login [account]       # Authenticate
codex-accounts logout [account]      # Remove credentials
codex-accounts next                  # Switch to next available account
```

## Billing/Renewal Tracking

```bash
codex-accounts set-renewal work 2024-05-01 --cycle monthly
codex-accounts clear-renewal work
```

The wrapper shows a banner before launch with renewal date and usage status.

## Project Ledger

Track activity across accounts per project:

```bash
codex-projects status [path]         # Show project info
codex-projects history [path]        # Show activity log
codex-projects list                  # List tracked projects
codex-projects handoff --to-account backup --reason "rate limit"
```

Handoff creates a note with git status, recent history, and resume instructions.

## Replication

Export accounts to another machine:

```bash
# Source machine
codexpm replicate export ~/codex-bundle.tgz --include-auth --include-projects

# Target machine
git clone <repo> codex-profile-manager && cd codex-profile-manager
bash install.sh && source ~/.bashrc
codexpm system install-codex
codexpm replicate import ~/codex-bundle.tgz --overwrite
```

## System Management

```bash
codexpm system status                # Show npm/codex versions
codexpm system install-codex         # Install @openai/codex globally
codexpm system upgrade-codex         # Upgrade to latest
```

## Documentation

```bash
codexpm docs                         # List topics
codexpm docs getting-started         # View topic
codexpm docs replication --path      # Show file path
```

## Data Layout

```
~/.local/share/codex-profile-manager/
  .venv/                          # Python environment
  src/codex_profile_manager/      # Typer CLI app
  accounts/<name>/home/           # Isolated CODEX_HOME per account
  accounts/<name>/meta.json       # Account metadata
  projects/<project-id>/          # Cross-account project ledger
  codex-profile-manager.sh        # Shell wrapper
```

## Uninstall

Remove the source line from `~/.bashrc` or `~/.zshrc` and delete `~/.local/share/codex-profile-manager/`.

## Requirements

- Linux or macOS
- Bash or Zsh
- Python 3.10+
- Node.js/npm (for @openai/codex)
