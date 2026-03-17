# help commands

cmd_accounts_help() {
    cat << 'EOF'
codex-accounts

USAGE
  codex-accounts <command>

COMMANDS
  list                     List managed accounts
  add <name>               Create empty managed account
  bootstrap [name]         Import current ~/.codex into a managed account
  remove <name>            Remove managed account
  rename <old> <new>       Rename managed account
  default [name]           Show or set default account
  profile <acc> [name]     Show or set default Codex config profile for account
  info [name]              Show account details
  login [name] [...]       Run codex login in the account CODEX_HOME
  logout [name]            Run codex logout in the account CODEX_HOME
  next                     Show likely available accounts
  path                     Show install path
  self-uninstall           Remove manager from shell and disk
EOF
}

cmd_projects_help() {
    cat << 'EOF'
codex-projects

USAGE
  codex-projects <command>

COMMANDS
  status [path]            Show project ledger status
  history [path] [-n N]    Show project activity history
  handoff ...              Create a handoff note for another account
  list                     List tracked projects
EOF
}
