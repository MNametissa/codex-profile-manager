# Codex Profile Manager

Codex Profile Manager ajoute une couche multi-comptes a `codex` en utilisant `CODEX_HOME` pour isoler proprement chaque compte sur la meme machine. Les commandes de gestion sont implementees avec [Typer](https://typer.tiangolo.com/) et le rendu terminal utilise Rich.

## Features

- plusieurs comptes Codex nommes (`perso`, `client-a`, `backup`)
- profil de configuration Codex par defaut par compte
- wrapper `codex -u <account>` sans casser les commandes natives
- CLI Typer avec rendu tableau et sorties `--json`
- ledger transverse par projet pour conserver une chronologie commune
- handoff entre comptes avec note de reprise
- suivi local des etats d'auth et des signaux de limite d'usage
- snapshots export/import pour repliquer l'installation managerisee sur d'autres VPS
- installation et upgrade de `@openai/codex` via `npm`
- installateur shell qui source automatiquement le wrapper

## Install

```bash
bash install.sh
source ~/.bashrc   # ou ~/.zshrc
```

## Documentation

- `codexpm docs`
- `codexpm docs getting-started`
- `codexpm docs replication --path`
- [Documentation Index](./docs/README.md)
- [Getting Started](./docs/getting-started.md)
- [Accounts Guide](./docs/accounts.md)
- [Projects Guide](./docs/projects.md)
- [Replication and Operations](./docs/replication-and-operations.md)
- [Architecture](./docs/architecture.md)

## Quickstart

```bash
codex-accounts list
codex-accounts info backup --json
codex-accounts add backup
codex-accounts login backup
codex-accounts default backup
codex-accounts set-renewal backup 2026-04-12 --cycle monthly

codex -u backup
codex -u backup -p review

codex-projects status
codex-projects history
codex-projects handoff --to-account backup --reason "rate limit"

codexpm replicate export ~/codex-bundle.tgz --include-auth --include-projects
codexpm system install-codex
codexpm system upgrade-codex
```

## Commands

### Accounts

- `codex-accounts list`
- `codex-accounts add <name>`
- `codex-accounts bootstrap [name]`
- `codex-accounts remove <name>`
- `codex-accounts rename <old> <new>`
- `codex-accounts default [name]`
- `codex-accounts profile <account> [config-profile]`
- `codex-accounts info [account]`
- `codex-accounts info [account] --json`
- `codex-accounts login [account] [codex-login-flags...]`
- `codex-accounts logout [account]`
- `codex-accounts next`
- `codex-accounts set-renewal <account> <YYYY-MM-DD> [--cycle monthly|annual]`
- `codex-accounts clear-renewal <account>`

### Projects

- `codex-projects status [path]`
- `codex-projects status [path] --json`
- `codex-projects history [path] [--limit N]`
- `codex-projects handoff --to-account <name> [--to-profile <profile>] [--reason <text>] [path]`
- `codex-projects list`

### Replication

- `codexpm replicate export <archive.tgz> [--account NAME] [--include-auth] [--include-projects]`
- `codexpm replicate import <archive.tgz> [--overwrite]`

### System

- `codexpm system status`
- `codexpm system install-codex [--version latest]`
- `codexpm system upgrade-codex [--version latest]`

## Replicate To Another VPS

Source VPS:

```bash
codexpm replicate export ~/codex-bundle.tgz --include-auth --include-projects
```

Target VPS:

```bash
git clone <your-repo> codex-profile-manager
cd codex-profile-manager
bash install.sh
source ~/.bashrc
codexpm system install-codex
codexpm replicate import ~/codex-bundle.tgz --overwrite
```

This restores managed accounts, isolated `CODEX_HOME` trees, config profiles, MCP settings, skills, agents, memories, and optionally project ledgers.

## Data Layout

```text
~/.local/share/codex-profile-manager/
  .venv/                        # runtime Python local
  src/codex_profile_manager/    # app Typer
  accounts/<name>/home/         # CODEX_HOME isole pour chaque compte
  accounts/<name>/meta.json     # metadonnees du compte
  projects/<project-id>/        # ledger transverse du projet
  codex-profile-manager.sh      # wrapper source par le shell
```

## Workflow Git

- branchement par defaut: trunk-based
- branches de feature: `feature/<scope>-<short-name>`
- commits: Conventional Commits (`feat:`, `fix:`, `docs:`, `chore:`)

## Development

```bash
bash scripts/smoke-test.sh
```

## Notes

- Le ledger projet est la source de verite pour la continuite inter-comptes.
- L'historique natif de Codex reste dans chaque `CODEX_HOME`.
- Les signaux de quota sont exposes comme estimations locales, pas comme verite de facturation.
- La date de prochain paiement peut etre stockee par compte et affichee par le manager, mais la status line native de Codex ne semble exposer que des champs internes predetermines. Le wrapper affiche donc un banner de renouvellement avant le lancement, plutot qu'une injection non fiable dans la status line native.
