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

  # ═══════════════════════════════════════════════════════════════════════════
  # TEST: LaunchAgents via nix-darwin (parallel to BTM for verification)
  # Uses .test suffix to avoid label conflicts with BTM-managed agents.
  # Points to same wrapper binaries inside BTM-managed .app stubs.
  #
  # AFTER CONFIRMING THESE WORK:
  # 1. Remove btm.stubs entries from: postgresql/service.nix, polymarket/service.nix
  # 2. Remove btm.agents from those files (keep stubs for BTM icon grouping)
  # 3. Rename labels here (remove .test suffix)
  # 4. Delete these TEST comments
  # ═══════════════════════════════════════════════════════════════════════════

  launchd.user.agents.postgresql-server-test = {
    serviceConfig = {
      Label = "org.postgresql.server.test";
      ProgramArguments = [ "${btmStubDir}/Postgres.app/Contents/MacOS/PostgresServer" ];
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      StandardOutPath = "/Users/darrenlu/.local/state/postgresql/launchd-stdout.log";
      StandardErrorPath = "/Users/darrenlu/.local/state/postgresql/launchd-stderr.log";
      EnvironmentVariables = {
        HOME = "/Users/darrenlu";
        PGDATA = "/Users/darrenlu/.local/share/postgresql/data";
      };
    };
  };

  launchd.user.agents.postgresql-backup-test = {
    serviceConfig = {
      Label = "org.postgresql.backup.test";
      ProgramArguments = [ "${btmStubDir}/Postgres.app/Contents/MacOS/PostgresBackup" ];
      StartCalendarInterval = [{ Hour = 3; Minute = 0; }];
      StandardOutPath = "/Users/darrenlu/.local/state/postgresql/backup-stdout.log";
      StandardErrorPath = "/Users/darrenlu/.local/state/postgresql/backup-stderr.log";
      EnvironmentVariables = {
        HOME = "/Users/darrenlu";
      };
    };
  };

  launchd.user.agents.polymarket-monitor-test = {
    serviceConfig = {
      Label = "com.polymarket.data-monitor.test";
      ProgramArguments = [ "${btmStubDir}/Polymarket.app/Contents/MacOS/PolymarketMonitor" ];
      WorkingDirectory = "/Users/darrenlu/Documents/dev/polymarket-trading-bot";
      RunAtLoad = true;
      KeepAlive = true;
      ThrottleInterval = 10;
      StandardOutPath = "/tmp/polymarket/monitor.log";
      StandardErrorPath = "/tmp/polymarket/monitor.err";
      EnvironmentVariables = {
        HOME = "/Users/darrenlu";
      };
    };
  };

  # nix-darwin state version
  system.stateVersion = 5;
}
