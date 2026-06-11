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
{ lib, pkgs, ... }: let
    # Feature flag: gate the polymarket data-monitor LaunchAgent without
    # removing the wrapper, BTM stub, or agent-mapping code. Flip to true
    # and run `sure` to re-enable.
    enableDataCollector = false;

    homeDir = "/Users/darrenlu";

    # ═══════════════════════════════════════════════════════════════════════════
    # BTM (Background Task Management) — app stubs for icon grouping
    # ═══════════════════════════════════════════════════════════════════════════

    btm = import ./lib/launchd-btm.nix { inherit lib pkgs; };

    # ── Polymarket Wrapper ──
    polymarketWorkDir = "${homeDir}/Documents/dev/polymarket-trading-bot";
    polymarketWrapper = btm.mkWrapper {
        name = "PolymarketMonitor";
        runtimeInputs = [ pkgs.nodejs_22 pkgs.pnpm ];
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

    # ── BTM stub install + agent patching — logic lives in lib/launchd-btm.nix ──
    btmInstallCommands = lib.concatStringsSep "\n"
    (
        [
            (
                btm.mkStubInstall {
                    name = "Nix";
                    app = ./modules/services/nix-daemon/Nix.app;
                    wrappers = [
                        { drv = nixDaemonWrapper; bin = "NixDaemonStart"; }
                        { drv = nixStoreMountWrapper; bin = "NixStoreMount"; }
                    ];
                } )
        ] ++
        lib.optionals enableDataCollector [
            (
                btm.mkStubInstall {
                    name = "Polymarket";
                    app = ./modules/services/polymarket/Polymarket.app;
                    wrappers = [ { drv = polymarketWrapper; bin = "PolymarketMonitor"; } ];
                    agents = [ "com.polymarket.data-monitor" ];
                } )
        ] );
in
{
    # ── Services (system half; each also has a home.nix imported from home.nix) ──
    imports = [ ./modules/services/postgresql/darwin.nix ];

    # Nix settings
    nix.settings.experimental-features = [ "nix-command" "flakes" ];

    # ── Homebrew ──
    homebrew = {
        enable = true;
        onActivation = {
            cleanup = "zap"; # Remove unlisted packages
            autoUpdate = false; # Don't `brew update` on rebuild (use `brew update` explicitly)
            upgrade = false; # Don't auto-upgrade — apps self-update or `brew upgrade` manually
        };
        brews = [
            { name = "tmux"; args = [ "HEAD" ]; } # HEAD fixes Claude Code rendering
        ];
        casks = [
            "alfred"
            "anki"
            "brave-browser"
            "claude"
            "claude-code"
            "dropbox"
            "font-carlito"
            "ghostty"
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
            persistent-apps = [
                "/System/Applications/Mail.app"
                "/System/Applications/Calendar.app"
                "/System/Cryptexes/App/System/Applications/Safari.app"
                "/Applications/Brave Browser.app"
                "/Applications/Obsidian.app"
                "/Applications/Ghostty.app"
                "/Applications/Visual Studio Code.app"
                "/System/Applications/Utilities/Activity Monitor.app"
                "/System/Applications/System Settings.app"
            ];
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

    # ── BTM: install app stubs + patch agent plists ──
    # System daemons (Nix) are patched by scripts/btm-patch-nix.sh (run via `sure`)
    ${btmInstallCommands}
    echo "BTM: done"
  '';

    # User (needed for home-manager integration to infer home.homeDirectory)
    users.users.darrenlu = { name = "darrenlu"; home = "/Users/darrenlu"; };

    # Required for user-level options (launchd.user.agents, system.defaults.dock, etc.)
    system.primaryUser = "darrenlu";

    # GUI env vars — single source of truth lives in lib/xdg-paths.nix.
    # Shell-only vars (HISTFILE, ZSH_SESSION_DIR, color codes, DBOX/DEV/HM,
    # NODE_REPL_HISTORY, PYTHON_HISTORY, HOMEBREW_NO_ENV_HINTS) stay in
    # modules/system/env.nix since GUI apps don't need them.
    launchd.user.envVariables = import ./lib/xdg-paths.nix { home = homeDir; };

    # Take over Nix daemon management from installer for BTM integration
    # This replaces /Library/LaunchDaemons/org.nixos.nix-daemon.plist
    launchd.daemons.nix-daemon = {
        serviceConfig = {
            Label = "org.nixos.nix-daemon";
            ProgramArguments = lib.mkForce [
                "${btm.stubDir}/Nix.app/Contents/MacOS/NixDaemonStart"
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
            ProgramArguments = [ "${btm.stubDir}/Nix.app/Contents/MacOS/NixStoreMount" ];
            RunAtLoad = true;
        };
    };

    launchd.user.agents.polymarket-monitor = lib.mkIf enableDataCollector {
        serviceConfig = {
            Label = "com.polymarket.data-monitor";
            ProgramArguments = [ "${btm.stubDir}/Polymarket.app/Contents/MacOS/PolymarketMonitor" ];
            WorkingDirectory = "/Users/darrenlu/Documents/dev/polymarket-trading-bot";
            RunAtLoad = true;
            KeepAlive = true;
            ThrottleInterval = 10;
            StandardOutPath = "/tmp/polymarket/monitor.log";
            StandardErrorPath = "/tmp/polymarket/monitor.err";
            EnvironmentVariables = { HOME = "/Users/darrenlu"; };
        };
    };

    # nix-darwin state version
    system.stateVersion = 5;
}
