{ tag, profile, lib, ... }: {
    home.sessionVariables = ( import ../../lib/xdg-paths.nix { home = "$HOME"; } ) //
    {
        # ── System ── (uppercase to match the INSTALL_TAG/INSTALL_PROFILE
        # gates in functions/_preamble.sh)
        HM_TAG = lib.toUpper tag;
        HM_PROFILE = lib.toUpper profile;

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
        SHELL_SESSIONS_DISABLE = "1"; # Apple's real knob: /etc/zshrc_Apple_Terminal hardcodes ${ZDOTDIR:-$HOME}/.zsh_sessions (no relocation var exists); must be exported before /etc/zshrc runs
        PYTHON_HISTORY = "$HOME/.local/state/python/history"; # requires Python 3.13+
        NODE_REPL_HISTORY = "$HOME/.local/state/node/history";
        PSQL_HISTORY = "$HOME/.local/state/psql/history";

        # ── Tools ──
        HOMEBREW_NO_ENV_HINTS = "1";

        # ── Google ── (Application Default Credentials for google-auth / gcloud libs)
        GOOGLE_APPLICATION_CREDENTIALS = "$HOME/.config/google/gsheets-sa.json";
    } //
    lib.optionalAttrs ( tag == "mac" && profile == "personal" ) {
        # ── Printing ── CLI default printer; checked before ~/.cups/lpoptions,
        # which macOS's CUPS hardcodes to $HOME — so this keeps ~/.cups away.
        # Home printer only: an LPDEST pointing at a missing printer breaks `lp`.
        LPDEST = "Canon_MG3600_series";
    };

    home.sessionPath = [ "$HOME/.local/bin" "$HOME/Library/pnpm" ] ++
    lib.optionals ( tag == "mac" ) [ "/opt/homebrew/bin" ];
}
