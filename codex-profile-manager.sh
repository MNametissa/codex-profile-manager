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
    _codex_pm_invoke accounts "$@"
}

codex-projects() {
    _codex_pm_invoke projects "$@"
}

codexpm() {
    _codex_pm_invoke "$@"
}

export -f codex codex-accounts codex-projects codexpm
