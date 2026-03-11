# Env-Setter Agent — BTM-friendly launchd agent for system-wide env vars.
#
# GUI apps launched via Spotlight/Alfred don't inherit shell env vars.
# This one-shot agent runs `launchctl setenv` at login to propagate
# selected env vars to the launchd domain (visible to all processes).
#
# Shows as "Claude — 1 item" in Login Items (reuses Claude.app stub).
{ config, lib, pkgs, ... }:

let
  btm = import ../../lib/launchd-btm.nix { inherit lib pkgs; };
  homeDir = config.home.homeDirectory;
  label = "com.user.env-setter";

  # Env vars to propagate to the launchd domain.
  # These must use absolute paths (no $HOME — launchctl setenv is literal).
  envVars = {
    CLAUDE_CONFIG_DIR = "${homeDir}/.config/claude";
  };

  setenvCommands = lib.concatStringsSep "\n" (lib.mapAttrsToList
    (name: value: ''/bin/launchctl setenv ${name} "${value}"'')
    envVars);

  wrapper = btm.mkWrapper {
    name = "EnvSetter";
    text = setenvCommands;
  };

  plist = btm.mkPlist {
    Label = label;
    BundleProgram = "Contents/MacOS/EnvSetter";
    RunAtLoad = true;
  };
in
{
  btm.stubs."Claude" = {
    src = ../../app-stubs/Claude.app;
    wrappers = [{ drv = wrapper; bin = "EnvSetter"; }];
    agents = { "${label}" = plist; };
  };
}
