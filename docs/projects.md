# Projects Guide

## Project Continuity Model

The most important rule is:

- project continuity belongs to the project ledger
- not to a single Codex account

Each tracked project gets a ledger under:

```text
~/.local/share/codex-profile-manager/projects/<project-id>/
```

With files such as:

- `project.toml`
- `activity.jsonl`
- `handoffs.jsonl`
- `notes/`
- `snapshots/`

## Commands

Show project status:

```bash
codex-projects status
codex-projects status /path/to/project --json
```

Show recent activity:

```bash
codex-projects history
codex-projects history /path/to/project --limit 50
```

List all tracked projects:

```bash
codex-projects list
```

## Handoff Between Accounts

When one account is exhausted or you want to continue elsewhere:

```bash
codex-projects handoff --to-account backup --to-profile review --reason "rate limit"
```

This creates:

- a structured handoff note in `notes/`
- an entry in `handoffs.jsonl`
- an event in `activity.jsonl`

Then continue with:

```bash
codex -u backup -p review
```

## Locking

The manager creates a project lock while a tracked session is running. This is meant to reduce accidental overlap between multiple accounts on the same project.

Bypass is possible with:

```bash
export CODEX_PM_IGNORE_LOCK=1
```

Use that only if you understand the consequences.
