# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Nix Home Manager flake for declaratively managing user environments across two machines:
- **mac** (`aarch64-darwin`) — personal macOS
- **ft** (`x86_64-linux`) — 42 school rootless Linux

The `tag` parameter (`"mac"` or `"ft"`) flows through the entire config to conditionally include modules, packages, and aliases.

## Commands

```bash
# Apply config (re-evaluates flake, rebuilds env, restarts shell)
# On mac:
home-manager switch --flake ~/.config/home-manager#mac && exec zsh
# On ft:
home-manager switch --flake ~/.config/home-manager#ft && exec zsh
# Or use the alias:
re

# Update flake inputs (nixpkgs, home-manager)
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
- `flake.nix` — defines two homeConfigurations (`mac`, `ft`) via `mkHome`, passing `tag` to all modules
- `home.nix` — main module: packages, shell config, zsh init chain, XDG config files, conditional imports

### Module Organization
- `modules/system/` — aliases (`aliases.nix` shared, `aliases-cp.nix` clipboard badges, `aliases-man.nix`), env vars (`env.nix`), platform-specific (`macos.nix`, `linux-ft.nix`)
- `modules/apps/` — per-app config: `git.nix`, `helix.nix`, `starship.nix`, `claude.nix`, `ssh.nix`
- `modules/services/` — macOS-only launchd services via BTM module (see below)

### BTM (Background Task Management) — macOS Launch Agents
Bypasses home-manager's default `launchd.agents` which wraps `ProgramArguments` in `/bin/sh -c "wait4path..."`, causing macOS BTM to show "sh" for all agents.

**Architecture:**
- `lib/launchd-btm.nix` — pure builders: `mkWrapper` (named shell binary with wait4path baked in), `mkPlist` (launchd plist from attrset)
- `app-stubs/` — static .app bundles (Info.plist, icon, dummy executable) for BTM icon resolution
- `modules/services/btm.nix` — shared activation: copies stubs, embeds wrapper binaries, codesigns, lsregister, bootout/bootstrap lifecycle
- `modules/services/*.nix` — each service registers via `btm.agents.<label>` and `btm.stubs.<Name> = { src, wrappers }`

**How icons work:** ProgramArguments points to a wrapper binary inside the .app stub. BTM resolves icons by path containment (executable is inside a .app → use that app's icon). Stubs are ad-hoc codesigned at activation time so the wrapper + bundle share one identity. After icon changes, reboot to refresh BTM. Do NOT use `sfltool resetbtm` — it wipes ALL login items system-wide.

**Current agents:** `postgresql.nix` (server + backup), `polymarket-monitor.nix`, `env-setter.nix` (propagates env vars to GUI domain via launchctl setenv)

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
`app-stubs/` — Static `.app` bundles for BTM icons. Each contains `Info.plist`, `PkgInfo`, dummy executable, and `icon.icns`. Wrapper binaries are embedded at activation time by `btm.nix`.

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
