#!/usr/bin/env bash
# install.sh - Entry point for OpenCode installation
#
# Self-contained installer for OpenCode on NixOS.
# Single-phase installation since opencode is available in nixpkgs.
#
# Usage: ./install.sh
#
# Assumes:
#   - NixOS base system (unstable channel recommended for latest opencode)
#   - Script directory contains opencode.nix
#
# Notes:
#   - No authentication configured (unsecured - suitable for local network use)
#   - Runs as 'opencode' user for security

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== OpenCode Installation ==="
echo "Script directory: $SCRIPT_DIR"
echo ""
echo "NOTE: Authentication is not configured."
echo "      The server will run unsecured (suitable for local network use)."
echo ""

# Phase 1: NixOS Prerequisites and Service
echo "=== Phase 1: NixOS Configuration ==="
if grep -q "opencode.nix" /etc/nixos/configuration.nix; then
    echo "OpenCode already in configuration.nix, skipping..."
else
    sed -i 's|./incus.nix|./incus.nix\n    '"$SCRIPT_DIR"'/opencode.nix|' /etc/nixos/configuration.nix
fi
sudo nixos-rebuild switch

echo ""
echo "=== OpenCode Installation Complete ==="
echo "Service status: systemctl status opencode"
echo "Web UI: http://localhost:4096/"
echo ""
echo "NOTE: No authentication is configured."
echo "      Add OPENCODE_SERVER_PASSWORD environment variable for security."
