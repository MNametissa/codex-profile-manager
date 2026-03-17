# Getting Started

## What This Tool Does

Codex Profile Manager adds a multi-account layer on top of `codex` by isolating each account in its own `CODEX_HOME`. It also keeps a shared project ledger so several accounts can continue the same project without losing the operational thread.

## Install

```bash
git clone <your-repo> codex-profile-manager
cd codex-profile-manager
bash install.sh
source ~/.bashrc   # or ~/.zshrc
```

## First Setup

If you already have a working `~/.codex`, import it as a managed account:

```bash
codex-accounts bootstrap default
```

Or create a new empty account:

```bash
codex-accounts add backup
codex-accounts login backup
```

## Basic Workflow

Set a default account:

```bash
codex-accounts default default
```

Set a default Codex config profile for an account:

```bash
codex-accounts profile default review
```

Run Codex with a managed account:

```bash
codex -u default
codex -u backup -p fast
```

Inspect the current state:

```bash
codex-accounts list
codex-accounts info default --json
codex-projects status
```

## Quick Commands

```bash
codex-accounts next
codex-projects history
codex-projects handoff --to-account backup --reason "rate limit"
codexpm system status
```
