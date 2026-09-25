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
{ profile ? "personal" }: { config, lib, ... }: let
    homeDir = "/Users/darrenlu";
    profiles = import ./profiles/macos.nix;
    selected = profiles.${profile} or ( throw "Unknown macOS profile: ${profile}" );
    act = import ./lib/activation.nix { inherit lib; };
in
{
    # ── Services — comment out to disable ──
    imports = [
        # PostgreSQL is useful for the personal machine, but a clean work
        # profile should not start a local database at login.
        ./modules/services/nix-daemon/darwin.nix
        # ./modules/services/polymarket/darwin.nix
    ] ++ ( if selected.enablePostgresql
        then
            [ ./modules/services/postgresql/darwin.nix ]
        else
            [ ] );

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
        casks = selected.casks;
        masApps = selected.masApps;
    };

    # Fail-soft prelude (defines _hm_warn) — extraActivation is the earliest
    # user hook in the assembled activate script, so every later step
    # (homebrew override, defaults, BTM stubs) can use it.
    system.activationScripts.extraActivation.text = act.prelude;

    # Override nix-darwin's homebrew step: a dead cask/masApps id makes
    # `brew bundle` exit non-zero, which under the script-wide `set -e` used
    # to abort activation before home-manager and BTM patching ran. Reuses the
    # module's own brewBundleCmd (internal option — a rename in nix-darwin
    # fails loudly at eval, not silently at runtime).
    system.activationScripts.homebrew.text = lib.mkForce ''
        # Homebrew Bundle (fail-soft)
        echo >&2 "Homebrew bundle..."
        if [ -f "${config.homebrew.prefix}/bin/brew" ]; then
          ${act.failSoft "brew bundle"
    ( config.homebrew.onActivation.brewBundleCmd { onlyCheck = false; } )}
        else
          _hm_warn "Homebrew is not installed; skipped brew bundle"
        fi
    '';

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
            persistent-apps = selected.dockApps;
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

    # Post-activation: settings not in nix-darwin + BTM agent patching.
    # Each block is fail-soft; act.summary recaps warnings at the very end.
    system.activationScripts.postActivation.text = lib.mkMerge [
        ( act.failSoft "macOS defaults (post-activation)" ''
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
    /usr/bin/defaults write com.apple.finder NewWindowTargetPath -string "file:///Users/darrenlu/${selected.finderStartFolder}/"
    /usr/bin/defaults write com.apple.finder ShowHardDrivesOnDesktop -bool false
    /usr/bin/defaults write com.apple.finder ShowExternalHardDrivesOnDesktop -bool true
    /usr/bin/defaults write com.apple.finder ShowRemovableMediaOnDesktop -bool true

    # Trackpad: force touch and click settings
    /usr/bin/defaults write com.apple.AppleMultitouchTrackpad TrackpadRightClick -int 1
    /usr/bin/defaults write com.apple.AppleMultitouchTrackpad ForceSuppressed -int 1
    /usr/bin/defaults write com.apple.AppleMultitouchTrackpad ActuationStrength -int 0
    /usr/bin/defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 0
    /usr/bin/defaults write com.apple.AppleMultitouchTrackpad SecondClickThreshold -int 0
  '' )
        act.summary
    ];

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
