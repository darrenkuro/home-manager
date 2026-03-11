# Claude Config Agent — BTM-friendly launchd agent for macOS
#
# Sets CLAUDE_CONFIG_DIR at login so all processes (including GUI apps) see it.
# One-shot: runs at load, no KeepAlive.
{ config, lib, pkgs, ... }:

let
  btm = import ../../lib/launchd-btm.nix { inherit lib pkgs; };

  wrapper = btm.mkWrapper {
    name = "ClaudeConfig";
    text = ''
      exec /bin/launchctl setenv CLAUDE_CONFIG_DIR "${config.home.homeDirectory}/.config/claude"
    '';
  };

  plist = btm.mkPlist {
    Label = "com.user.set-claude-config-dir";
    BundleProgram = "Contents/MacOS/ClaudeConfig";
    RunAtLoad = true;
  };

in
{
  btm.stubs."Claude" = {
    src = ../../app-stubs/Claude.app;
    wrappers = [{ drv = wrapper; bin = "ClaudeConfig"; }];
    agents = { "com.user.set-claude-config-dir" = plist; };
  };
}
