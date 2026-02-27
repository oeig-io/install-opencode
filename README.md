# OpenCode Container

Deployment automation for OpenCode AI coding assistant on NixOS containers.

## Overview

This repository automates OpenCode installation using a single-phase approach:

1. **Phase 1 - NixOS Configuration** (`opencode.nix`): OpenCode package, opencode user, systemd service

> **🔗 Reference**: See [github.com/oeig-io/container-management](https://github.com/oeig-io/container-management) for deployment standards and orchestration instructions.

## Access

- **Web UI**: http://localhost:4096/
- **Default Port**: 4096

## Service Management

```bash
# Check status
systemctl status opencode

# Start/Stop/Restart
systemctl start opencode
systemctl stop opencode
systemctl restart opencode

# View logs
journalctl -u opencode -f
```

## Security

**Authentication is not configured by default.** The server runs unsecured, which is suitable for local network use behind the container proxy.

To enable basic authentication, set the `OPENCODE_SERVER_PASSWORD` environment variable in the systemd service configuration.

## Configuration

### Port

The service listens on port 4096 by default. This is configured in `opencode.nix` via the `ExecStart` command:

```bash
opencode web --port 4096 --hostname 0.0.0.0
```

### User

OpenCode runs as the `opencode` system user with home directory `/home/opencode`.

## File Structure

```
install-opencode/
├── install.sh              # Automated installation script
├── opencode.nix            # NixOS module (package, user, service)
├── README.md               # This file
└── CLAUDE.md               # Technical guidance for Claude Code
```

## Requirements

- NixOS (unstable recommended for latest opencode package)
- Sufficient resources for AI model inference (recommend 2GiB+ RAM)

## Installation

### Automated (via container-management)

```bash
# From container-management directory:
./launch.sh configs/opencode.conf oc-01
```

### Manual

```bash
cd /opt/opencode-install
./install.sh
```

## References

- [OpenCode Documentation](https://opencode.ai/docs/)
- [OpenCode Web Interface](https://opencode.ai/docs/web/)
- [github.com/oeig-io/container-management](https://github.com/oeig-io/container-management) - Deployment standards and orchestration
- [NixOS Packages - opencode](https://search.nixos.org/packages?channel=unstable&show=opencode)
