# account commands

cmd_accounts_list() {
    ensure_manager_dirs
    local default_account
    default_account="$(read_default_account)"

    echo "Codex accounts:"
    echo ""
    printf "  %-16s %-8s %-14s %-12s %s\n" "ACCOUNT" "AUTH" "STATE" "PROFILE" "LAST REFRESH"
    printf "  %-16s %-8s %-14s %-12s %s\n" "-------" "----" "-----" "-------" "------------"

    local account
    local found=0
    while IFS= read -r account; do
        [[ -n "$account" ]] || continue
        found=1

        local auth="no"
        account_is_logged_in "$account" && auth="yes"

        local state used reset plan
        IFS='|' read -r state used reset plan <<< "$(rate_limit_state_for_account "$account")"
        local default_profile
        default_profile="$(account_default_profile "$account")"
        local refresh
        refresh="$(account_last_refresh "$account")"
        [[ -z "$refresh" ]] && refresh="-"

        if [[ "$account" == "$default_account" ]]; then
            account="$account*"
        fi

        [[ -z "$default_profile" ]] && default_profile="-"
        printf "  %-16s %-8s %-14s %-12s %s\n" "$account" "$auth" "$state" "$default_profile" "$refresh"
    done < <(list_accounts)

    if [[ $found -eq 0 ]]; then
        echo "  (none)"
        echo ""
        echo "Bootstrap your current ~/.codex with: codex-accounts bootstrap default"
    fi
}

cmd_accounts_add() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Usage: codex-accounts add <name>" >&2
        return 1
    fi

    require_safe_name "$name" || return 1
    if account_exists "$name"; then
        echo "Account '$name' already exists" >&2
        return 1
    fi

    mkdir -p "$(account_dir "$name")"
    init_account_home "$name"
    [[ -f "$CODEX_PM_DEFAULT_ACCOUNT_FILE" ]] || write_default_account "$name"

    echo "Created account '$name'"
    echo "Login with: codex-accounts login $name"
}

cmd_accounts_bootstrap() {
    local name="${1:-default}"
    if [[ ! -d "$HOME/.codex" ]]; then
        echo "No ~/.codex directory found to import" >&2
        return 1
    fi

    bootstrap_from_current_codex_home "$name" || return 1
    echo "Imported ~/.codex into managed account '$name'"
    echo "Run: codex -u $name"
}

cmd_accounts_remove() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Usage: codex-accounts remove <name>" >&2
        return 1
    fi

    if ! account_exists "$name"; then
        echo "Account '$name' not found" >&2
        return 1
    fi

    local default_account
    default_account="$(read_default_account)"
    if [[ "$name" == "$default_account" ]]; then
        echo "Cannot remove default account '$name'. Change default first." >&2
        return 1
    fi

    rm -rf "$(account_dir "$name")"
    echo "Removed account '$name'"
}

cmd_accounts_rename() {
    local old_name="$1"
    local new_name="$2"
    if [[ -z "$old_name" || -z "$new_name" ]]; then
        echo "Usage: codex-accounts rename <old> <new>" >&2
        return 1
    fi

    require_safe_name "$new_name" || return 1
    account_exists "$old_name" || {
        echo "Account '$old_name' not found" >&2
        return 1
    }
    account_exists "$new_name" && {
        echo "Account '$new_name' already exists" >&2
        return 1
    }

    mv "$(account_dir "$old_name")" "$(account_dir "$new_name")"
    if [[ "$(read_default_account)" == "$old_name" ]]; then
        write_default_account "$new_name"
    fi

    echo "Renamed '$old_name' to '$new_name'"
}

cmd_accounts_default() {
    local name="$1"
    if [[ -z "$name" ]]; then
        echo "Default account: $(read_default_account)"
        return 0
    fi

    account_exists "$name" || {
        echo "Account '$name' not found" >&2
        return 1
    }

    write_default_account "$name"
    echo "Default account set to '$name'"
}

