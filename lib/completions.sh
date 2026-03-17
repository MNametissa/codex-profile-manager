# shell completions

if [[ -n "$BASH_VERSION" ]]; then
    _codex_accounts_completion() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local commands="list add bootstrap remove rename default profile info login logout next path self-uninstall"
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
    }
    complete -F _codex_accounts_completion codex-accounts

    _codex_projects_completion() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local commands="status history handoff list"
        COMPREPLY=($(compgen -W "$commands" -- "$cur"))
    }
    complete -F _codex_projects_completion codex-projects

    _codex_wrapper_completion() {
        local cur="${COMP_WORDS[COMP_CWORD]}"
        local prev="${COMP_WORDS[COMP_CWORD-1]}"

        if [[ "$prev" == "-u" || "$prev" == "--user" || "$prev" == "--account" ]]; then
            local accounts
            accounts="$(list_accounts 2>/dev/null)"
            COMPREPLY=($(compgen -W "$accounts" -- "$cur"))
        fi
    }
    complete -F _codex_wrapper_completion codex
fi
