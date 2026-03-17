# Replication and Operations

## Goal

This tool is designed to replicate a Codex setup across VPS instances:

- managed accounts
- isolated `CODEX_HOME` trees
- `config.toml`
- MCP configuration
- skills
- agents
- memories
- optionally project ledgers

## Export a Bundle

Without auth tokens:

```bash
codexpm replicate export ~/codex-bundle.tgz --include-projects
```

With auth tokens included:

```bash
codexpm replicate export ~/codex-bundle.tgz --include-auth --include-projects
```

If you include auth, treat the archive as sensitive.

## Import a Bundle

```bash
codexpm replicate import ~/codex-bundle.tgz --overwrite
```

JSON output is available:

```bash
codexpm replicate import ~/codex-bundle.tgz --overwrite --json
```

## Install and Upgrade Codex

Check local tooling:

```bash
codexpm system status
```

Install Codex globally:

```bash
codexpm system install-codex
```

Upgrade Codex:

```bash
codexpm system upgrade-codex
```

Pin a specific version:

```bash
codexpm system install-codex --version 0.115.0
```

## Replicate to Another VPS

On the source machine:

```bash
codexpm replicate export ~/codex-bundle.tgz --include-auth --include-projects
```

On the target machine:

```bash
git clone <your-repo> codex-profile-manager
cd codex-profile-manager
bash install.sh
source ~/.bashrc
codexpm system install-codex
codexpm replicate import ~/codex-bundle.tgz --overwrite
```

## Operational Notes

- Keep at least one clean backup bundle without auth.
- Use auth-including bundles only for trusted transfers.
- Re-run `codexpm system upgrade-codex` after moving to a new VPS if you want the same CLI generation.
- For smoke validation, run:

```bash
bash scripts/smoke-test.sh
```
