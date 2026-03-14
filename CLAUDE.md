# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Nix Home Manager flake for declaratively managing user environments across two machines:
- **mac** (`aarch64-darwin`) — personal macOS
- **ft** (`x86_64-linux`) — 42 school rootless Linux

The `tag` parameter (`"mac"` or `"ft"`) flows through the entire config to conditionally include modules, packages, and aliases.

## Commands

```bash
# On mac — two rebuild modes:
re      # home-manager only (no sudo, no brew/system changes)
sure    # full darwin-rebuild + BTM patching (with sudo)

# On ft (home-manager only):
re      # runs home-manager switch

# First-time install (mac only):
sudo -v && sudo nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake ~/.config/home-manager#mac && sudo ~/.config/home-manager/scripts/btm-patch-nix.sh && exec zsh

# Update flake inputs (nixpkgs, home-manager, nix-darwin)
nix flake update

# Format Nix files
alejandra .

# Lint shell scripts
shellcheck functions/*.sh scripts/*.sh

# Garbage collect old nix generations
nix-collect-garbage -d
```

## Architecture

### Entry Points
- `flake.nix` — defines configurations:
  - `darwinConfigurations.mac` — nix-darwin system config with embedded home-manager (`sure`)
  - `homeConfigurations.mac` — standalone home-manager for fast rebuilds (`re`)
  - `homeConfigurations.ft` — standalone home-manager config for Linux
- `darwin.nix` — nix-darwin system-level config (LaunchDaemons, system settings, BTM, Homebrew)
- `home.nix` — main module: packages, shell config, zsh init chain, XDG config files

### Module Organization
- `modules/system/` — aliases, env vars, platform-specific (`linux-ft.nix`)
- `modules/apps/` — per-app config: `git.nix`, `helix.nix`, `starship.nix`, `claude.nix`, `ssh.nix`
- `modules/services/` — service-specific activation and .app stubs (postgres, polymarket, nix-daemon)

### BTM (Background Task Management) — macOS Launch Agents

All BTM logic is in `darwin.nix`:
- **Wrappers** — named shell scripts via `lib/launchd-btm.nix`
- **App stubs** — `.app` bundles in `modules/services/*/` (embedded with wrappers at activation)
- **LaunchAgents/Daemons** — defined via `launchd.user.agents` and `launchd.daemons`
- **Activation** — postActivation installs stubs, codesigns, patches `AssociatedBundleIdentifiers`

**How icons work:** ProgramArguments points to a wrapper binary inside the .app stub. BTM resolves icons by path containment. After icon changes, reboot to refresh BTM.

**Rebuild aliases:**
- `re` — home-manager only (no BTM, no sudo, no brew)
- `sure` — full darwin-rebuild + `btm-patch-nix.sh` (with sudo)

### Nix Store Volume UUID Handling
The darwin-store wrapper dynamically looks up the Nix Store volume UUID by name at runtime instead of hardcoding it. This prevents issues after Nix reinstalls when the volume UUID changes. The wrapper uses `diskutil apfs list` to find the UUID of the volume named "Nix Store".

### Shell Functions
`functions/*.sh` — each file has a preamble pattern:
1. `INSTALL_TAG` array — which tags should source this function
2. Dependency check — skips if required tools are missing
3. Function definition

Sourced at shell init via `scripts/source.sh` which iterates `$HM/functions/*.sh`.

### Config Files — Two Strategies
1. **Nix-managed symlinks** (`xdg.configFile`) — for read-only configs (clang-format, starship, claude hooks/CLAUDE.md, skills merged from flake inputs)
2. **Copy-in-place** (`scripts/copy-files.sh`) — for configs that need to be writable at runtime (VSCode settings, taskrc, tmux, Claude `settings.json`)

`copy-files.sh` runs during `home.activation` after `writeBoundary`. It uses `envsubst` for templating and `jq` for merging JSON keys.

### App Stubs
`modules/services/*/` — Static `.app` bundles for BTM icons (Postgres.app, Polymarket.app, Nix.app). Each contains `Info.plist`, `PkgInfo`, and `icon.icns`. Wrapper binaries are embedded at activation time by `darwin.nix` postActivation.

### Claude Code Config
Managed via `modules/apps/claude.nix`:
- `CLAUDE.md` — symlinked from `configs/claude/` (read-only, Nix-managed)
- `skills/`, `hooks/` — merged/sourced from flake inputs (`claude-config`, `claude-plugins-official`, `obsidian-skills`) via `symlinkJoin`
- `settings.json` — owned by Claude Code; hm only injects the `hooks` key via `jq` merge in `copy-files.sh`

### Key Environment Variables
Defined in `modules/system/env.nix`:
- `$HM` → `~/.config/home-manager` (this repo)
- `$HM_TAG` → `"MAC"` or `"FT"` (uppercase, used by shell function preambles)
- `$DEV` → `~/Documents/dev`
- XDG dirs are explicitly set to keep `$HOME` clean

## Nix Conventions
- Use `lib.mkMerge` + `lib.mkIf (tag == "...")` for conditional attribute sets within a single file
- Use `lib.optionals (tag == "...")` for conditional list items (packages, imports)
- Same attribute defined across different files merges automatically (home-manager behavior)
- Format with `alejandra` (not `nixfmt`)
