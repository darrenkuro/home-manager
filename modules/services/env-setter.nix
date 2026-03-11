# Env-Setter Agent — invisible launchd agent for system-wide env vars.
#
# GUI apps launched via Spotlight/Alfred don't inherit shell env vars.
# This one-shot agent runs `launchctl setenv` at login to propagate
# selected env vars to the launchd domain (visible to all processes).
#
# NOT registered with btm.stubs — invisible in System Settings Login Items.
{ config, lib, pkgs, ... }:

let
  btm = import ../../lib/launchd-btm.nix { inherit lib pkgs; };
  homeDir = config.home.homeDirectory;
  agentDir = "${homeDir}/Library/LaunchAgents";
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
    ProgramArguments = [ "${wrapper}/bin/EnvSetter" ];
    RunAtLoad = true;
  };
in
{
  home.activation.envSetterAgent = lib.hm.dag.entryAfter [
    "writeBoundary"
  ] ''
    set +e

    _dst="${agentDir}/${label}.plist"
    _hash_file="${homeDir}/.local/share/app-stubs/.plist-src-${label}"
    _need_install=0

    if ! /bin/launchctl print "gui/$UID/${label}" &>/dev/null; then
      _need_install=1
    elif ! /usr/bin/cmp -s "${plist}" "$_hash_file" 2>/dev/null; then
      _need_install=1
      /bin/launchctl bootout "gui/$UID/${label}" 2>/dev/null
      sleep 1
    fi

    if [ "$_need_install" -eq 1 ]; then
      echo "  installing env-setter agent: ${label}"
      /usr/bin/install -Dm444 "${plist}" "$_dst"
      /bin/launchctl bootstrap "gui/$UID" "$_dst" 2>&1 || \
        echo "  error: bootstrap ${label} failed" >&2
      /bin/cp "${plist}" "$_hash_file"
    fi

    set -e
  '';
}
