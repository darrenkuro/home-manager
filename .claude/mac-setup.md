# New Mac Setup Guide

Reference for setting up a fresh macOS machine. Most config is now declarative via nix-darwin/home-manager.

## Prerequisites

1. Sign into iCloud (for App Store, Photos sync)

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

- alfred, anki, brave-browser, claude, claude-code, dropbox, font-carlito, ghostty, notion, obsidian, pearcleaner, sf-symbols, steam, visual-studio-code
- No greedy flags, no auto-upgrade on rebuild — apps self-update or `brew upgrade` manually (dc0a34a)

### Homebrew Brews

- tmux (HEAD — fixes Claude Code rendering; drop once 3.7 releases)

### App Store (masApps)

- CleanMyMac, Developer, Final Cut Pro, iA Writer, Mirror Magnet, Xcode, Yoink

### Nix Packages (home.nix)

- Core: tokei, eza, fd, jq, fzf, rename, bat, gettext, wakatime-cli
- Dev: clang-tools, dprint, nil, shfmt, shellcheck, cargo/rustc + rust tools, asm-lsp, asmfmt, openssl, gnused, cmake
- Node: nodejs_22, typescript, typescript-language-server, pnpm, bun
- Python: python313, pip, virtualenv, flake8
- Mac: trash, ffmpeg, poppler-utils, yt-dlp, pandoc, colima, docker-\*
- Services: postgresql_17 + pgvector (via `modules/services/postgresql/home.nix`)

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
"cursor"
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

# Check services (polymarket only appears if its import is uncommented)
launchctl list | grep -E "postgresql|polymarket|nix"

# Verify env vars in GUI apps
# Open Claude Desktop > Settings > check CLAUDE_CONFIG_DIR is set

# After reboot, check BTM
# System Settings > General > Login Items > Background Task Management
# Should show Postgres and Nix (+ Polymarket if enabled) with correct icons
```

---

## Archive Notes

Music production tools (install when needed):

- Odesi, Mixed In Key, Logic Pro, Melodyne, VOCALOID, Native Access suite
