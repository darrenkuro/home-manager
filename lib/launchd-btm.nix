# lib/launchd-btm.nix — mkWrapper for BTM-friendly named binaries.
# useSystemBash — For pre-mount scripts (darwin-store) that run before /nix exists.
{
  lib,
  pkgs,
}: {
  mkWrapper = {
    name,
    text,
    runtimeInputs ? [],
    excludeShellChecks ? [],
    useSystemBash ? false,
  }:
    if useSystemBash
    then
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
}
