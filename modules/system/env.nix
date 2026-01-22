{tag, ...}: {
  home.sessionVariables = {
    HM_TAG =
      if tag == "mac"
      then "MAC"
      else if tag == "ft"
      then "FT"
      else "UNKNOWN";

    # Directories
    DBOX = "$HOME/Dropbox";
    DEV = "$HOME/Documents/dev";
    HM = "$HOME/.config/home-manager";

    # Colors
    RED = "\\u001b[31m";
    GREEN = "\\u001b[32m";
    YELLOW = "\\u001b[33m";
    BLUE = "\\u001b[34m";
    MAGENTA = "\\u001b[35m";
    CYAN = "\\u001b[36m";
    WHITE = "\\u001b[37m";
    RESET = "\\u001b[0m";

    # Home Directory Hygenie
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";

    HISTFILE = "$HOME/.local/state/bash/history";
    LESSHISTFILE = "$HOME/.local/state/less/history";
    ZSH_SESSION_DIR = "$HOME/.local/state/zsh/sessions";
    WAKATIME_HOME = "$HOME/.local/state/wakatime";
    CLAUDE_CONFIG_DIR = "$HOME/.config/claude";
  };
}
