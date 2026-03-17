# Accounts Guide

## Account Model

A managed account is a named Codex environment stored under:

```text
~/.local/share/codex-profile-manager/accounts/<name>/home
```

That directory acts as the account's `CODEX_HOME`. It can contain:

- `config.toml`
- `auth.json`
- `sessions/`
- `skills/`
- `agents/`
- `memories/`
- `mcp` configuration and related state

## Core Commands

Create or import accounts:

```bash
codex-accounts add backup
codex-accounts bootstrap default
```

Rename or remove:

```bash
codex-accounts rename backup backup-eu
codex-accounts remove backup-eu
```

Set defaults:

```bash
codex-accounts default default
codex-accounts profile default review
```

Login or logout:

```bash
codex-accounts login default
codex-accounts logout backup
```

## Introspection

Human-readable output:

```bash
codex-accounts list
codex-accounts info default
codex-accounts next
```

Machine-readable output:

```bash
codex-accounts list --json
codex-accounts info default --json
codex-accounts next --json
```

## Billing Metadata

The tool can store a renewal date per account:

```bash
codex-accounts set-renewal default 2026-04-12 --cycle monthly
codex-accounts clear-renewal default
```

This data is manager-owned metadata. It is not fetched automatically from OpenAI billing.

## Important Limitation

The manager can display renewal information before launching `codex`, but it does not reliably inject arbitrary data into the native Codex status line. The native status line appears to support predefined fields only.

Instead, the wrapper prints a manager-owned control strip before `codex` starts. It highlights:

- the selected account and effective profile
- the stored renewal date with stronger colors as payment gets close
- local usage pressure from recent session data (`used_percent`, `resets_at`, `plan_type`)
