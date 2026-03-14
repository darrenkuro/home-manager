# nix-darwin system-level macOS config.
#
# Handles (requires sudo via darwin-rebuild):
#   - Homebrew packages (brews, casks, masApps)
#   - macOS system defaults (Dock, Finder, Trackpad, etc.)
#   - LaunchDaemons (nix-daemon, darwin-store) and LaunchAgents (postgres, polymarket)
#   - BTM app stubs and wrapper binaries
#   - GUI environment variables (launchd.user.envVariables)
#
# home-manager handles (no sudo via home-manager switch):
#   - Nix packages in ~/
#   - Shell config, aliases, env vars
#   - XDG dotfiles and app configs
#   - Directory creation (activation scripts)
#
{
  lib,
  pkgs,
  ...
}: let
  homeDir = "/Users/darrenlu";
  agentDir = "${homeDir}/Library/LaunchAgents";
  btmStubDir = "${homeDir}/.local/share/app-stubs";

  # ═══════════════════════════════════════════════════════════════════════════
  # BTM (Background Task Management) — app stubs for icon grouping
  # ═══════════════════════════════════════════════════════════════════════════

  btm = import ./lib/launchd-btm.nix {inherit lib pkgs;};

  # ── PostgreSQL Wrappers ──
  pg = pkgs.postgresql_17.withPackages (ps: [ps.pgvector]);
  pgDataDir = "${homeDir}/.local/share/postgresql/data";
  pgLogDir = "${homeDir}/.local/state/postgresql";
  pgSocket = "/tmp";
  pgPort = "5432";
  pgBackupDir = "${homeDir}/.local/share/postgresql/backups";

  pgConf = pkgs.writeText "postgresql.conf" ''
    listen_addresses = 'localhost'
    port = ${pgPort}
    unix_socket_directories = '${pgSocket}'
    max_connections = 50
    shared_buffers = 256MB
    work_mem = 16MB
    effective_cache_size = 1GB
    logging_collector = on
    log_directory = '${pgLogDir}'
    log_filename = 'postgresql-%a.log'
    log_rotation_age = 1d
    log_rotation_size = 0
    log_truncate_on_rotation = on
    log_min_duration_statement = 1000
    shared_preload_libraries = 'vector'
    lc_messages = 'C'
  '';
  pgHba = ./configs/postgresql/pg_hba.conf;

  postgresServerWrapper = btm.mkWrapper {
    name = "PostgresServer";
    runtimeInputs = [pg];
    text = ''
      exec postgres \
        -D "${pgDataDir}" \
        -c "config_file=${pgConf}" \
        -c "hba_file=${pgHba}" \
        -k "${pgSocket}"
    '';
  };

  postgresBackupWrapper = btm.mkWrapper {
    name = "PostgresBackup";
    runtimeInputs = [pg];
    excludeShellChecks = ["SC2043"];
    text = ''
      set -euo pipefail
      TIMESTAMP=$(date +%Y%m%d_%H%M%S)
      LOG="${pgLogDir}/backup.log"
      log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

      if ! pg_isready -h ${pgSocket} -p ${pgPort} -q 2>/dev/null; then
        log "ERROR: PostgreSQL not running, skipping backup"
        exit 1
      fi

      DBS=$(psql -h ${pgSocket} -p ${pgPort} -At -c \
        "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres';" postgres)

      if [ -z "$DBS" ]; then
        log "No user databases found, skipping backup"
        exit 0
      fi

      for db in $DBS; do
        mkdir -p "${pgBackupDir}"
        DUMPFILE="${pgBackupDir}/''${db}_''${TIMESTAMP}.dump"
        if pg_dump -h ${pgSocket} -p ${pgPort} --format=custom "$db" > "$DUMPFILE" 2>>"$LOG"; then
          log "OK: $db -> $DUMPFILE ($(du -h "$DUMPFILE" | cut -f1))"
        else
          log "FAIL: $db -> $DUMPFILE"
          rm -f "$DUMPFILE"
        fi
      done

      # Retention: 7 daily, 4 weekly (Mon), 12 monthly (1st)
      NOW=$(date +%s)
      for f in "${pgBackupDir}"/*.dump; do
        [ -f "$f" ] || continue
        BASENAME=$(basename "$f")
        DATE_STR=$(echo "$BASENAME" | grep -oE '[0-9]{8}_[0-9]{6}' | head -1)
        [ -z "$DATE_STR" ] && continue
        FILE_TS=$(date -j -f "%Y%m%d_%H%M%S" "$DATE_STR" +%s 2>/dev/null) || continue
        AGE_DAYS=$(( (NOW - FILE_TS) / 86400 ))
        FILE_DOW=$(date -j -f "%Y%m%d_%H%M%S" "$DATE_STR" +%u 2>/dev/null) || continue
        FILE_DOM=$(date -j -f "%Y%m%d_%H%M%S" "$DATE_STR" +%d 2>/dev/null) || continue
        DELETE=0
        if [ "$AGE_DAYS" -lt 7 ]; then DELETE=0
        elif [ "$AGE_DAYS" -lt 28 ]; then [ "$FILE_DOW" != "1" ] && DELETE=1
        elif [ "$AGE_DAYS" -lt 365 ]; then [ "$FILE_DOM" != "01" ] && DELETE=1
        else DELETE=1; fi
        if [ "$DELETE" -eq 1 ]; then
          rm -f "$f"
          log "PRUNE: $BASENAME (age=''${AGE_DAYS}d)"
        fi
      done
      log "Backup run complete"
    '';
  };

  # ── Polymarket Wrapper ──
  polymarketWorkDir = "${homeDir}/Documents/dev/polymarket-trading-bot";
  polymarketWrapper = btm.mkWrapper {
    name = "PolymarketMonitor";
    runtimeInputs = [pkgs.nodejs_22 pkgs.pnpm];
    text = ''
      cd "${polymarketWorkDir}"
      if [ -f .env ]; then
        set -a
        # shellcheck disable=SC1091
        source .env
        set +a
      fi
      exec pnpm tsx src/scripts/data-monitor.ts
    '';
  };

  # ── Nix Daemon Wrappers ──
  nixDaemonWrapper = btm.mkWrapper {
    name = "NixDaemonStart";
    text = ''
      /bin/wait4path /nix/var/nix/profiles/default/bin/nix-daemon
      exec /nix/var/nix/profiles/default/bin/nix-daemon
    '';
  };

  # useSystemBash = true because this runs BEFORE /nix is mounted
  nixStoreMountWrapper = btm.mkWrapper {
    name = "NixStoreMount";
    useSystemBash = true;
    text = ''
      nixVolumeDev=$(/usr/sbin/diskutil apfs list | \
        /usr/bin/awk '/Nix Store/ {print prev} {prev=$0}' | \
        /usr/bin/grep -o 'disk[0-9]*s[0-9]*')
      if [ -z "$nixVolumeDev" ]; then
        echo "Error: Could not find Nix Store volume device" >&2
        exit 1
      fi
      nixCryptoUUID=$(/usr/sbin/diskutil apfs listCryptoUsers "$nixVolumeDev" -plist | \
        /usr/bin/plutil -extract Users.0.APFSCryptoUserUUID raw -)
      if [ -z "$nixCryptoUUID" ]; then
        echo "Error: Could not find Nix Store crypto user UUID" >&2
        exit 1
      fi
      /usr/bin/security find-generic-password -s "$nixCryptoUUID" -w | \
        /usr/sbin/diskutil apfs unlockVolume "$nixVolumeDev" -stdinpassphrase -user "$nixCryptoUUID"
    '';
  };

  # ── BTM Stub Configuration ──
  btmStubs = {
    Postgres = {
      src = ./modules/services/postgresql/Postgres.app;
      wrappers = [
        {
          drv = postgresServerWrapper;
          bin = "PostgresServer";
        }
        {
          drv = postgresBackupWrapper;
          bin = "PostgresBackup";
        }
      ];
    };
    Polymarket = {
      src = ./modules/services/polymarket/Polymarket.app;
      wrappers = [
        {
          drv = polymarketWrapper;
          bin = "PolymarketMonitor";
        }
      ];
    };
    Nix = {
      src = ./modules/services/nix-daemon/Nix.app;
      wrappers = [
        {
          drv = nixDaemonWrapper;
          bin = "NixDaemonStart";
        }
        {
          drv = nixStoreMountWrapper;
          bin = "NixStoreMount";
        }
      ];
    };
  };

  # Generate BTM stub installation commands
  # Note: runs as root via sudo, so we use SUDO_USER to codesign with user's keychain
  btmStubCommands = lib.concatStringsSep "\n\n" (lib.mapAttrsToList (name: stubCfg: let
      manifestLines =
        ["src=${stubCfg.src}"]
        ++ map (w: "wrapper=${w.bin}:${w.drv}") stubCfg.wrappers;
      expectedManifest = lib.concatStringsSep "\\n" manifestLines;
    in ''
      _stub_dst="${btmStubDir}/${name}.app"
      _manifest="${btmStubDir}/.stub-manifest-${name}"
      _expected="$(printf '${expectedManifest}\n')"
      _real_user="''${SUDO_USER:-$(whoami)}"

      if [ -f "$_manifest" ] && [ "$(cat "$_manifest")" = "$_expected" ] && [ -d "$_stub_dst" ]; then
        echo "  stub unchanged: ${name}.app"
      else
        echo "  installing stub: ${name}.app"
        [ -d "$_stub_dst" ] && chmod -R u+w "$_stub_dst"
        rm -rf "$_stub_dst"
        cp -R "${stubCfg.src}" "$_stub_dst"
        chmod -R u+w "$_stub_dst"
        mkdir -p "$_stub_dst/Contents/MacOS"

        ${lib.concatMapStringsSep "\n" (w: ''
          cp "${w.drv}/bin/${w.bin}" "$_stub_dst/Contents/MacOS/${w.bin}"
          chmod u+wx "$_stub_dst/Contents/MacOS/${w.bin}"
        '')
        stubCfg.wrappers}

        printf '#!/bin/sh\nexit 0\n' > "$_stub_dst/Contents/MacOS/Stub"
        chmod u+x "$_stub_dst/Contents/MacOS/Stub"

        # Fix ownership (codesigning done by btm-patch-nix.sh post-activation)
        chown -R "$_real_user:staff" "$_stub_dst"
        printf '%s\n' "$_expected" > "$_manifest"
        chown "$_real_user:staff" "$_manifest"
      fi
    '')
    btmStubs);

  # Map labels to app stubs for BTM grouping
  # Format: { "label" = "AppName"; } where stub is at ${btmStubDir}/AppName.app
  btmAgentMapping = {
    "org.postgresql.server" = "Postgres";
    "org.postgresql.backup" = "Postgres";
    "com.polymarket.data-monitor" = "Polymarket";
  };

  # Generate patching commands for user agents
  patchAgentCommands = lib.concatStringsSep "\n" (lib.mapAttrsToList (label: appName: ''
      _plist="${agentDir}/${label}.plist"
      _stub="${btmStubDir}/${appName}.app"
      if [[ -f "$_plist" ]] && [[ -d "$_stub" ]]; then
        _bid=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$_stub/Contents/Info.plist" 2>/dev/null)
        if [[ -n "$_bid" ]]; then
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
    '')
    btmAgentMapping);
in {
  # Nix settings
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # ── Homebrew ──
  homebrew = {
    enable = true;
    onActivation = {
      cleanup = "zap"; # Remove unlisted packages
      autoUpdate = false; # Don't `brew update` on rebuild (use `brew update` explicitly)
      upgrade = true; # Upgrade existing packages to latest version
    };
    brews = [
      {
        name = "tmux";
        args = ["HEAD"];
      } # HEAD fixes Claude Code rendering
    ];
    casks = [
      "alfred"
      "brave-browser"
      "calibre"
      {
        name = "claude";
        greedy = true;
      } # Desktop app, fast-updating
      {
        name = "claude-code";
        greedy = true;
      } # CLI, fast-updating
      "dropbox"
      "font-carlito"
      "notion"
      "obsidian"
      "pearcleaner"
      "sf-symbols"
      "steam"
      "visual-studio-code"
    ];
    masApps = {
      "CleanMyMac" = 1339170533;
      "Developer" = 640199958;
      "Final Cut Pro" = 424389933;
      "iA Writer" = 775737590;
      "Mirror Magnet" = 1563698880;
      "Xcode" = 497799835;
      "Yoink" = 457622435;
    };
  };

  # macOS system defaults (declarative)
  system.defaults = {
    # ── NSGlobalDomain ──
    NSGlobalDomain = {
      AppleInterfaceStyle = "Dark";
      ApplePressAndHoldEnabled = false; # Key repeat instead of accent popup
      InitialKeyRepeat = 15; # Default 25
      KeyRepeat = 2; # Default 6
      "com.apple.trackpad.scaling" = 3.0;
      NSAutomaticPeriodSubstitutionEnabled = false;
    };

    # ── Dock ──
    dock = {
      autohide = true;
      show-recents = false;
      tilesize = 61;
      show-process-indicators = true;
      wvous-br-corner = 1; # Disabled hot corner
    };

    # ── Finder ──
    finder = {
      FXPreferredViewStyle = "clmv"; # Column view
      ShowPathbar = true;
      ShowStatusBar = false;
    };

    # ── Trackpad ──
    trackpad = {
      Clicking = true; # Tap to click
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

    # ── BTM: Install app stubs with embedded wrappers ──
    echo "BTM: syncing stubs..."
    _btm_user="''${SUDO_USER:-$(whoami)}"
    mkdir -p "${btmStubDir}"
    chown "$_btm_user:staff" "${btmStubDir}"
    ${btmStubCommands}

    # ── BTM: Patch user agents with AssociatedBundleIdentifiers ──
    # System daemons (Nix) are patched by scripts/btm-patch-nix.sh (run via sure alias)
    echo "BTM: patching LaunchAgents..."
    ${patchAgentCommands}
    echo "BTM: done"
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
      ProgramArguments = ["${btmStubDir}/Postgres.app/Contents/MacOS/PostgresServer"];
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
      ProgramArguments = ["${btmStubDir}/Postgres.app/Contents/MacOS/PostgresBackup"];
      StartCalendarInterval = [
        {
          Hour = 3;
          Minute = 0;
        }
      ];
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
      ProgramArguments = ["${btmStubDir}/Polymarket.app/Contents/MacOS/PolymarketMonitor"];
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
