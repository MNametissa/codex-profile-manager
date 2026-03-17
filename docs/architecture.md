# Architecture

## Overview

The project has two layers:

1. A shell wrapper that adds `-u/--user/--account` to `codex`
2. A Python Typer application that owns management logic

## Shell Layer

[`codex-profile-manager.sh`](/home/mnametissa/development/tools/codex-profile-manager/codex-profile-manager.sh)

Responsibilities:

- expose `codex`, `codex-accounts`, `codex-projects`, and `codexpm`
- resolve the local Python runtime
- call the Typer app
- wrap native `codex` execution with a managed account

## Python Layer

[`cli.py`](/home/mnametissa/development/tools/codex-profile-manager/src/codex_profile_manager/cli.py)

- defines command groups
- supports rich output and `--json`

[`core.py`](/home/mnametissa/development/tools/codex-profile-manager/src/codex_profile_manager/core.py)

- account storage
- project ledger
- handoff generation
- lock handling
- replication export/import
- system install/upgrade helpers

[`render.py`](/home/mnametissa/development/tools/codex-profile-manager/src/codex_profile_manager/render.py)

- Rich tables and panels

[`runner.py`](/home/mnametissa/development/tools/codex-profile-manager/src/codex_profile_manager/runner.py)

- dedicated execution path for wrapped `codex` launches

## Storage Model

```text
~/.local/share/codex-profile-manager/
  accounts/
    <name>/
      home/
      meta.json
  projects/
    <project-id>/
      project.toml
      activity.jsonl
      handoffs.jsonl
      notes/
      snapshots/
  default-account
  .venv/
  src/
```

## Design Principles

- account isolation is implemented with `CODEX_HOME`
- continuity is attached to the project ledger
- the manager does not depend on undocumented internal file formats for handoff
- JSON output is available for automation
- rich output is the default for operators
