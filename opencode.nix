# opencode.nix
# NixOS module for OpenCode web interface
#
# This module sets up:
#   - OpenCode from nixpkgs (unstable recommended)
#   - opencode system user
#   - systemd service running 'opencode web'
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
  opencode = {
    user = "opencode";
    group = "opencode";
    port = 4096;
    homeDir = "/home/opencode";
  };

in {
  #############################################################################
  # Compatibility: Scripts may expect /bin/bash
  #############################################################################
  system.activationScripts.binbash = ''
    mkdir -p /bin
    ln -sf ${pkgs.bash}/bin/bash /bin/bash
  '';

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
  users.users.${opencode.user} = {
    isSystemUser = true;
    group = opencode.group;
    home = opencode.homeDir;
    createHome = true;
    shell = pkgs.bash;
    description = "OpenCode service user";
  };

  users.groups.${opencode.group} = {};

  #############################################################################
  # OpenCode working directory
  #############################################################################
  systemd.tmpfiles.rules = [
    "d ${opencode.homeDir}/.local/share/opencode 0755 ${opencode.user} ${opencode.group} -"
  ];

  #############################################################################
  # OpenCode systemd service
  # Runs 'opencode web' as the opencode user
  # Listens on 0.0.0.0:4096 for container proxy access
  #############################################################################
  systemd.services.opencode = {
    description = "OpenCode Web Interface";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    
    serviceConfig = {
      Type = "simple";
      User = opencode.user;
      Group = opencode.group;
      WorkingDirectory = opencode.homeDir;
      
      ExecStart = "${pkgs.opencode}/bin/opencode web --port ${toString opencode.port} --hostname 0.0.0.0";
      
      Restart = "always";
      RestartSec = 5;
      
      # Environment for opencode data
      Environment = [
        "HOME=${opencode.homeDir}"
        "XDG_DATA_HOME=${opencode.homeDir}/.local/share"
      ];
      
      # Security hardening
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ opencode.homeDir ];
    };
  };

  #############################################################################
  # Firewall - port 4096 is exposed via proxy, not directly
  #############################################################################
  # networking.firewall.allowedTCPPorts = [ 4096 ];
}
