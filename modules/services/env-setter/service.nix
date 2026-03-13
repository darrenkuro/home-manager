# Env-Setter — propagates env vars to the GUI domain via launchctl setenv.
#
# GUI apps (Spotlight, Dock, Finder) are spawned by per-user launchd, not by
# any shell. Shell dotfiles (.zshenv, .zshrc) never run, so custom env vars
# are invisible to desktop apps. This one-shot agent runs at login to bridge
# home.sessionVariables into the launchd domain.
#
# Vars defined in env.nix with $HOME are resolved to absolute paths at Nix
# eval time (launchctl setenv takes literal strings, no shell expansion).
{ config, lib, pkgs, ... }:

let
  btm = import ../../../lib/launchd-btm.nix { inherit lib pkgs; };
  homeDir = config.home.homeDirectory;
  label = "com.user.env-setter";

  # Shell-only vars that GUI apps don't need.
  denyList = [
    # Shell shortcuts (used in aliases/functions only)
    "HM" "DEV" "DBOX" "HM_TAG"
    # ANSI escape codes
    "RED" "GREEN" "YELLOW" "BLUE" "MAGENTA" "CYAN" "WHITE" "RESET"
    # Shell/REPL history
    "HISTFILE" "LESSHISTFILE" "ZSH_SESSION_DIR" "NODE_REPL_HISTORY" "PYTHON_HISTORY"
    # Shell-only behavior
    "HOMEBREW_NO_ENV_HINTS"
    # Terminal-only tools (uses $HM which won't resolve)
    "STARSHIP_CONFIG"
  ];

  # Pull from home.sessionVariables, filter, resolve $HOME
  allVars = config.home.sessionVariables;
  filteredVars = lib.filterAttrs (name: _: !(builtins.elem name denyList)) allVars;
  resolvedVars = lib.mapAttrs (_: value:
    builtins.replaceStrings ["$HOME"] [homeDir] (toString value)
  ) filteredVars;

  setenvCommands = lib.concatStringsSep "\n" (lib.mapAttrsToList
    (name: value: ''/bin/launchctl setenv ${name} "${value}"'')
    resolvedVars);

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
  btm.stubs."Env" = {
    src = ./Env.app;
    wrappers = [{ drv = wrapper; bin = "EnvSetter"; }];
    agents = { "${label}" = plist; };
  };
}
