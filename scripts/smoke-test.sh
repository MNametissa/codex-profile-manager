#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$CACHE_ROOT"
TEST_HOME="$(mktemp -d "$CACHE_ROOT/codex-profile-manager-smoke-XXXXXX")"
VENV_DIR="$REPO_DIR/.venv"

cleanup() {
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

if [[ ! -d "$VENV_DIR" ]]; then
    python3 -m venv "$VENV_DIR"
fi

"$VENV_DIR/bin/python" -m pip install --upgrade pip >/dev/null
"$VENV_DIR/bin/pip" install -e "$REPO_DIR" >/dev/null

HOME="$TEST_HOME" bash -lc "
set -e
export CODEX_PM_HOME=\"\$HOME/.local/share/codex-profile-manager\"
source '$REPO_DIR/codex-profile-manager.sh'
codex-accounts add primary >/dev/null
codex-accounts add backup >/dev/null
codex-accounts profile backup review >/dev/null
codex-accounts set-renewal backup 2030-01-15 --cycle monthly >/dev/null
mkdir -p \"\$HOME/project\"
cd \"\$HOME/project\"
codex -u primary exec 'hello' >/dev/null 2>/dev/null || true
codex-projects handoff --to-account backup --reason 'smoke test' >/dev/null
codex-accounts info backup --json >/dev/null
codex-projects history >/dev/null
'$VENV_DIR/bin/python' -m codex_profile_manager replicate export \"\$HOME/bundle.tgz\" --include-projects >/dev/null
test -f \"\$HOME/bundle.tgz\"
test -f \"\$HOME/.local/share/codex-profile-manager/projects/\$(printf %s \"\$HOME/project\" | sha256sum | cut -c1-16)/activity.jsonl\"
"

echo "Smoke test passed."
