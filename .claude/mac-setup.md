# New Mac Setup Guide

Reference for setting up a fresh macOS machine. Most config is now declarative via nix-darwin/home-manager.

## Prerequisites

1. Sign into iCloud (for App Store, Photos sync)
2. Install Homebrew: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

## Nix + Home Manager Bootstrap

```bash
# Install Nix
curl -L https://nixos.org/nix/install | sh

# Clone config
git clone git@github.com:darrenkuro/home-manager.git ~/.config/home-manager

# First-time darwin-rebuild (installs nix-darwin + hm)
sudo -v && sudo nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake ~/.config/home-manager#mac && sudo ~/.config/home-manager/scripts/btm-patch-nix.sh && exec zsh
```

After this, `re` (fast) and `sure` (full) aliases are available.

---

## Managed by nix-darwin/hm

### Homebrew Casks (darwin.nix)

- alfred, brave-browser, calibre, claude, claude-code, dropbox, notion, obsidian, pearcleaner, sf-symbols, steam, visual-studio-code

### Homebrew Brews

- tmux (HEAD)

### App Store (masApps)

- CleanMyMac, Developer, Final Cut Pro, iA Writer, Mirror Magnet, Xcode, Yoink

### Nix Packages (home.nix)

- Core: tokei, eza, fd, jq, fzf, rename, bat, gettext, wakatime-cli
- Dev: clang-tools, alejandra, nil, shfmt, shellcheck, cargo, rust-analyzer, rustfmt, clippy
- Node: nodejs_22, typescript, typescript-language-server, pnpm, bun
- Python: python313, pip, virtualenv, black, flake8
- Mac: trash, ghostty-bin, ffmpeg, tmux, poppler-utils, yt-dlp, colima, docker-\*

### System Defaults (darwin.nix)

- Dark mode, key repeat (fast), trackpad speed (3.0), tap to click
- Dock: autohide, no recents, size 61
- Finder: column view, path bar

### Shell Config

- zsh (history, aliases, functions)
- starship prompt
- git config + signing
- helix editor
- ssh keys

---

## Manual Setup Required

### Nix Packages to Add (not yet in home.nix)

```nix
# Consider adding:
imagemagick
marksman  # Markdown LSP
pkg-config
```

### Casks to Add (not yet in darwin.nix)

```nix
# Consider adding to darwin.nix casks:
"google-chrome"
"anki"
"cursor"
"the-unarchiver"
```

### App Store Apps to Add (not yet in masApps)

```nix
# Consider adding:
"Amphetamine" = ???;  # Keep-awake utility
"Magnet" = ???;       # Window manager (or use free Rectangle)
"DaisyDisk" = ???;    # Disk analyzer
"OmniFocus 3" = ???;  # Task manager
"Scrivener 3" = ???;  # Writing app
```

### Security Tools (install on-demand)

```bash
brew install ffuf hashcat
brew tap brewsci/homebrew-bio && brew install john-jumbo
```

### Alfred

1. Enter license (stored in 1Password or Dropbox)
2. Set sync folder: `~/Dropbox/src`
3. Preferences > Features > turn off menu bar icon
4. Enable snippet expansion

### GitHub Auth

```bash
gh auth login --web
```

### Email Accounts

System Settings > Internet Accounts — add manually

### Dock Arrangement

Now managed via `system.defaults.dock.persistent-apps` in darwin.nix

### Desktop Pictures

Manual selection

### Trackpad: 3-Finger Lookup

System Settings > Trackpad > Point & Click > Look up & data detectors > "Tap with three fingers"
(Currently not managed by nix-darwin)

### Safari

View > Show Favorites Bar

### VPN

Install NordVPN from App Store, sign in

---

## Credentials & Licenses

### Alfred License

```
--------- BEGIN ALFRED LICENSE ---------
[stored in 1Password]
---------- END ALFRED LICENSE ----------
```

### Other Licensed Apps

- Scrivener 3 — license in 1Password
- OmniFocus — linked to Omni account (darrenlu0416)
- Notion — linked to account
- Obsidian — linked to account
- Claude — linked to Anthropic account

---

## Post-Setup Verification

```bash
# Verify nix-darwin
sure

# Check services
launchctl list | grep -E "postgresql|polymarket|nix"

# Verify env vars in GUI apps
# Open Claude Desktop > Settings > check CLAUDE_CONFIG_DIR is set

# After reboot, check BTM
# System Settings > General > Login Items > Background Task Management
# Should show Postgres, Polymarket, Nix with correct icons
```

---

## Archive Notes

Music production tools (install when needed):

- Odesi, Mixed In Key, Logic Pro, Melodyne, VOCALOID, Native Access suite
