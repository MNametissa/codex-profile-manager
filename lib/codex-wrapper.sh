# codex wrapper

codex() {
    ensure_manager_dirs

    local account
    account="$(read_default_account)"
    local -a codex_args=()
    local arg

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

    require_safe_name "$account" || return 1
    if ! account_exists "$account"; then
        echo "Account '$account' not found." >&2
        echo "Create it with: codex-accounts add $account" >&2
        echo "Or import current ~/.codex with: codex-accounts bootstrap $account" >&2
        return 1
    fi

    init_account_home "$account"

    local account_home_dir
    account_home_dir="$(account_home "$account")"
    local default_profile
    default_profile="$(account_default_profile "$account")"

    if [[ -n "$default_profile" ]] && ! has_profile_arg "${codex_args[@]}"; then
        codex_args=(-p "$default_profile" "${codex_args[@]}")
    fi

    local first_token
    first_token="$(detect_first_codex_token "${codex_args[@]}")"
    local track_project=false
    if trackable_codex_command "$first_token"; then
        track_project=true
    fi

    local project_root=""
    local session_id=""
    local active_profile="$default_profile"
    local prev=""
    for arg in "${codex_args[@]}"; do
        if [[ "$prev" == "-p" || "$prev" == "--profile" ]]; then
            active_profile="$arg"
            break
        fi
        case "$arg" in
            --profile=*)
                active_profile="${arg#*=}"
                break
                ;;
        esac
        prev="$arg"
    done

    echo "Using Codex account: $account"
    [[ -n "$active_profile" ]] && echo "Using config profile: $active_profile"

    if [[ "$track_project" == true ]]; then
        project_root="$(resolve_project_root "$(pwd)")"
        session_id="$(new_session_id)"
        acquire_project_lock "$project_root" "$account" "$session_id" || return 1

        local last_account
        last_account="$(project_last_account "$project_root")"
        if [[ -n "$last_account" && "$last_account" != "$account" ]]; then
            echo "Resume hint: last tracked activity on this project used account '$last_account'."
        fi

        local handoff_note
        handoff_note="$(project_latest_handoff_note_for_account "$project_root" "$account")"
        if [[ -n "$handoff_note" ]]; then
            echo "Resume hint: handoff note available at $handoff_note"
        fi

        log_project_event "$project_root" "$account" "$active_profile" "$session_id" "session_started" "codex ${codex_args[*]}"
    fi

    CODEX_PM_CURRENT_ACCOUNT="$account" CODEX_HOME="$account_home_dir" command codex "${codex_args[@]}"
    local exit_code=$?

    if [[ "$track_project" == true ]]; then
        log_project_event "$project_root" "$account" "$active_profile" "$session_id" "session_exited" "codex ${codex_args[*]}" "$exit_code"
        release_project_lock "$project_root" "$session_id"
    fi

    return "$exit_code"
}
