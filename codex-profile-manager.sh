#!/bin/bash

CODEX_PM_DIR="${CODEX_PM_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
CODEX_PM_HOME="${CODEX_PM_HOME:-$HOME/.local/share/codex-profile-manager}"

_codex_pm_python() {
    if [[ -x "$CODEX_PM_HOME/.venv/bin/python" ]]; then
        printf '%s' "$CODEX_PM_HOME/.venv/bin/python"
    elif [[ -x "$CODEX_PM_DIR/.venv/bin/python" ]]; then
        printf '%s' "$CODEX_PM_DIR/.venv/bin/python"
    else
        command -v python3
    fi
}

_codex_pm_invoke() {
    local py_bin
    py_bin="$(_codex_pm_python)"
    PYTHONPATH="$CODEX_PM_DIR/src${PYTHONPATH:+:$PYTHONPATH}" \
    CODEX_PM_HOME="$CODEX_PM_HOME" \
    "$py_bin" -m codex_profile_manager "$@"
}

_codex_pm_account_names() {
    CODEX_PM_HOME="$CODEX_PM_HOME" PYTHONPATH="$CODEX_PM_DIR/src${PYTHONPATH:+:$PYTHONPATH}" "$(_codex_pm_python)" - <<'PY'
from codex_profile_manager.core import list_accounts

for name in list_accounts():
    print(name)
PY
}

_codex_pm_help_route() {
    local scope="$1"
    shift
    if [[ "${1:-}" == "help" ]]; then
        shift
        if [[ "$scope" == "root" ]]; then
            if [[ $# -eq 0 ]]; then
                _codex_pm_invoke --help
            else
                _codex_pm_invoke "$1" --help
            fi
            return 0
        fi
        if [[ $# -eq 0 ]]; then
            _codex_pm_invoke "$scope" --help
        else
            _codex_pm_invoke "$scope" "$1" --help
        fi
        return 0
    fi
    return 1
}

_codex_pm_run_wrapper() {
    local account="$1"
    shift
    local py_bin
    py_bin="$(_codex_pm_python)"
    PYTHONPATH="$CODEX_PM_DIR/src${PYTHONPATH:+:$PYTHONPATH}" \
    CODEX_PM_HOME="$CODEX_PM_HOME" \
    "$py_bin" -m codex_profile_manager.runner --account "$account" -- "$@"
}

codex() {
    local account
    account="$(CODEX_PM_HOME="$CODEX_PM_HOME" PYTHONPATH="$CODEX_PM_DIR/src${PYTHONPATH:+:$PYTHONPATH}" "$(_codex_pm_python)" - <<'PY'
from codex_profile_manager.core import read_default_account
print(read_default_account())
PY
)"

    local -a codex_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -u|--user|--account)
                if [[ -z "$2" || "$2" == -* ]]; then
                    echo "Error: $1 requires an account name" >&2
                    return 1
                fi
                account="$2"
                shift 2
                ;;
            --account=*)
                account="${1#*=}"
                shift
                ;;
            *)
                codex_args+=("$1")
                shift
                ;;
        esac
    done

    _codex_pm_run_wrapper "$account" "${codex_args[@]}"
}

codex-accounts() {
    _codex_pm_help_route accounts "$@" && return 0
    _codex_pm_invoke accounts "$@"
}

codex-projects() {
    _codex_pm_help_route projects "$@" && return 0
    _codex_pm_invoke projects "$@"
}

codexpm() {
    _codex_pm_help_route root "$@" && return 0
    _codex_pm_invoke "$@"
}

_codex_complete_bash() {
    local current prev
    current="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"

    if [[ "$prev" == "-u" || "$prev" == "--user" || "$prev" == "--account" ]]; then
        COMPREPLY=($(compgen -W "$(_codex_pm_account_names)" -- "$current"))
        return
    fi

    COMPREPLY=($(compgen -W "-u --user --account" -- "$current"))
}

_codex_accounts_complete_bash() {
    local current prev command
    current="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    command="${COMP_WORDS[1]:-}"

    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "list add bootstrap remove rename default profile info login logout next set-renewal clear-renewal path help --help" -- "$current"))
        return
    fi

    case "$command" in
        remove|default|info|login|logout|clear-renewal)
            COMPREPLY=($(compgen -W "$(_codex_pm_account_names)" -- "$current"))
            ;;
        rename)
            if [[ $COMP_CWORD -eq 2 ]]; then
                COMPREPLY=($(compgen -W "$(_codex_pm_account_names)" -- "$current"))
            fi
            ;;
        profile)
            if [[ $COMP_CWORD -eq 2 ]]; then
                COMPREPLY=($(compgen -W "$(_codex_pm_account_names)" -- "$current"))
            fi
            ;;
        set-renewal)
            if [[ $COMP_CWORD -eq 2 ]]; then
                COMPREPLY=($(compgen -W "$(_codex_pm_account_names)" -- "$current"))
            elif [[ "$prev" == "--cycle" ]]; then
                COMPREPLY=($(compgen -W "monthly annual" -- "$current"))
            else
                COMPREPLY=($(compgen -W "--cycle" -- "$current"))
            fi
            ;;
        help)
            if [[ $COMP_CWORD -eq 2 ]]; then
                COMPREPLY=($(compgen -W "list add bootstrap remove rename default profile info login logout next set-renewal clear-renewal path" -- "$current"))
            fi
            ;;
        *)
            COMPREPLY=()
            ;;
    esac
}

