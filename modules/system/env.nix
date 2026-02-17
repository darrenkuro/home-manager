{tag, ...}: {
  home.sessionVariables = {
    # ── System ──
    HM_TAG =
      if tag == "mac"
      then "MAC"
      else if tag == "ft"
      then "FT"
      else "UNKNOWN";

    # ── Shortcuts ──
    DBOX = "$HOME/Dropbox";
    DEV = "$HOME/Documents/dev";
    HM = "$HOME/.config/home-manager";

    # ── Terminal Colors ──
    RED = "\\u001b[31m";
    GREEN = "\\u001b[32m";
    YELLOW = "\\u001b[33m";
    BLUE = "\\u001b[34m";
    MAGENTA = "\\u001b[35m";
    CYAN = "\\u001b[36m";
    WHITE = "\\u001b[37m";
    RESET = "\\u001b[0m";

    # ── XDG Base Directories ──
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";

    # ── XDG Overrides (keep $HOME clean) ──
    HISTFILE = "$HOME/.local/state/bash/history";
    LESSHISTFILE = "$HOME/.local/state/less/history";
    ZSH_SESSION_DIR = "$HOME/.local/state/zsh/sessions";
    WAKATIME_HOME = "$HOME/.local/state/wakatime";
    CLAUDE_CONFIG_DIR = "$HOME/.config/claude";
    NPM_CONFIG_USERCONFIG = "$HOME/.config/npm/npmrc";
    NPM_CONFIG_CACHE = "$HOME/.cache/npm";
    CARGO_HOME = "$HOME/.local/share/cargo";
    DOCKER_CONFIG = "$HOME/.config/docker";
    ANDROID_USER_HOME = "$HOME/.local/share/android";
    BUNDLE_USER_HOME = "$HOME/.local/share/bundle";
    GEM_HOME = "$HOME/.local/share/gem";
    RBENV_ROOT = "$HOME/.local/share/rbenv";

    # ── Tools ──
    PNPM_HOME = "$HOME/Library/pnpm";
    HOMEBREW_NO_ENV_HINTS = "1";
  };

  home.sessionPath = [
    "$HOME/Library/pnpm"
  ];
}
