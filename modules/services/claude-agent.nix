# Claude Config Agent — BTM-friendly launchd agent for macOS
#
# Sets CLAUDE_CONFIG_DIR at login so all processes (including GUI apps) see it.
# One-shot: runs at load, no KeepAlive.
#
# Creates:
#   - ClaudeConfig wrapper → named binary for BTM/ps display
#   - Claude.app stub      → BTM icon (uses Claude.icns)
#   - Launchd plist via btm.agents (bypassing HM's mutateConfig)
{ config, lib, pkgs, ... }:

let
  btm = import ../../lib/launchd-btm.nix { inherit lib pkgs; };

  # ── Named Wrapper ──
  wrapper = btm.mkWrapper {
    name = "ClaudeConfig";
    text = ''
      exec /bin/launchctl setenv CLAUDE_CONFIG_DIR "${config.home.homeDirectory}/.config/claude"
    '';
  };

  # ── App Stub ──
  stub = btm.mkAppStub {
    name = "Claude";
    bundleId = "com.local.claude.stub";
    icon = ../../configs/icons/Claude.icns;
  };

  # ── Launchd Plist ──
  plist = btm.mkPlist {
    Label = "com.user.set-claude-config-dir";
    ProgramArguments = [ "${wrapper}/bin/ClaudeConfig" ];
    RunAtLoad = true;
    AssociatedBundleIdentifiers = [ "com.local.claude.stub" ];
  };

in
{
  btm.agents."com.user.set-claude-config-dir" = plist;
  btm.stubs."Claude" = stub;
}
