{ ... }:
{
  home.sessionVariables = {
    DBOX = "$HOME/Dropbox";
    DEV = "$HOME/Documents/dev";
    HM = "$HOME/.config/home-manager";

    # setaf => foreground; setab => background
    BLACK = "$(tput setaf 0)";
    RED = "$(tput setaf 1)";
    GREEN = "$(tput setaf 2)";
    YELLOW = "$(tput setaf 3)";
    BLUE = "$(tput setaf 4)";
    MAGENTA = "$(tput setaf 5)";
    CYAN = "$(tput setaf 6)";
    WHITE = "$(tput setaf 7)";

    # tput sgr0 sets all the settings back to terminal default
    RESET = "$(tput sgr0)";

    # Home Directory Hygenie
    XDG_CONFIG_HOME = "$HOME/.config";
    XDG_CACHE_HOME = "$HOME/.cache";
    XDG_DATA_HOME = "$HOME/.local/share";
    XDG_STATE_HOME = "$HOME/.local/state";
  };
}
