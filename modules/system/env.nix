{ tag, lib, ... }: {
    home.sessionVariables = ( import ../../lib/xdg-paths.nix { home = "$HOME"; } ) // {
        # ── System ──
        HM_TAG = if tag == "mac"
        then
            "MAC"
        else if tag == "ft"
        then
            "FT"
        else
            "UNKNOWN";

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

        # ── Shell-only history paths (not needed by GUI apps) ──
        HISTFILE = "$HOME/.local/state/bash/history";
        LESSHISTFILE = "$HOME/.local/state/less/history";
        ZSH_SESSION_DIR = "$HOME/.local/state/zsh/sessions";
        PYTHON_HISTORY = "$HOME/.local/state/python/history"; # requires Python 3.13+
        NODE_REPL_HISTORY = "$HOME/.local/state/node/history";

        # ── Tools ──
        HOMEBREW_NO_ENV_HINTS = "1";
    };

    home.sessionPath = [ "$HOME/.local/bin" "$HOME/Library/pnpm" ] ++
    lib.optionals ( tag == "mac" ) [ "/opt/homebrew/bin" ];
}
