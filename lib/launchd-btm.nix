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
# ── Key insight: useSystemBash ──
# By default, mkWrapper uses writeShellApplication which embeds Nix's bash
# (e.g., #!/nix/store/.../bash). This is fine for most agents.
#
# HOWEVER: The darwin-store mount script (NixStoreMount) runs BEFORE /nix is
# mounted — so Nix's bash doesn't exist yet! This is a chicken-and-egg problem.
# Set useSystemBash = true for any wrapper that must run before /nix is available.
#
# ── Nix Store unlock command ──
# The encrypted APFS volume requires both device identifier AND crypto user UUID:
#   security find-generic-password -s $UUID -w | \
#     diskutil apfs unlockVolume $DEVICE -stdinpassphrase -user $UUID
# The -user flag is required. The UUID is found via `diskutil apfs listCryptoUsers`.
#
# Usage in service modules:
#   let btm = import ../../lib/launchd-btm.nix { inherit lib pkgs; };
{
  lib,
  pkgs,
}: let
  inherit (lib.generators) toPlist;
in {
  # mkWrapper — creates a named shell script for launchd ProgramArguments.
  # By default uses Nix's bash via writeShellApplication.
  # Set useSystemBash = true for scripts that must run BEFORE /nix is mounted.
  mkWrapper = {
    name,
    text,
    runtimeInputs ? [],
    excludeShellChecks ? [],
    useSystemBash ? false,
  }:
    if useSystemBash
    then
      # For pre-mount scripts: use /bin/bash, no wait4path (store doesn't exist yet)
      pkgs.writeTextFile {
        inherit name;
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
