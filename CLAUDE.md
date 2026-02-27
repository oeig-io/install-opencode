# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an OpenCode deployment automation framework for NixOS. It provides a single-phase installation since OpenCode is available in nixpkgs (unstable channel).

## Architecture

The installation follows a single-phase approach:

1. **Phase 1 - NixOS Configuration** (`opencode.nix`): 
   - OpenCode package from nixpkgs
   - `opencode` system user with home directory `/home/opencode`
   - systemd service definition

Key design decisions:
- Single-phase installation (no Ansible needed)
- Runs as dedicated `opencode` user for security
- Uses `opencode web` command which provides both web UI and API
- No authentication configured by default (suitable for local network use)
- Container proxy handles external access (not direct firewall exposure)

## Key Commands

```bash
# Full installation
./install.sh

# Service management
systemctl status opencode
systemctl start opencode
systemctl stop opencode
journalctl -u opencode -f

# Access web UI
# Via container proxy: http://<host>:9201/ (for oc-01)
# Inside container: http://localhost:4096/
```

## File Structure

- `install.sh` - Installation entry point
- `opencode.nix` - NixOS module (package, user, service)

## NixOS-Specific Notes

- Uses nixos/unstable for latest opencode package
- `/bin/bash` symlink created via activation script for compatibility
- `sudo nixos-rebuild switch` required even when running as root
- Service runs as `opencode` user (not root)

## Service Configuration

- **Command**: `opencode web --port 4096 --hostname 0.0.0.0`
- **Port**: 4096 (HTTP)
- **User**: opencode
- **Working Directory**: /home/opencode
- **Data Directory**: /home/opencode/.local/share/opencode/

## Security Considerations

- No authentication by default (unsecured)
- Suitable for local network use behind container proxy
- To enable auth, add `OPENCODE_SERVER_PASSWORD` to service Environment

## Container Deployment

Container creation is handled by the `container-management` module:

```bash
# From container-management directory:
./launch.sh configs/opencode.conf oc-01              # Create and install
./launch.sh configs/opencode.conf oc-01 --no-install  # Create only (for manual install)
```

See `README.md` for details.

## Reference Documentation

- OpenCode Docs: https://opencode.ai/docs/
- OpenCode Web: https://opencode.ai/docs/web/
- NixOS Manual: https://nixos.org/manual/nixos/stable/
- NixOS Packages: https://search.nixos.org/packages?channel=unstable&show=opencode
