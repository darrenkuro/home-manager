# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

Nix Home Manager flake for declaratively managing user environments across two machines:

- **mac** (`aarch64-darwin`) — personal macOS
- **ft** (`x86_64-linux`) — 42 school rootless Linux

The `tag` parameter (`"mac"` or `"ft"`) flows through the entire config to conditionally include modules, packages, and aliases.

## Commands

> **Always `git commit` before `re`/`sure`.** Nix flakes evaluate from the git tree — uncommitted or untracked files cause "path does not exist" errors. Stage only your files (`git add <specific files>`), never `git add -A`.

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

# Format all supported files (Nix, JS/TS, JSON, Markdown, TOML, Python)
dprint fmt

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

- `modules/system/` — aliases, env vars
- `modules/apps/` — per-app config: `git.nix`, `helix.nix`, `starship.nix`, `claude.nix`, `ssh.nix`, `netusage.nix`
- `modules/services/<name>/` — self-contained services. Each has:
  - `spec.nix` — shared facts (paths, port, package); imported by both halves
  - `darwin.nix` — system half: wrappers, launchd agents/daemons, BTM stub
  - `home.nix` — user half: package, activation, env vars, aliases (omitted if nothing user-scoped)
  - `<Name>.app/` — static BTM stub bundle (`Info.plist`, `PkgInfo`, `icon.icns`)

### Toggles — disabled ≠ deleted

- **Services**: comment out the import line in root `darwin.nix` (and root `home.nix` if the service has a user half), then `sure`. No `enableXxx` bools. Polymarket is the parked exemplar.
- **Shell functions**: set `INSTALL_TAG=()` in the function file (e.g. `functions/icon.sh`).
- Never delete toggled-off code in an audit — it's deliberately parked.

### BTM (Background Task Management) — macOS Launch Agents

Shared BTM logic lives in `lib/launchd-btm.nix` (plain functions, no module options):

- **`mkWrapper`** — named wrapper binary so BTM shows a real name (use `useSystemBash = true` for pre-/nix-mount scripts)
- **`mkStubInstall`** — activation bash that installs one `.app` stub idempotently (manifest-checked to avoid BTM churn) and patches its user agents' `AssociatedBundleIdentifiers`
- **`stubDir`/`agentDir`** — exported path constants

Each `modules/services/<name>/darwin.nix` calls these for itself and appends to `system.activationScripts.postActivation.text` (type `lines` — contributions concatenate). System-daemon plists (Nix) are patched by `scripts/btm-patch-nix.sh`, which also codesigns all stubs (runs via `sure`).

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

1. **Nix-managed symlinks** (`xdg.configFile`) — for read-only configs (dprint, starship, claude hooks/CLAUDE.md, skills merged from flake inputs)
2. **Copy-in-place** (`scripts/copy-files.sh`) — for configs that need to be writable at runtime (VSCode settings, tmux; alacritty + tmux-nix on ft)

`copy-files.sh` runs during `home.activation` after `writeBoundary` and uses `envsubst` for templating.

### Claude Code Config

All Claude config is owned by `modules/apps/claude.nix`:

- `CLAUDE.md` — symlinked from `configs/claude/` (read-only, Nix-managed)
- `skills/`, `hooks/` — merged/sourced from flake inputs (`claude-config`, `claude-plugins-official`, `obsidian-skills`) via `symlinkJoin`
- `settings.json` — owned by Claude Code (writable); hm injects only the `hooks` key via an idempotent `jq` merge in its activation block, and warns about plugin drift

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
- Format with `dprint fmt` (not `alejandra` or `nixfmt`)

## Workflow

- Always `git commit` before running `re` or `sure` — flakes only see committed files, and new files need `git add` first
- Stage only files you changed (`git add <file> ...`), not `git add -A` — the working tree may have unrelated dirty files
- **Live on `main`.** Routine config changes commit directly to main; short-lived branches + small PRs for refactors/experiments only. Never let daily work accumulate on a side branch (flakes build whatever is checked out, so a stale main means the repo lies about the machine).
