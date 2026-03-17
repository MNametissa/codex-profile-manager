# Codex Profile Manager

Codex Profile Manager ajoute une couche multi-comptes a `codex` en utilisant `CODEX_HOME` pour isoler proprement chaque compte sur la meme machine.

## Features

- plusieurs comptes Codex nommes (`perso`, `client-a`, `backup`)
- profil de configuration Codex par defaut par compte
- wrapper `codex -u <account>` sans casser les commandes natives
- ledger transverse par projet pour conserver une chronologie commune
- handoff entre comptes avec note de reprise
- suivi local des etats d'auth et des signaux de limite d'usage
- installateur shell qui source automatiquement le wrapper

## Install

```bash
bash install.sh
source ~/.bashrc   # ou ~/.zshrc
```

## Quickstart

```bash
codex-accounts list
codex-accounts add backup
codex-accounts login backup
codex-accounts default backup

codex -u backup
codex -u backup -p review

codex-projects status
codex-projects history
codex-projects handoff --to-account backup --reason "rate limit"
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
- `codex-accounts login [account] [codex-login-flags...]`
- `codex-accounts logout [account]`
- `codex-accounts next`

### Projects

- `codex-projects status [path]`
- `codex-projects history [path] [--limit N]`
- `codex-projects handoff --to-account <name> [--to-profile <profile>] [--reason <text>] [path]`
- `codex-projects list`

## Data Layout

```text
~/.local/share/codex-profile-manager/
  accounts/<name>/home/         # CODEX_HOME isole pour chaque compte
  accounts/<name>/meta.env      # metadonnees du compte
  projects/<project-id>/        # ledger transverse du projet
  codex-profile-manager.sh      # wrapper source par le shell
  lib/*.sh
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
