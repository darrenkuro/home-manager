# lib/launchd-btm.nix — Pure helper functions for BTM-friendly launchd agents.
#
# ── Why this exists ──
# home-manager's built-in `launchd.agents` wraps every ProgramArguments in
#   /bin/sh -c "wait4path /nix/store && exec ..."
# This causes macOS Background Task Management (System Settings → General →
# Login Items & Extensions) to show "sh" as the process name for every agent,
# with no icon and no way to identify what each one does.
#
# This library provides two builders that bypass HM's mutateConfig:
#
#   mkWrapper — Named shell binary (shows "PostgresServer" in BTM, not "sh")
#               Bakes in /bin/wait4path so HM's wrapper is unnecessary.
#
#   mkPlist  — Generates a launchd plist from a Nix attrset. Used instead of
#               HM's launchd.agents so we control ProgramArguments directly.
#
# App stubs (.app bundles for BTM icons) live in configs/app-stubs/ as static
# files — no Nix builder needed. The btm.nix activation script copies them to
# ~/.local/share/app-stubs/, embeds wrapper binaries, codesigns, and registers.
#
# Usage in service modules:
#   let btm = import ../../lib/launchd-btm.nix { inherit lib pkgs; };
{ lib, pkgs }:

let
  inherit (lib.generators) toPlist;
in
{
  mkWrapper =
    { name
    , text
    , runtimeInputs ? []
    , excludeShellChecks ? []
    }:
    pkgs.writeShellApplication {
      inherit name runtimeInputs excludeShellChecks;
      text = ''
        /bin/wait4path /nix/store &>/dev/null
        ${text}
      '';
    };

  mkPlist = config:
    pkgs.writeText "${config.Label}.plist" (toPlist { escape = true; } config);
}
