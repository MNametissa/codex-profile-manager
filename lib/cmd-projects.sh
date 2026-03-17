# project continuity commands

cmd_projects_status() {
    local path="${1:-$(pwd)}"
    local root
    root="$(resolve_project_root "$path")" || return 1
    ensure_project_ledger "$root"

    local dir
    dir="$(project_dir "$root")"
    echo "Project root: $root"
    echo "Project id: $(project_id_for_root "$root")"
    echo "Ledger: $dir"

    local lock_file
    lock_file="$(project_lock_file "$root")"
    if [[ -f "$lock_file" ]]; then
        echo ""
        echo "Active lock:"
        cat "$lock_file"
    fi

    local last_event
    last_event="$(project_last_event "$root")"
    if [[ -n "$last_event" ]]; then
        echo ""
        echo "Last event:"
        if command -v jq >/dev/null 2>&1; then
            echo "$last_event" | jq .
        else
            echo "$last_event"
        fi
    fi

    local last_handoff
    last_handoff="$(project_last_handoff "$root")"
    if [[ -n "$last_handoff" ]]; then
        echo ""
        echo "Last handoff:"
        if command -v jq >/dev/null 2>&1; then
            echo "$last_handoff" | jq .
        else
            echo "$last_handoff"
        fi
    fi
}

cmd_projects_history() {
    local path="$(pwd)"
    local limit=20

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --limit|-n)
                limit="$2"
                shift 2
                ;;
            *)
                path="$1"
                shift
                ;;
        esac
    done

    local root
    root="$(resolve_project_root "$path")" || return 1
    local activity_file
    activity_file="$(project_dir "$root")/activity.jsonl"

    if [[ ! -f "$activity_file" ]]; then
        echo "No activity history for $root"
        return 0
    fi

    echo "Project history for $root"
    echo ""
    if command -v jq >/dev/null 2>&1; then
        tail -n "$limit" "$activity_file" | jq -r '"  \(.timestamp) | \(.account_id) | \(.config_profile // "-") | \(.event_type) | \(.summary)"'
    else
        tail -n "$limit" "$activity_file"
    fi
}

cmd_projects_handoff() {
    local path="$(pwd)"
    local to_account=""
    local to_profile=""
    local reason="manual handoff"

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --to-account)
                to_account="$2"
                shift 2
                ;;
            --to-profile)
                to_profile="$2"
                shift 2
                ;;
            --reason)
                reason="$2"
                shift 2
                ;;
            *)
                path="$1"
                shift
                ;;
        esac
    done

    if [[ -z "$to_account" ]]; then
        echo "Usage: codex-projects handoff --to-account <name> [--to-profile <profile>] [--reason <text>] [path]" >&2
        return 1
    fi

    account_exists "$to_account" || {
        echo "Target account '$to_account' not found" >&2
        return 1
    }

    local root
    root="$(resolve_project_root "$path")" || return 1
    ensure_project_ledger "$root"
    local dir
    dir="$(project_dir "$root")"

    local last_event_json
    last_event_json="$(project_last_event "$root")"
    local from_account=""
    local from_profile=""
    local from_session=""
    if [[ -n "$last_event_json" && -n "$(command -v jq)" ]]; then
        from_account="$(echo "$last_event_json" | jq -r '.account_id // empty' 2>/dev/null)"
        from_profile="$(echo "$last_event_json" | jq -r '.config_profile // empty' 2>/dev/null)"
        from_session="$(echo "$last_event_json" | jq -r '.session_id // empty' 2>/dev/null)"
    fi

    [[ -z "$to_profile" ]] && to_profile="$(account_default_profile "$to_account")"

    local note_file
    note_file="$dir/notes/handoff-$(date +%Y%m%d-%H%M%S)-to-${to_account}.md"
    local git_status=""
    git_status="$(git -C "$root" status --short 2>/dev/null || true)"
    local recent_history=""
    recent_history="$(tail -n 10 "$dir/activity.jsonl" 2>/dev/null)"

    cat > "$note_file" << EOF
# Project Handoff

- Project root: $root
- Created at: $(now_utc)
- From account: ${from_account:-unknown}
- From profile: ${from_profile:-unknown}
- To account: $to_account
- To profile: ${to_profile:-none}
- Reason: $reason
- Last session id: ${from_session:-unknown}

## Resume Instructions

- Open the same project root.
- Read the recent history below.
- Continue from the current git branch.
- Validate uncommitted changes before making new edits.

## Open Risks

- Review working tree state before continuing.
- Reconstruct short-term intent from the recent activity and current diff.

## Git Status

\`\`\`text
$git_status
\`\`\`

## Recent Activity

\`\`\`json
$recent_history
\`\`\`
EOF

    printf '{"timestamp":"%s","project_id":"%s","from_account_id":"%s","to_account_id":"%s","from_session_id":"%s","to_profile":"%s","reason":"%s","resume_instructions":"%s","open_risks":"%s","note_file":"%s"}\n' \
        "$(now_utc)" \
        "$(json_escape "$(project_id_for_root "$root")")" \
        "$(json_escape "$from_account")" \
        "$(json_escape "$to_account")" \
        "$(json_escape "$from_session")" \
        "$(json_escape "$to_profile")" \
        "$(json_escape "$reason")" \
        "$(json_escape "Open $note_file and continue from the same project root.")" \
        "$(json_escape "Validate working tree and recent history before editing.")" \
        "$(json_escape "$note_file")" \
        >> "$dir/handoffs.jsonl"

    log_project_event "$root" "$to_account" "$to_profile" "$from_session" "handoff_created" "handoff to $to_account: $reason"

    echo "Handoff note created:"
    echo "  $note_file"
    echo ""
    echo "Resume with:"
    if [[ -n "$to_profile" ]]; then
        echo "  codex -u $to_account -p $to_profile"
    else
        echo "  codex -u $to_account"
    fi
}

cmd_projects_list() {
    ensure_manager_dirs
    echo "Tracked projects:"
    echo ""

    local dir
    local found=0
    for dir in "$CODEX_PM_PROJECTS_DIR"/*; do
        [[ -d "$dir" ]] || continue
        found=1
        local project_file="$dir/project.toml"
        local root="-"
        if [[ -f "$project_file" ]]; then
            root="$(grep '^project_root = ' "$project_file" | head -1 | cut -d'"' -f2)"
        fi
        printf "  %-18s %s\n" "$(basename "$dir")" "$root"
    done

    [[ $found -eq 0 ]] && echo "  (none)"
}