cmd_accounts_profile() {
    local name="$1"
    local profile_name="$2"
    if [[ -z "$name" ]]; then
        echo "Usage: codex-accounts profile <account> [config-profile]" >&2
        return 1
    fi

    account_exists "$name" || {
        echo "Account '$name' not found" >&2
        return 1
    }

    if [[ -z "$profile_name" ]]; then
        local current
        current="$(account_default_profile "$name")"
        [[ -z "$current" ]] && current="(none)"
        echo "Default config profile for '$name': $current"
        return 0
    fi

    write_account_meta_value "$name" "default_profile" "$profile_name"
    echo "Default config profile for '$name' set to '$profile_name'"
}

cmd_accounts_info() {
    local name="${1:-$(read_default_account)}"
    account_exists "$name" || {
        echo "Account '$name' not found" >&2
        return 1
    }

    local home_dir
    home_dir="$(account_home "$name")"
    local profile_name
    profile_name="$(account_default_profile "$name")"
    [[ -z "$profile_name" ]] && profile_name="(none)"

    echo "Account: $name"
    echo "Home: $home_dir"
    echo "Default config profile: $profile_name"
    local auth_mode
    auth_mode="$(account_auth_mode "$name")"
    [[ -z "$auth_mode" ]] && auth_mode="unknown"
    echo "Auth mode: $auth_mode"
    if account_is_logged_in "$name"; then
        echo "Status: logged in"
    else
        echo "Status: not logged in"
    fi

    local refresh
    refresh="$(account_last_refresh "$name")"
    [[ -n "$refresh" ]] && echo "Last refresh: $refresh"

    local state used reset plan
    IFS='|' read -r state used reset plan <<< "$(rate_limit_state_for_account "$name")"
    echo "Availability: $state"
    [[ -n "$used" ]] && echo "Used percent: $used"
    [[ -n "$reset" ]] && echo "Resets at: $reset"
    [[ -n "$plan" ]] && echo "Plan hint: $plan"
}

cmd_accounts_login() {
    local name="${1:-$(read_default_account)}"
    if [[ -n "$1" && "$1" != -* ]]; then
        shift
    fi

    account_exists "$name" || {
        echo "Account '$name' not found" >&2
        return 1
    }
    init_account_home "$name"

    CODEX_HOME="$(account_home "$name")" command codex login "$@"
}

cmd_accounts_logout() {
    local name="${1:-$(read_default_account)}"
    if [[ -n "$1" && "$1" != -* ]]; then
        shift
    fi

    account_exists "$name" || {
        echo "Account '$name' not found" >&2
        return 1
    }

    CODEX_HOME="$(account_home "$name")" command codex logout "$@"
}

cmd_accounts_next() {
    echo "Account availability:"
    echo ""

    local account
    while IFS= read -r account; do
        [[ -n "$account" ]] || continue

        local state used reset plan
        IFS='|' read -r state used reset plan <<< "$(rate_limit_state_for_account "$account")"
        case "$state" in
            available)
                printf "  ok %-14s available" "$account"
                [[ -n "$used" ]] && printf " (used %s%%)" "$used"
                printf "\n"
                ;;
            likely-limited)
                printf "  wait %-12s limited" "$account"
                [[ -n "$reset" ]] && printf " until %s" "$reset"
                printf "\n"
                ;;
            unauthenticated)
                printf "  noauth %-10s not logged in\n" "$account"
                ;;
            *)
                printf "  unknown %-8s unknown\n" "$account"
                ;;
        esac
    done < <(list_accounts)
}

cmd_accounts_path() {
    echo "$CODEX_PM_INSTALL_DIR"
}

cmd_accounts_self_uninstall() {
    local shell_rc
    if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == *"zsh"* ]]; then
        shell_rc="$HOME/.zshrc"
    else
        shell_rc="$HOME/.bashrc"
    fi

    echo "This removes Codex Profile Manager code from $CODEX_PM_INSTALL_DIR."
    echo "Managed account homes and project ledgers will also be removed."
    echo "Type UNINSTALL to continue:"
    read -r reply
    [[ "$reply" == "UNINSTALL" ]] || {
        echo "Cancelled"
        return 0
    }

    if [[ -f "$shell_rc" ]]; then
        sed -i '/# Codex Profile Manager/d' "$shell_rc"
        sed -i '/codex-profile-manager.sh/d' "$shell_rc"
    fi

    rm -rf "$CODEX_PM_INSTALL_DIR"
    echo "Uninstalled. Reload your shell."
}
