# nix-darwin system-level macOS config.
#
# Handles (requires sudo via darwin-rebuild, alias `sure`):
#   - Homebrew packages (brews, casks, masApps)
#   - macOS system defaults (Dock, Finder, Trackpad, etc.)
#   - GUI environment variables (launchd.user.envVariables)
#   - Service imports — launchd daemons/agents + BTM stubs live in
#     modules/services/<name>/darwin.nix (see imports list below)
#
# home-manager handles (no sudo, alias `re`):
#   - Nix packages in ~/
#   - Shell config, aliases, env vars
#   - XDG dotfiles and app configs
#   - Services' user halves (modules/services/<name>/home.nix)
#
{ ... }: let
    homeDir = "/Users/darrenlu";
in
{
    # ── Services — comment out to disable ──
    imports = [
        ./modules/services/postgresql/darwin.nix
        ./modules/services/nix-daemon/darwin.nix
        # ./modules/services/polymarket/darwin.nix
    ];

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
            # tmux 3.7 (released 2026-06-26) ships the Claude Code rendering fix; was on --HEAD until then.
            # Still brew (not nix) because pinned nixpkgs is on 3.6a — move to nix-managed tmux once it ships >=3.7.
            "tmux"
        ];
        casks = [
            "alfred"
            "anki"
            "brave-browser"
            "claude"
            "dropbox"
            "font-carlito"
            "ghostty"
            "notion"
            "obsidian"
            "pearcleaner"
            "sf-symbols"
            "spotify"
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

    # nix-darwin state version
    system.stateVersion = 5;
}
