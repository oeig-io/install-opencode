# opencode-idempiere-deploy-observations.md

**Date**: 2026-03-05  
**Container**: id-04  
**Goal**: Make opencode web UI accessible via nginx at `/ai/` path

---

## Problem Summary

Attempting to deploy opencode web UI behind nginx reverse proxy at `https://<host>/ai/`. The web UI loads but cannot execute shell commands, showing errors like:
- `ENOENT: no such file or directory, posix_spawn '/run/current-system/sw/bin/bash'`

---

## What Was Learned

### 1. Nginx Configuration Requirements

**Path-based routing requires multiple location blocks:**
- `/ai/` - Main web UI with `sub_filter` to rewrite HTML paths
- `/assets/` - Static assets (JS, CSS)
- `/favicon*`, `/apple-touch-icon*`, `/site.webmanifest` - Favicon and manifest files
- `/global`, `/session`, `/event`, `/pty`, `/config`, `/agent`, `/skill`, `/lsp`, `/command`, `/vcs`, `/instance`, `/path`, `/mcp`, `/provider`, `/question`, `/permission`, `/experimental`, `/tui`, `/log` - All API endpoints

**Key nginx directives needed:**
```nix
# Rewrite absolute paths in HTML to use /ai/ prefix
sub_filter_once off;
sub_filter_types text/html text/css application/javascript;
sub_filter 'href="/' 'href="/ai/';
sub_filter 'src="/' 'src="/ai/';
sub_filter 'url(/' 'url(/ai/';

# WebSocket support
proxy_http_version 1.1;
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";

# Important: Don't duplicate proxy_http_version when proxyWebsockets = true
```

### 2. Opencode Web UI Architecture

**Static asset paths:**
- Opencode uses absolute paths (`/assets/`, `/favicon`, etc.) in HTML
- When served from `/ai/`, these break unless proxied separately or rewritten

**API endpoints used by web UI:**
- `/global` - Health checks and global settings
- `/session` - Session management
- `/session/:id/shell` - Shell command execution (when user types `!` in prompt)
- `/event` - Server-Sent Events for real-time updates
- `/pty/:id/connect` - WebSocket for terminal sessions
- Many more... (see grep results in idempiere-nginx.nix)

**WebSocket endpoints:**
- PTY terminal uses WebSocket at `/pty/:ptyID/connect`
- Requires `proxyWebsockets = true` in nginx

### 3. NixOS/Bun Spawn Issue (CRITICAL)

**Root Cause:**
Bun's `posix_spawn` implementation cannot follow NixOS symlink chains properly:
```
SHELL=/run/current-system/sw/bin/bash  # Symlink to nix store
        ↓
/nix/store/...-bash-interactive-5.3p9/bin/bash  # Actual binary
```

**Error:**
```
ENOENT: no such file or directory, posix_spawn '/run/current-system/sw/bin/bash'
```

Even setting `SHELL` to the direct store path fails:
```
ENOENT: no such file or directory, posix_spawn '/nix/store/...-bash-interactive-5.3p9/bin/bash'
```

**Attempted Solutions:**

#### Attempt 1: Set SHELL env var explicitly
**Status:** FAILED
```bash
SHELL=/nix/store/0550j0i8bmzxbcnzrg1g51zigj7y12ih-bash-interactive-5.3p9/bin/bash \
  opencode web --port 4096 --hostname 127.0.0.1
```
Still results in ENOENT errors.

#### Attempt 2: Wrapper script
**Status:** UNKNOWN/PARTIAL
```bash
# /tmp/bash-wrapper.sh
#!/nix/store/.../bin/bash
exec /nix/store/...-bash-interactive-5.3p9/bin/bash "$@"
```

Set `SHELL=/tmp/bash-wrapper.sh` - no ENOENT errors in logs after restart, but shell commands still hang in UI.

### 4. Opencode Server Code Analysis

**Shell command execution flow:**
```typescript
// src/session/prompt.ts:1565
const shell = Shell.preferred()  // Reads from SHELL env var

// src/shell/shell.ts:57-61
export const preferred = lazy(() => {
  const s = process.env.SHELL
  if (s) return s
  return fallback()  // Tries /bin/sh, /bin/bash, etc.
})
```

**Spawn happens via Node.js child_process:**
```typescript
// src/session/prompt.ts:1626
const proc = spawn(shell, args, {
  cwd,
  detached: process.platform !== 'win32',
  stdio: ['ignore', 'pipe', 'pipe'],
  env: { ...process.env, ...shellEnv.env, TERM: 'dumb' }
})
```

This uses Node.js `child_process.spawn()`, which calls `posix_spawn` on Linux.

