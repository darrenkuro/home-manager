# nix-darwin system-level macOS config.
{ lib, ... }:

let
  # BTM stub location (managed by home-manager btm module)
  btmStubDir = "/Users/darrenlu/.local/share/app-stubs";
  homeDir = "/Users/darrenlu";
  agentDir = "${homeDir}/Library/LaunchAgents";

  # Map agent labels to their parent app stubs for BTM grouping
  # Format: { "label" = "AppName"; } where stub is at ${btmStubDir}/AppName.app
  btmAgentMapping = {
    "org.postgresql.server" = "Postgres";
    "org.postgresql.backup" = "Postgres";
    "com.polymarket.data-monitor" = "Polymarket";
  };

  # Generate patching commands for all mapped agents
  patchCommands = lib.concatStringsSep "\n" (lib.mapAttrsToList (label: appName: ''
    _plist="${agentDir}/${label}.plist"
    _stub="${btmStubDir}/${appName}.app"
    if [[ -f "$_plist" ]] && [[ -d "$_stub" ]]; then
      _bid=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$_stub/Contents/Info.plist" 2>/dev/null)
      if [[ -n "$_bid" ]]; then
        # Check if already patched
        _existing=$(/usr/libexec/PlistBuddy -c "Print :AssociatedBundleIdentifiers:0" "$_plist" 2>/dev/null || true)
        if [[ "$_existing" != "$_bid" ]]; then
          /usr/libexec/PlistBuddy \
            -c "Delete :AssociatedBundleIdentifiers" "$_plist" 2>/dev/null || true
          /usr/libexec/PlistBuddy \
            -c "Add :AssociatedBundleIdentifiers array" \
            -c "Add :AssociatedBundleIdentifiers:0 string $_bid" \
            "$_plist" 2>/dev/null && echo "  BTM: patched ${label} -> ${appName}"
        fi
      fi
    fi
  '') btmAgentMapping);
in
{
  # Nix settings
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # ── Homebrew ──
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap";  # Remove unlisted packages
      autoUpdate = false;  # Don't auto-update on rebuild
      upgrade = true;
    };
    brews = [
      { name = "tmux"; args = ["HEAD"]; }  # HEAD fixes Claude Code rendering
    ];
    casks = [
      "alfred"
      "brave-browser"
      "calibre"
      { name = "claude"; greedy = true; }  # Fast-updating, always check
      "dropbox"
      "font-carlito"
      "notion"
      "obsidian"
      "pearcleaner"
      "sf-symbols"
      "steam"
      "visual-studio-code"
      "vlc"
    ];
    masApps = {
      "Affinity Designer" = 1274090551;
      "CleanMyMac" = 1339170533;
      "Developer" = 640199958;
      "Final Cut Pro" = 424389933;
      "iA Writer" = 775737590;
      "Mirror Magnet" = 1563698880;
      "OmniFocus 4" = 1542143627;
      "Scrivener 3" = 1310686187;
      "Xcode" = 497799835;
      "Yoink" = 457622435;
    };
  };

  # macOS system defaults (declarative)
  system.defaults = {
    # ── NSGlobalDomain ──
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      ApplePressAndHoldEnabled = false;  # Key repeat instead of accent popup
      InitialKeyRepeat = 15;  # Default 25
      KeyRepeat = 2;  # Default 6
      "com.apple.trackpad.scaling" = 3.0;
      NSAutomaticPeriodSubstitutionEnabled = false;
    };

    # ── Dock ──
    dock = {
      autohide = true;
      show-recents = false;
      tilesize = 61;
      show-process-indicators = true;
      wvous-br-corner = 1;  # Disabled hot corner
    };

    # ── Finder ──
    finder = {
      FXPreferredViewStyle = "clmv";  # Column view
      ShowPathbar = true;
      ShowStatusBar = false;
    };

    # ── Trackpad ──
    trackpad = {
      Clicking = true;  # Tap to click
      TrackpadThreeFingerDrag = false;
    };

    # ── Menu Bar Clock ──
    menuExtraClock = {
      ShowAMPM = true;
      ShowDayOfWeek = true;
      ShowSeconds = true;
      IsAnalog = false;
    };
  };

  # Post-activation: settings not in nix-darwin + BTM agent patching
  system.activationScripts.postActivation.text = ''
    # ── macOS defaults not in nix-darwin ──
    /usr/bin/defaults write -g NSRecentDocumentsLimit 0
    /usr/bin/defaults write -g AppleMeasurementUnits -string "Centimeters"
    /usr/bin/defaults write -g AppleMetricUnits -int 1
    /usr/bin/defaults write -g AppleTemperatureUnit -string "Celsius"
    /usr/bin/defaults write -g "com.apple.mouse.scaling" -float 3
    /usr/bin/defaults write -g "com.apple.sound.beep.feedback" -int 0
    /usr/bin/defaults write -g "com.apple.sound.beep.flash" -int 0

    # Finder: custom window target
    /usr/bin/defaults write com.apple.finder NewWindowTarget -string "PfLo"
    /usr/bin/defaults write com.apple.finder NewWindowTargetPath -string "file:///Users/darrenlu/Dropbox/"
    /usr/bin/defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
    /usr/bin/defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
    /usr/bin/defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

    # Trackpad: force touch and click settings
    /usr/bin/defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -int 1
    /usr/bin/defaults write com.apple.AppleMultitouchTrackpad ForceSuppressed -int 1
    /usr/bin/defaults write com.apple.AppleMultitouchTrackpad ActuationStrength -int 0
    /usr/bin/defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 0
    /usr/bin/defaults write com.apple.AppleMultitouchTrackpad SecondClickThreshold -int 0

    # ── BTM: Patch LaunchAgents with AssociatedBundleIdentifiers ──
    echo "BTM: patching LaunchAgents..."
    ${patchCommands}
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
  # LaunchAgents via nix-darwin
  # Agents use wrapper binaries inside BTM-managed .app stubs for icon grouping.
  # Post-activation script patches plists with AssociatedBundleIdentifiers.
  # ═══════════════════════════════════════════════════════════════════════════

  launchd.user.agents.postgresql-server = {
    serviceConfig = {
      Label = "org.postgresql.server";
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

  launchd.user.agents.postgresql-backup = {
    serviceConfig = {
      Label = "org.postgresql.backup";
      ProgramArguments = [ "${btmStubDir}/Postgres.app/Contents/MacOS/PostgresBackup" ];
      StartCalendarInterval = [{ Hour = 3; Minute = 0; }];
      StandardOutPath = "/Users/darrenlu/.local/state/postgresql/backup-stdout.log";
      StandardErrorPath = "/Users/darrenlu/.local/state/postgresql/backup-stderr.log";
      EnvironmentVariables = {
        HOME = "/Users/darrenlu";
      };
    };
  };

  launchd.user.agents.polymarket-monitor = {
    serviceConfig = {
      Label = "com.polymarket.data-monitor";
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
