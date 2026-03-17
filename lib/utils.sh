# Shared helpers

ensure_manager_dirs() {
    mkdir -p "$CODEX_PM_ACCOUNTS_DIR" "$CODEX_PM_PROJECTS_DIR"
}

now_utc() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

slugify_name() {
    local value="$1"
    value="${value// /-}"
    value="$(echo "$value" | sed 's/[^A-Za-z0-9._-]/-/g')"
    value="$(echo "$value" | sed 's/--*/-/g; s/^-//; s/-$//')"
    printf '%s' "$value"
}

require_safe_name() {
    local safe
    safe="$(slugify_name "$1")"
    if [[ -z "$safe" || "$safe" != "$1" ]]; then
        echo "Invalid name '$1'. Use letters, digits, dot, underscore, and hyphen only." >&2
        return 1
    fi
}

account_dir() {
    echo "$CODEX_PM_ACCOUNTS_DIR/$1"
}

account_home() {
    echo "$(account_dir "$1")/home"
}

account_meta() {
    echo "$(account_dir "$1")/meta.env"
}

account_exists() {
    [[ -d "$(account_dir "$1")" ]]
}

list_accounts() {
    ensure_manager_dirs
    for dir in "$CODEX_PM_ACCOUNTS_DIR"/*; do
        [[ -d "$dir" ]] || continue
        basename "$dir"
    done | sort
}

read_default_account() {
    if [[ -n "$CODEX_PM_CURRENT_ACCOUNT" ]]; then
        printf '%s' "$CODEX_PM_CURRENT_ACCOUNT"
    elif [[ -f "$CODEX_PM_DEFAULT_ACCOUNT_FILE" ]]; then
        cat "$CODEX_PM_DEFAULT_ACCOUNT_FILE"
    else
        printf 'default'
    fi
}

write_default_account() {
    printf '%s\n' "$1" > "$CODEX_PM_DEFAULT_ACCOUNT_FILE"
}

init_account_meta() {
    local name="$1"
    local meta_file
    meta_file="$(account_meta "$name")"
    if [[ ! -f "$meta_file" ]]; then
        cat > "$meta_file" << EOF
created_at='$(now_utc)'
default_profile=''
EOF
    fi
}

init_account_home() {
    local name="$1"
    local home_dir
    home_dir="$(account_home "$name")"

    mkdir -p "$home_dir"
    init_account_meta "$name"

    if [[ ! -f "$home_dir/config.toml" ]]; then
        cat > "$home_dir/config.toml" << 'EOF'
approval_policy = "on-request"
sandbox_mode = "workspace-write"

[history]
persistence = "save-all"
max_bytes = 10485760
EOF
    fi
}

read_account_meta_value() {
    local name="$1"
    local key="$2"
    local meta_file
    meta_file="$(account_meta "$name")"
    [[ -f "$meta_file" ]] || return 0
    local value
    value="$(grep -E "^${key}=" "$meta_file" | head -1 | cut -d= -f2-)"
    value="${value#\'}"
    value="${value%\'}"
    printf '%s' "$value"
}

write_account_meta_value() {
    local name="$1"
    local key="$2"
    local value="$3"
    local meta_file
    meta_file="$(account_meta "$name")"
    init_account_meta "$name"

    if grep -q -E "^${key}=" "$meta_file"; then
        sed -i "s|^${key}=.*$|${key}='${value//\'/}'|" "$meta_file"
    else
        printf "%s='%s'\n" "$key" "$value" >> "$meta_file"
    fi
}

account_default_profile() {
    read_account_meta_value "$1" "default_profile"
}

copy_codex_home_tree() {
    local src="$1"
    local dest="$2"
    mkdir -p "$dest"
    if [[ -d "$src" ]]; then
        cp -a "$src/." "$dest/"
    fi
}

bootstrap_from_current_codex_home() {
    local name="$1"
    require_safe_name "$name" || return 1
    if account_exists "$name"; then
        echo "Account '$name' already exists" >&2
        return 1
    fi

    mkdir -p "$(account_dir "$name")"
    copy_codex_home_tree "$HOME/.codex" "$(account_home "$name")"
    init_account_meta "$name"
    [[ -f "$CODEX_PM_DEFAULT_ACCOUNT_FILE" ]] || write_default_account "$name"
}

account_is_logged_in() {
    [[ -f "$(account_home "$1")/auth.json" ]]
}

account_auth_mode() {
    local auth_file
    auth_file="$(account_home "$1")/auth.json"
    [[ -f "$auth_file" ]] || return 0

    if command -v jq >/dev/null 2>&1; then
        jq -r '.auth_mode // empty' "$auth_file" 2>/dev/null
    else
        grep -o '"auth_mode":[[:space:]]*"[^"]*"' "$auth_file" | head -1 | cut -d'"' -f4
    fi
}

account_last_refresh() {
    local auth_file
    auth_file="$(account_home "$1")/auth.json"
    [[ -f "$auth_file" ]] || return 0

    if command -v jq >/dev/null 2>&1; then
        jq -r '.last_refresh // empty' "$auth_file" 2>/dev/null
    fi
}

resolve_project_root() {
    local path="${1:-$(pwd)}"
    local root

    root="$(cd "$path" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null)" || true
    if [[ -n "$root" ]]; then
        printf '%s' "$root"
    else
        cd "$path" 2>/dev/null && pwd -P
    fi
}

project_id_for_root() {
    local root="$1"
    printf '%s' "$root" | sha256sum | cut -c1-16
}

project_dir() {
    local root="$1"
    echo "$CODEX_PM_PROJECTS_DIR/$(project_id_for_root "$root")"
}

project_lock_file() {
    local root="$1"
    echo "$(project_dir "$root")/active.lock"
}

ensure_project_ledger() {
    local root="$1"
    local dir
    dir="$(project_dir "$root")"
    mkdir -p "$dir/notes" "$dir/snapshots"

    if [[ ! -f "$dir/project.toml" ]]; then
        cat > "$dir/project.toml" << EOF
project_id = "$(project_id_for_root "$root")"
project_root = "$(printf '%s' "$root" | sed 's/"/\\"/g')"
created_at = "$(now_utc)"
EOF
    fi
}

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    value="${value//$'\r'/\\r}"
    value="${value//$'\t'/\\t}"
    printf '%s' "$value"
}

git_branch_for_root() {
    git -C "$1" rev-parse --abbrev-ref HEAD 2>/dev/null || printf ''
}

git_head_for_root() {
    git -C "$1" rev-parse HEAD 2>/dev/null || printf ''
}

new_session_id() {
    printf '%s-%s-%s' "$(date +%Y%m%d%H%M%S)" "$$" "${RANDOM:-0}"
}

trackable_codex_command() {
    local first="$1"
    case "$first" in
        ""|exec|review|resume|fork|cloud)
            return 0
            ;;
        login|logout|mcp|mcp-server|app-server|completion|sandbox|debug|features|help|--help|-h|--version|-V)
            return 1
            ;;
        *)
            [[ "$first" == -* ]] && return 0
            return 0
            ;;
    esac
}

detect_first_codex_token() {
    local -a args=("$@")
    local arg
    for arg in "${args[@]}"; do
        if [[ "$arg" != -* ]]; then
            printf '%s' "$arg"
            return 0
        fi
    done
    printf ''
}

has_profile_arg() {
    local prev=""
    local arg
    for arg in "$@"; do
        if [[ "$prev" == "-p" || "$prev" == "--profile" ]]; then
            return 0
        fi
        case "$arg" in
            -p|--profile|--profile=*)
                return 0
                ;;
        esac
        prev="$arg"
    done
    return 1
}

log_project_event() {
    local root="$1"
    local account="$2"
    local config_profile="$3"
    local session_id="$4"
    local event_type="$5"
    local summary="$6"
    local exit_code="${7:-}"
    local dir

    ensure_project_ledger "$root"
    dir="$(project_dir "$root")"

    printf '{"timestamp":"%s","project_id":"%s","project_root":"%s","account_id":"%s","config_profile":"%s","session_id":"%s","cwd":"%s","git_branch":"%s","git_commit_head":"%s","event_type":"%s","summary":"%s","exit_code":"%s"}\n' \
        "$(now_utc)" \
        "$(json_escape "$(project_id_for_root "$root")")" \
        "$(json_escape "$root")" \
        "$(json_escape "$account")" \
        "$(json_escape "$config_profile")" \
        "$(json_escape "$session_id")" \
        "$(json_escape "$(pwd -P)")" \
        "$(json_escape "$(git_branch_for_root "$root")")" \
        "$(json_escape "$(git_head_for_root "$root")")" \
        "$(json_escape "$event_type")" \
        "$(json_escape "$summary")" \
        "$(json_escape "$exit_code")" \
        >> "$dir/activity.jsonl"

    write_account_meta_value "$account" "last_used_at" "$(now_utc)"
}

latest_session_file_for_account() {
    local home_dir
    home_dir="$(account_home "$1")"
    [[ -d "$home_dir/sessions" ]] || return 0
    find "$home_dir/sessions" -type f -print0 2>/dev/null | xargs -0 ls -1t 2>/dev/null | head -1
}

rate_limit_summary_for_account() {
    local name="$1"
    local latest_file
    latest_file="$(latest_session_file_for_account "$name")"
    [[ -n "$latest_file" && -f "$latest_file" ]] || return 0

    if command -v jq >/dev/null 2>&1; then
        jq -r '
            select(.type == "event_msg" and .payload.type == "token_count")
            | [
                (.payload.rate_limits.primary.used_percent // ""),
                (.payload.rate_limits.primary.resets_at // ""),
                (.payload.rate_limits.plan_type // ""),
                (.payload.rate_limits.credits.has_credits // "")
              ]
            | @tsv
        ' "$latest_file" 2>/dev/null | tail -1
    fi
}

rate_limit_state_for_account() {
    local name="$1"
    if ! account_is_logged_in "$name"; then
        printf 'unauthenticated|||'
        return 0
    fi

    local summary
    summary="$(rate_limit_summary_for_account "$name")"
    if [[ -z "$summary" ]]; then
        printf 'unknown|||'
        return 0
    fi

    local used reset plan credits
    IFS=$'\t' read -r used reset plan credits <<< "$summary"

    if [[ -n "$used" && "$used" != "null" ]]; then
        local used_int="${used%.*}"
        if [[ -n "$used_int" && "$used_int" -ge 99 ]]; then
            printf 'likely-limited|%s|%s|%s' "$used" "$reset" "$plan"
            return 0
        fi
    fi

    printf 'available|%s|%s|%s' "$used" "$reset" "$plan"
}

project_last_event() {
    local root="$1"
    local activity_file
    activity_file="$(project_dir "$root")/activity.jsonl"
    [[ -f "$activity_file" ]] || return 0
    tail -1 "$activity_file"
}

project_last_handoff() {
    local root="$1"
    local handoff_file
    handoff_file="$(project_dir "$root")/handoffs.jsonl"
    [[ -f "$handoff_file" ]] || return 0
    tail -1 "$handoff_file"
}

project_latest_handoff_note_for_account() {
    local root="$1"
    local account="$2"
    local handoff_file
    handoff_file="$(project_dir "$root")/handoffs.jsonl"
    [[ -f "$handoff_file" ]] || return 0

    if command -v jq >/dev/null 2>&1; then
        jq -r --arg account "$account" '
            select(.to_account_id == $account)
            | .note_file // empty
        ' "$handoff_file" 2>/dev/null | tail -1
    fi
}

project_last_account() {
    local root="$1"
    local activity_file
    activity_file="$(project_dir "$root")/activity.jsonl"
    [[ -f "$activity_file" ]] || return 0

    if command -v jq >/dev/null 2>&1; then
        jq -r '.account_id // empty' "$activity_file" 2>/dev/null | tail -1
    fi
}

acquire_project_lock() {
    local root="$1"
    local account="$2"
    local session_id="$3"
    local lock_file

    ensure_project_ledger "$root"
    lock_file="$(project_lock_file "$root")"

    if [[ -f "$lock_file" ]]; then
        local locked_pid locked_account locked_session
        locked_pid="$(grep '^pid=' "$lock_file" | cut -d= -f2)"
        locked_account="$(grep '^account=' "$lock_file" | cut -d= -f2)"
        locked_session="$(grep '^session_id=' "$lock_file" | cut -d= -f2)"

        if [[ -n "$locked_pid" ]] && kill -0 "$locked_pid" 2>/dev/null; then
            echo "Project is already locked by account '$locked_account' (session $locked_session, pid $locked_pid)." >&2
            echo "Finish that session first, or set CODEX_PM_IGNORE_LOCK=1 to bypass." >&2
            [[ "$CODEX_PM_IGNORE_LOCK" == "1" ]] && return 0
            return 1
        fi
    fi

    cat > "$lock_file" << EOF
pid=$$
account=$account
session_id=$session_id
timestamp=$(now_utc)
cwd=$(pwd -P)
EOF
}

release_project_lock() {
    local root="$1"
    local session_id="$2"
    local lock_file
    lock_file="$(project_lock_file "$root")"
    [[ -f "$lock_file" ]] || return 0

    local locked_session
    locked_session="$(grep '^session_id=' "$lock_file" | cut -d= -f2)"
    if [[ "$locked_session" == "$session_id" ]]; then
        rm -f "$lock_file"
    fi
}
