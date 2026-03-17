#!/bin/bash
set -e

if [[ -n "$ZSH_VERSION" ]] || [[ "$SHELL" == *"zsh"* ]]; then
    SHELL_RC="$HOME/.zshrc"
else
    SHELL_RC="$HOME/.bashrc"
fi

if [[ -f "$SHELL_RC" ]]; then
    sed -i '/# Codex Profile Manager/d' "$SHELL_RC"
    sed -i '/codex-profile-manager.sh/d' "$SHELL_RC"
    echo "Removed Codex Profile Manager source line from $SHELL_RC"
fi
