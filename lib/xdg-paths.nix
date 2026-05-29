# Single source of truth for XDG-style env vars.
#
# Two consumers need the same set of paths but interpret strings differently:
#   - `home.sessionVariables` (shell-sourced) expects "$HOME/..." literals.
#   - `launchd.user.envVariables` (plist-loaded) expects absolute paths.
#
# Both call this with the appropriate `home` value:
#   import ./xdg-paths.nix { home = "$HOME"; }            # shell
#   import ./xdg-paths.nix { home = "/Users/darrenlu"; }  # launchd
{ home }: {
    # ── XDG Base Directories ──
    XDG_CONFIG_HOME = "${home}/.config";
    XDG_CACHE_HOME = "${home}/.cache";
    XDG_DATA_HOME = "${home}/.local/share";
    XDG_STATE_HOME = "${home}/.local/state";

    # ── XDG Overrides (keep $HOME clean) ──
    WAKATIME_HOME = "${home}/.local/state/wakatime";
    CLAUDE_CONFIG_DIR = "${home}/.config/claude";
    NPM_CONFIG_USERCONFIG = "${home}/.config/npm/npmrc";
    NPM_CONFIG_CACHE = "${home}/.cache/npm";
    CARGO_HOME = "${home}/.local/share/cargo";
    DOCKER_CONFIG = "${home}/.config/docker";
    ANDROID_USER_HOME = "${home}/.local/share/android";
    BUNDLE_USER_HOME = "${home}/.local/share/bundle";
    GEM_HOME = "${home}/.local/share/gem";
    RBENV_ROOT = "${home}/.local/share/rbenv";
    DOTNET_CLI_HOME = "${home}/.local/share";
    NUGET_PACKAGES = "${home}/.local/share/NuGet/packages";
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    MPLCONFIGDIR = "${home}/.config/matplotlib";

    # ── Tools ──
    PNPM_HOME = "${home}/Library/pnpm";
}
