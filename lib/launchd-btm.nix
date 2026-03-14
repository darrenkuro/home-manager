# lib/launchd-btm.nix — Helpers for BTM-friendly launchd agents.
#
# mkWrapper — Named shell binary (shows "PostgresServer" in BTM, not "sh")
# mkPlist — Generates launchd plist from Nix attrset
# useSystemBash — For pre-mount scripts (darwin-store) that run before /nix exists
{
  lib,
  pkgs,
}: let
  inherit (lib.generators) toPlist;
in {
  mkWrapper = {
    name,
    text,
    runtimeInputs ? [],
    excludeShellChecks ? [],
    useSystemBash ? false,
  }:
    if useSystemBash
    then
      # Pre-mount: /bin/bash, no wait4path
      pkgs.writeTextFile {
        inherit name;
        destination = "/bin/${name}";
        executable = true;
        text = ''
          #!/bin/bash
          set -euo pipefail
          ${text}
        '';
      }
    else
      pkgs.writeShellApplication {
        inherit name runtimeInputs excludeShellChecks;
        text = ''
          /bin/wait4path /nix/store &>/dev/null
          ${text}
        '';
      };

  mkPlist = config:
    pkgs.writeText "${config.Label}.plist" (toPlist {escape = true;} config);
}
