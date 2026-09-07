#!/usr/bin/env bash
# Launches the Matrix extras installer TUI.
# Run this after bootstrap.sh to set up optional modules:
# shell, snapshots, fingerprint, NVIDIA, printers, etc.

SCRIPT="$HOME/.config/matrix/scripts/install-matrix.sh"

if [ ! -f "$SCRIPT" ]; then
    echo "Error: install-matrix.sh not found at $SCRIPT"
    echo "Make sure bootstrap.sh has completed and dotfiles are stowed."
    exit 1
fi

bash "$SCRIPT"