_codex_projects_complete_bash() {
    local current
    current="${COMP_WORDS[COMP_CWORD]}"

    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "status history handoff list help --help" -- "$current"))
        return
    fi

    case "${COMP_WORDS[1]:-}" in
        handoff)
            if [[ "${COMP_WORDS[COMP_CWORD-1]}" == "--to-account" ]]; then
                COMPREPLY=($(compgen -W "$(_codex_pm_account_names)" -- "$current"))
            else
                COMPREPLY=($(compgen -W "--to-account --to-profile --reason --json" -- "$current"))
            fi
            ;;
        history)
            COMPREPLY=($(compgen -W "--limit -n --json" -- "$current"))
            ;;
        status|list)
            COMPREPLY=($(compgen -W "--json" -- "$current"))
            ;;
        help)
            if [[ $COMP_CWORD -eq 2 ]]; then
                COMPREPLY=($(compgen -W "status history handoff list" -- "$current"))
            fi
            ;;
        *)
            COMPREPLY=()
            ;;
    esac
}

_codexpm_complete_bash() {
    local current
    current="${COMP_WORDS[COMP_CWORD]}"

    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "version docs accounts projects replicate system help --help" -- "$current"))
        return
    fi

    case "${COMP_WORDS[1]:-}" in
        accounts)
            local shifted_words=("${COMP_WORDS[@]:1}")
            COMP_WORDS=("codex-accounts" "${shifted_words[@]}")
            COMP_CWORD=$((COMP_CWORD - 1))
            _codex_accounts_complete_bash
            ;;
        projects)
            local shifted_words=("${COMP_WORDS[@]:1}")
            COMP_WORDS=("codex-projects" "${shifted_words[@]}")
            COMP_CWORD=$((COMP_CWORD - 1))
            _codex_projects_complete_bash
            ;;
        replicate)
            COMPREPLY=($(compgen -W "export import --help" -- "$current"))
            ;;
        system)
            COMPREPLY=($(compgen -W "status install-codex upgrade-codex --help" -- "$current"))
            ;;
        docs)
            COMPREPLY=($(compgen -W "index readme getting-started accounts projects replication architecture spec --path --json" -- "$current"))
            ;;
        help)
            if [[ $COMP_CWORD -eq 2 ]]; then
                COMPREPLY=($(compgen -W "version docs accounts projects replicate system" -- "$current"))
            fi
            ;;
        *)
            COMPREPLY=()
            ;;
    esac
}

_codexpm_setup_completion() {
    if [[ -n "${BASH_VERSION:-}" ]]; then
        complete -o default -F _codex_complete_bash codex
        complete -o default -F _codex_accounts_complete_bash codex-accounts
        complete -o default -F _codex_projects_complete_bash codex-projects
        complete -o default -F _codexpm_complete_bash codexpm
        return
    fi

    if [[ -n "${ZSH_VERSION:-}" ]]; then
        _codex_zsh_from_bash() {
            local bash_func="$1"
            local -a COMPREPLY COMP_WORDS
            local COMP_CWORD
            COMP_WORDS=("${words[@]}")
            COMP_CWORD=$((CURRENT-1))
            "$bash_func"
            (( ${#COMPREPLY[@]} > 0 )) && compadd -- "${COMPREPLY[@]}"
        }

        _codex_complete_zsh() { _codex_zsh_from_bash _codex_complete_bash; }
        _codex_accounts_complete_zsh() { _codex_zsh_from_bash _codex_accounts_complete_bash; }
        _codex_projects_complete_zsh() { _codex_zsh_from_bash _codex_projects_complete_bash; }
        _codexpm_complete_zsh() { _codex_zsh_from_bash _codexpm_complete_bash; }

        compdef _codex_complete_zsh codex
        compdef _codex_accounts_complete_zsh codex-accounts
        compdef _codex_projects_complete_zsh codex-projects
        compdef _codexpm_complete_zsh codexpm
    fi
}

_codexpm_setup_completion

export -f codex codex-accounts codex-projects codexpm
