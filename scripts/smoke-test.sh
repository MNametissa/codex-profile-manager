#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CACHE_ROOT="${XDG_CACHE_HOME:-$HOME/.cache}"
mkdir -p "$CACHE_ROOT"
TEST_HOME="$(mktemp -d "$CACHE_ROOT/codex-profile-manager-smoke-XXXXXX")"

cleanup() {
    rm -rf "$TEST_HOME"
}
trap cleanup EXIT

HOME="$TEST_HOME" bash -lc "
source '$REPO_DIR/codex-profile-manager.sh'
codex-accounts add primary >/dev/null
codex-accounts add backup >/dev/null
codex-accounts profile backup review >/dev/null
mkdir -p \"\$HOME/project\"
cd \"\$HOME/project\"
codex -u primary exec 'hello' >/dev/null 2>/dev/null || true
codex-projects handoff --to-account backup --reason 'smoke test' >/dev/null
codex -u backup exec 'resume' >/dev/null 2>/dev/null || true
codex-projects history >/dev/null
test -f \"\$HOME/.local/share/codex-profile-manager/projects/\$(printf %s \"\$HOME/project\" | sha256sum | cut -c1-16)/activity.jsonl\"
"

echo "Smoke test passed."
