#!/bin/bash

CODEX_PM_DIR="${CODEX_PM_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"

source "$CODEX_PM_DIR/lib/config.sh"
source "$CODEX_PM_DIR/lib/utils.sh"
source "$CODEX_PM_DIR/lib/codex-wrapper.sh"
source "$CODEX_PM_DIR/lib/cmd-accounts.sh"
source "$CODEX_PM_DIR/lib/cmd-projects.sh"
source "$CODEX_PM_DIR/lib/cmd-help.sh"
source "$CODEX_PM_DIR/lib/completions.sh"

codex-accounts() {
    local cmd="${1:-list}"
    [[ $# -gt 0 ]] && shift

    case "$cmd" in
        list|ls)         cmd_accounts_list "$@" ;;
        add)             cmd_accounts_add "$@" ;;
        bootstrap)       cmd_accounts_bootstrap "$@" ;;
        remove|rm|delete) cmd_accounts_remove "$@" ;;
        rename|mv)       cmd_accounts_rename "$@" ;;
        default)         cmd_accounts_default "$@" ;;
        profile)         cmd_accounts_profile "$@" ;;
        info|status)     cmd_accounts_info "$@" ;;
        login)           cmd_accounts_login "$@" ;;
        logout)          cmd_accounts_logout "$@" ;;
        next)            cmd_accounts_next "$@" ;;
        path)            cmd_accounts_path ;;
        self-uninstall)  cmd_accounts_self_uninstall ;;
        help|--help|-h)  cmd_accounts_help ;;
        *)
            echo "Unknown codex-accounts command: $cmd" >&2
            cmd_accounts_help >&2
            return 1
            ;;
    esac
}

codex-projects() {
    local cmd="${1:-status}"
    [[ $# -gt 0 ]] && shift

    case "$cmd" in
        status)          cmd_projects_status "$@" ;;
        history)         cmd_projects_history "$@" ;;
        handoff)         cmd_projects_handoff "$@" ;;
        list)            cmd_projects_list "$@" ;;
        help|--help|-h)  cmd_projects_help ;;
        *)
            echo "Unknown codex-projects command: $cmd" >&2
            cmd_projects_help >&2
            return 1
            ;;
    esac
}

export -f codex codex-accounts codex-projects
