# nix-darwin system-level macOS config.
{ lib, ... }:

let
  # BTM stub location (managed by home-manager btm module)
  btmStubDir = "/Users/darrenlu/.local/share/app-stubs";
in
{
  # Nix settings
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # macOS system defaults (declarative)
  system.defaults = {
    dock.show-recents = false;
  };

  # NSRecentDocumentsLimit not available in nix-darwin — use activation script
  system.activationScripts.postActivation.text = ''
    /usr/bin/defaults write -g NSRecentDocumentsLimit 0
  '';

  # User (needed for home-manager integration to infer home.homeDirectory)
  users.users.darrenlu = {
    name = "darrenlu";
    home = "/Users/darrenlu";
  };

  # Required for user-level options (launchd.user.agents, system.defaults.dock, etc.)
  system.primaryUser = "darrenlu";

  # GUI env vars — replaces env-setter service after reboot verification
  # These are the vars from home.sessionVariables minus shell-only ones (denyList)
  launchd.user.envVariables = {
    # XDG Base Directories
    XDG_CONFIG_HOME = "/Users/darrenlu/.config";
    XDG_CACHE_HOME = "/Users/darrenlu/.cache";
    XDG_DATA_HOME = "/Users/darrenlu/.local/share";
    XDG_STATE_HOME = "/Users/darrenlu/.local/state";
    # XDG Overrides (keep $HOME clean)
    WAKATIME_HOME = "/Users/darrenlu/.local/state/wakatime";
    CLAUDE_CONFIG_DIR = "/Users/darrenlu/.config/claude";
    NPM_CONFIG_USERCONFIG = "/Users/darrenlu/.config/npm/npmrc";
    NPM_CONFIG_CACHE = "/Users/darrenlu/.cache/npm";
    CARGO_HOME = "/Users/darrenlu/.local/share/cargo";
    DOCKER_CONFIG = "/Users/darrenlu/.config/docker";
    ANDROID_USER_HOME = "/Users/darrenlu/.local/share/android";
    BUNDLE_USER_HOME = "/Users/darrenlu/.local/share/bundle";
    GEM_HOME = "/Users/darrenlu/.local/share/gem";
    RBENV_ROOT = "/Users/darrenlu/.local/share/rbenv";
    DOTNET_CLI_HOME = "/Users/darrenlu/.local/share";
    NUGET_PACKAGES = "/Users/darrenlu/.local/share/NuGet/packages";
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    MPLCONFIGDIR = "/Users/darrenlu/.config/matplotlib";
    # Tools
    PNPM_HOME = "/Users/darrenlu/Library/pnpm";
  };

  # Take over Nix daemon management from installer for BTM integration
  # This replaces /Library/LaunchDaemons/org.nixos.nix-daemon.plist
  launchd.daemons.nix-daemon = {
    serviceConfig = {
      Label = "org.nixos.nix-daemon";
      ProgramArguments = lib.mkForce [
        "${btmStubDir}/Nix.app/Contents/MacOS/NixDaemonStart"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      LowPriorityIO = false;
      ProcessType = "Standard";
      SoftResourceLimits.NumberOfFiles = 1048576;
      EnvironmentVariables = {
        NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
        OBJC_DISABLE_INITIALIZE_FORK_SAFETY = "YES";
      };
    };
  };

  # This replaces /Library/LaunchDaemons/org.nixos.darwin-store.plist
  launchd.daemons.darwin-store = {
    serviceConfig = {
      Label = "org.nixos.darwin-store";
      ProgramArguments = [
        "${btmStubDir}/Nix.app/Contents/MacOS/NixStoreMount"
      ];
      RunAtLoad = true;
    };
  };

  # nix-darwin state version
  system.stateVersion = 5;
}
