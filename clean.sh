#!/bin/bash
set -euo pipefail

INSTALL_DIR="${CODEX_PM_HOME:-$HOME/.local/share/codex-profile-manager}"

if [[ -n "${ZSH_VERSION:-}" ]] || [[ "${SHELL:-}" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
else
    SHELL_RC="$HOME/.bashrc"
fi

if [[ -f "$SHELL_RC" ]]; then
    sed -i '/# Codex Profile Manager/d' "$SHELL_RC"
    sed -i '/export CODEX_PM_HOME=.*codex-profile-manager/d' "$SHELL_RC"
    sed -i '/codex-profile-manager.sh/d' "$SHELL_RC"
fi

echo "Removed shell integration from $SHELL_RC"
echo "Managed data is still present in $INSTALL_DIR"
