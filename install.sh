#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${CODEX_PM_HOME:-$HOME/.local/share/codex-profile-manager}"
INSTALL_SCRIPT="$INSTALL_DIR/codex-profile-manager.sh"
PYTHON_BIN="${PYTHON_BIN:-python3}"

if [[ -n "${ZSH_VERSION:-}" ]] || [[ "${SHELL:-}" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
    SHELL_NAME="zsh"
else
    SHELL_RC="$HOME/.bashrc"
    SHELL_NAME="bash"
fi

echo "=================================="
echo "Codex Profile Manager Installer"
echo "=================================="
echo "Shell: $SHELL_NAME"
echo "Config: $SHELL_RC"
echo "Install: $INSTALL_DIR"
echo ""

mkdir -p "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR/docs/specs"
mkdir -p "$INSTALL_DIR/scripts"
mkdir -p "$INSTALL_DIR/src"

cp "$SCRIPT_DIR/codex-profile-manager.sh" "$INSTALL_SCRIPT"
cp "$SCRIPT_DIR/README.md" "$INSTALL_DIR/README.md"
cp "$SCRIPT_DIR/install.sh" "$INSTALL_DIR/install.sh"
cp "$SCRIPT_DIR/clean.sh" "$INSTALL_DIR/clean.sh"
cp "$SCRIPT_DIR/pyproject.toml" "$INSTALL_DIR/pyproject.toml"
cp "$SCRIPT_DIR/docs/specs/"*.md "$INSTALL_DIR/docs/specs/" 2>/dev/null || true
cp "$SCRIPT_DIR/scripts/"*.sh "$INSTALL_DIR/scripts/" 2>/dev/null || true
rm -rf "$INSTALL_DIR/src/codex_profile_manager"
cp -r "$SCRIPT_DIR/src/codex_profile_manager" "$INSTALL_DIR/src/"

chmod +x "$INSTALL_DIR/install.sh" "$INSTALL_DIR/clean.sh" "$INSTALL_SCRIPT" "$INSTALL_DIR/scripts/"*.sh 2>/dev/null || true

if [[ ! -d "$INSTALL_DIR/.venv" ]]; then
    "$PYTHON_BIN" -m venv "$INSTALL_DIR/.venv"
fi

"$INSTALL_DIR/.venv/bin/python" -m pip install --upgrade pip >/dev/null
"$INSTALL_DIR/.venv/bin/pip" install -e "$INSTALL_DIR" >/dev/null

if grep -q "codex-profile-manager.sh" "$SHELL_RC" 2>/dev/null; then
    echo "Source line already present in $SHELL_RC"
else
    cat >> "$SHELL_RC" << EOF

# Codex Profile Manager
export CODEX_PM_HOME="$INSTALL_DIR"
[[ -f "$INSTALL_SCRIPT" ]] && source "$INSTALL_SCRIPT"
EOF
    echo "Added source line to $SHELL_RC"
fi

source "$INSTALL_SCRIPT"

if [[ -d "$HOME/.codex" ]] && [[ ! -d "$INSTALL_DIR/accounts/default" ]]; then
    echo ""
    echo "Import current ~/.codex into managed account 'default'? [Y/n]"
    read -r reply
    if [[ -z "$reply" || "$reply" =~ ^[Yy] ]]; then
        codex-accounts bootstrap default
    fi
fi

echo ""
echo "Installed successfully."
echo "Reload your shell with: source $SHELL_RC"
echo "Then run: codex-accounts list"