### 5. Similar Issues in Vilara Project

From `~/code/vilara/project/nixos/opencode.nix`:
- Sets explicit PATH: `PATH = lib.mkForce "/run/current-system/sw/bin:/run/wrappers/bin"`
- Uses `opencode serve` (not `opencode web`)
- Runs as systemd service with proper environment setup
- Does NOT set SHELL explicitly

---

## Current State

**Working:**
- ✅ Web UI loads at `https://vilara-incus-phoenix-chuck.netbird.cloud:9004/ai/`
- ✅ All static assets load correctly
- ✅ API endpoints are accessible
- ✅ Session creation works
- ✅ Health checks respond

**Not Working:**
- ❌ Shell command execution hangs indefinitely
- ❌ Terminal/PTY WebSocket connection uncertain

**Last Error:**
```
ENOENT: no such file or directory, posix_spawn '/nix/store/.../bin/bash'
```

**Current Process:**
- PID: varies (last was 17461)
- SHELL: `/tmp/bash-wrapper.sh`
- Port: 4096
- Log: `/home/idempiere/.local/share/opencode/log/`

---

## Potential Solutions to Investigate

### Option 1: Use `opencode serve` instead of `opencode web`

`opencode serve` is the production HTTP server mode, while `opencode web` is the development server with auto-open browser.

**Command:**
```bash
opencode serve --port 4096 --hostname 127.0.0.1
```

**Pros:**
- Production-ready
- Used in Vilara project successfully
- No browser auto-open behavior

**Cons:**
- May have same spawn issues
- Different API (if any) from `web`

### Option 2: Use Statically Linked Shell

NixOS provides statically linked busybox or other shells that don't have dynamic library dependencies.

**Investigate:**
- `${pkgs.busybox}/bin/sh` (static)
- `${pkgs.bashInteractive}/bin/bash` vs `${pkgs.bash}/bin/bash`

### Option 3: Create FHS Environment

Use NixOS `buildFHSUserEnv` or `steam-run` to create a traditional Linux environment where dynamic linking works normally.

**Investigate:**
- `pkgs.buildFHSUserEnv`
- `pkgs.steam-run`

### Option 4: Use systemd Service

Instead of running `opencode web` manually, create a proper systemd service like in the Vilara project. This ensures:
- Correct environment variables
- Proper PATH setup
- Clean process management

### Option 5: Patch Opencode or Bun

This is a known issue with Bun on NixOS. Potential fixes:
- Upgrade Bun version
- Patch Bun's spawn implementation
- Use Node.js runtime instead of Bun

---

## Next Steps

1. **Try `opencode serve` instead of `opencode web`**
   - Test if shell commands work in production mode
   - Check if the API is identical

2. **Investigate statically linked shells**
   - Try busybox sh
   - Compare bash vs bashInteractive

3. **Review Vilara project setup**
   - How do they handle this in production?
   - What environment variables are set?

4. **Create systemd service**
   - Move from manual process to managed service
   - Use same pattern as `opencode.nix` in Vilara

5. **Test PTY functionality**
   - Even if shell commands work, verify terminal works
   - May need additional WebSocket configuration

---

## Files Modified

- `/home/debian/code/oeig/install-idempiere/idempiere-nginx.nix` - Added opencode reverse proxy configuration with all API endpoints

---

## Log Locations

- **Opencode logs**: `/home/idempiere/.local/share/opencode/log/`
- **Server stdout**: `/tmp/opencode-server.log`
- **Nginx logs**: Journal via `journalctl -u nginx`

---

## Commands for Testing

```bash
# Check opencode process
incus exec id-04 -- ps aux | grep opencode

# Check SHELL env
incus exec id-04 -- cat /proc/<PID>/environ | tr '\0' '\n' | grep SHELL

# Test API endpoints
curl -k https://vilara-incus-phoenix-chuck.netbird.cloud:9004/global
curl -k https://vilara-incus-phoenix-chuck.netbird.cloud:9004/session

# Check logs
incus exec id-04 -- su - idempiere -c "cat .local/share/opencode/log/*.log | grep ENOENT"

# Restart opencode
incus exec id-04 -- pkill -f "opencode"
sleep 2
incus exec id-04 -- su - idempiere -c "SHELL=/tmp/bash-wrapper.sh opencode web --port 4096 --hostname 127.0.0.1"
```

---

## References

- Vilara opencode config: `~/code/vilara/project/nixos/opencode.nix`
- Vilara opencode-idempiere config: `~/code/vilara/project/nixos/opencode-idempiere.nix`
- Opencode source: `~/code/opencode/packages/opencode/src/`
- NixOS manual: https://nixos.org/manual/nixos/stable/
