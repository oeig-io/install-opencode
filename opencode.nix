# opencode.nix
# NixOS module for OpenCode web interface
#
# This module sets up:
#   - OpenCode from nixpkgs (unstable recommended)
#   - opencode system user
#   - systemd service running 'opencode web'
#
# Architecture Note:
#   'opencode web' serves BOTH the web UI and API on the same port:
#     - Web UI: Browser interface at http://host:port/
#     - API/WebSocket: For 'opencode attach' and terminal sessions
#   Alternative: 'opencode serve' is API-only (no browser UI)
#
# Workflow:
#   1. Add this to configuration.nix: imports = [ ./opencode.nix ];
#   2. Run: sudo nixos-rebuild switch
#
# Security Note:
#   - No authentication is configured by default
#   - Server is unsecured (suitable for local network use)
#   - Set OPENCODE_SERVER_PASSWORD environment variable for basic auth

{ config, pkgs, lib, ... }:

let
  cfg = {
    user = "opencode";
    group = "opencode";
    port = 4096;
    homeDir = "/home/opencode";
  };

in {
  #############################################################################
  # Timezone Configuration - Default to America/Chicago
  # Can be overridden by container-management/launch.sh when needed
  #############################################################################
  time.timeZone = "America/Chicago";

  #############################################################################
  # Compatibility: Scripts may expect /bin/bash
  #############################################################################
  system.activationScripts.binbash = ''
    mkdir -p /bin
    ln -sf ${pkgs.bash}/bin/bash /bin/bash
  '';

  # enable netbird - must bring up manually
  services.netbird.enable = true;

  #############################################################################
  # IPv6 Configuration - Disable temporary addresses for stable addressing
  #############################################################################
  boot.kernel.sysctl = {
    "net.ipv6.conf.all.use_tempaddr" = 0;
    "net.ipv6.conf.default.use_tempaddr" = 0;
  };

  #############################################################################
  # System packages - Prerequisites
  #############################################################################
  environment.systemPackages = with pkgs; [
    opencode
    curl
    coreutils
  ];

  #############################################################################
  # OpenCode system user
  #############################################################################
  users.users.${cfg.user} = {
    isSystemUser = true;
    group = cfg.group;
    home = cfg.homeDir;
    createHome = true;
    shell = pkgs.bash;
    description = "OpenCode service user";
  };

  users.groups.${cfg.group} = {};

  #############################################################################
  # OpenCode working directory
  #############################################################################
  systemd.tmpfiles.rules = [
    "d ${cfg.homeDir}/.local 0755 ${cfg.user} ${cfg.group} -"
    "d ${cfg.homeDir}/.local/share 0755 ${cfg.user} ${cfg.group} -"
    "d ${cfg.homeDir}/.local/share/opencode 0755 ${cfg.user} ${cfg.group} -"
  ];

  #############################################################################
  # OpenCode systemd service
  # Runs 'opencode web' as the opencode user
  # Serves BOTH web UI and API/WebSocket on the same port
  # Listens on 0.0.0.0:4096 for container proxy access
  #############################################################################
  systemd.services.opencode = {
    description = "OpenCode Web Interface and API";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    
    serviceConfig = {
      Type = "simple";
      User = cfg.user;
      Group = cfg.group;
      WorkingDirectory = cfg.homeDir;
      
      # 'opencode web' provides both UI and API on the same port
      # Use 'opencode serve' instead for API-only mode
      ExecStart = "${pkgs.opencode}/bin/opencode web --port ${toString cfg.port} --hostname 0.0.0.0";
      
      Restart = "always";
      RestartSec = 5;
      
      # Environment for opencode data
      Environment = [
        "HOME=${cfg.homeDir}"
        "XDG_DATA_HOME=${cfg.homeDir}/.local/share"
        # Uncomment to enable basic auth:
        # "OPENCODE_SERVER_PASSWORD=your-password-here"
        # 
        # Uncomment if opencode needs access to user-installed binaries:
        # "PATH=/run/current-system/sw/bin:/run/wrappers/bin:/home/opencode/.local/bin"
      ];
      
      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = "read-only";
      ReadWritePaths = [ 
        cfg.homeDir
        "/tmp"
      ];
    };
  };

  #############################################################################
  # Firewall - port 4096 is exposed via proxy, not directly
  #############################################################################
  # networking.firewall.allowedTCPPorts = [ 4096 ];
}
