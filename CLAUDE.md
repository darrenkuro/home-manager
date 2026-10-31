# CLAUDE.md

Guidance for Claude Code in this repository.

## What This Is

Nix Home Manager flake for four targets:

- **mac** (`aarch64-darwin`) — personal macOS
- **mac-work** (`aarch64-darwin`) — work iMac: same toolchain as personal, smaller app list, no BTM
- **ft** (`x86_64-linux`) — 42 school rootless Linux
- **hetzner** (`x86_64-linux`) — personal server (Ubuntu, user `deploy`): minimal profile — shell backbone + allowlist (eza/fd/fzf/bat/jq, neovim), no dev toolchains, no helix/claude/vscode

Machine identity (system, tag, profile, user — homeDir derived) lives in the `machines` map in `flake.nix`; `specialArgs` carry those values into every module, plus `machine` (the machine's map key — never call it `name`, which shadows the HM submodule's username arg). Three dimensions: `tag` (`"mac"`/`"linux"`, OS), `profile` (`"personal"`/`"work"`/`"server"`, purpose — macOS app/service choices per profile live in `profiles/macos.nix`; `server` trims packages/modules to a headless allowlist in `home.nix`), and `machine` for one-machine quirks (e.g. ft's chroot-nix plumbing gates on `machine == "ft"`; shell-side it's `$HM_NAME`).

## Commands

```bash
re      # mac: home-manager only (no sudo, brew, system.defaults, launchd); linux: home-manager switch
sure    # mac: full darwin-rebuild (sudo) + btm-patch-nix.sh (personal only)
# Both first bump claude-config to its pushed HEAD and commit flake.lock (`bumpOwn`, modules/system/aliases.nix)

# First-time install (mac; use #mac-work on the work iMac):
sudo -v && sudo nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake ~/.config/home-manager#mac && sudo ~/.config/home-manager/scripts/btm-patch-nix.sh && exec zsh

nix flake update                          # bump upstream inputs (manual)
dprint fmt <files>                        # Nix, JS/TS, JSON, Markdown, TOML, Python
shellcheck functions/*.sh scripts/*.sh
nix-collect-garbage -d
```

## Architecture

### Entry Points

- `flake.nix` — `machines` map → `darwinConfigurations.{mac,mac-work}` (nix-darwin + embedded HM with `useUserPackages = false`, so `re` and `sure` share `~/.nix-profile`; `sure`) and `homeConfigurations.<every machine>` (standalone HM, `re`)
- `darwin.nix` — nix-darwin system config (Homebrew, system.defaults, GUI env, nix gc/optimise, service imports)
- `home.nix` — main module: packages, shell config, zsh init chain, XDG config files

### Module Organization

- `modules/system/` — aliases, env vars, OS/machine-specific bits (linux-ft, tiling hotkeys, wallpaper)
- `modules/apps/` — per-app config; `mdserve` and `netusage` keep their source in-repo (`modules/apps/<name>/`)
- `modules/services/<name>/` — self-contained services:
  - `spec.nix` — shared facts (paths, port, package); imported by both halves
  - `darwin.nix` — system half: wrappers, launchd agents/daemons, BTM stub
  - `home.nix` — user half (omitted if nothing user-scoped)
  - `<Name>.app/` — static BTM stub bundle (`Info.plist`, `PkgInfo`, `icon.icns`)

### Toggles — disabled ≠ deleted

- **Services**: comment out the import line in root `darwin.nix` (and root `home.nix` if it has a user half), then `sure`. No `enableXxx` bools / `mkIf cfg.enable` gating. Polymarket is the parked exemplar.
- **Shell functions**: set `INSTALL_TAG=()` in the function file (e.g. `functions/icon.sh`).
- Never delete toggled-off code in an audit — it's deliberately parked.

### BTM (Background Task Management) — macOS Login Items

Shared logic in `lib/launchd-btm.nix` (plain functions, no module options):

- **`mkWrapper`** — named wrapper binary so BTM shows a real name (`useSystemBash = true` for pre-/nix-mount scripts)
- **`mkStubInstall`** — activation bash that installs one `.app` stub idempotently (manifest-checked to avoid BTM churn) and patches its user agents' `AssociatedBundleIdentifiers`
- **`stubDir`/`agentDir`** — path constants

Each `modules/services/<name>/darwin.nix` calls these and appends to `system.activationScripts.postActivation.text` (type `lines`). `scripts/btm-patch-nix.sh` (via `sure`) patches the Nix system-daemon plists, codesigns all stubs, unregisters stray `/nix/store/*.app` LaunchServices entries, and regroups third-party helper agents under their vendor app. Icons resolve by path containment: ProgramArguments points to a wrapper inside the stub. Gotchas + new-service template: `.claude/btm.md`.

The darwin-store daemon (`modules/services/nix-daemon/spec.nix`) looks up the Nix Store volume by name via `diskutil apfs list` at runtime — never hardcode its UUID (changes on Nix reinstall).

### Shell Functions

`functions/*.sh`, sourced by `scripts/source.sh` (skips `_*.sh` helpers). Each file: `INSTALL_TAG` array (+ optional `INSTALL_PROFILE`) → dependency check via `_preamble.sh` → function definition.

### Config Files — Two Strategies

1. **Nix-managed symlinks** (`xdg.configFile`) — read-only configs (dprint, starship, claude hooks/CLAUDE.md, skills)
2. **Copy-in-place** (`scripts/copy-files.sh`, `home.activation` after `writeBoundary`, `envsubst` templating) — configs writable at runtime (VSCode settings, tmux; alacritty + tmux-nix on ft)

### Claude Code Config

Owned by `modules/apps/claude.nix`:

- `CLAUDE.md` — symlinked from `configs/claude/`
- `skills/`, `hooks/` — merged from flake inputs (`claude-config`, `claude-plugins-official`, `obsidian-skills`) via `symlinkJoin`
- `settings.json` — Claude-owned (writable); activation `jq`-merges hm's `hooks`, `env.DISABLE_AUTOUPDATER` (binary only — `env.FORCE_AUTOUPDATE_PLUGINS` keeps plugins updating), `cleanupPeriodDays`, auto-installs required plugins and warns about plugin drift

### Key Environment Variables (`modules/system/env.nix`)

- `$HM` → `~/.config/home-manager`; `$DEV` → `~/Documents/dev`
- `$HM_TAG` / `$HM_PROFILE` / `$HM_NAME` — uppercased `tag` / `profile` / `machine` (`MAC`/`LINUX`, `PERSONAL`/`WORK`/`SERVER`); used by the `INSTALL_TAG`/`INSTALL_PROFILE` gates
- XDG dirs are explicitly set to keep `$HOME` clean

## Nix Conventions

- `lib.mkMerge` + `lib.mkIf (tag == "...")` for conditional attrsets in one file; `lib.optionals` for conditional list items
- Same attribute across files merges automatically
- Format with `dprint fmt <changed files>` (config at repo root; not `alejandra`/`nixfmt`). Known failures — hand-format to match surroundings: `flake.nix` (2-space indent vs `indentWidth: 4` — a full reformat is a ~200-line re-indent), `lib/launchd-btm.nix` (plugin's `if`-body / comment-before-`in` layout is valid but uglier), `functions/{tidy,noise}.sh`, `scripts/nix-prepend-path.sh` (zsh syntax shfmt can't parse)

## Workflow

- **Never run `re` / `sure` / `home-manager switch` / `darwin-rebuild switch` yourself** — manual-only, enforced by the `block-rebuild.sh` PreToolUse hook. Commit, then ask the user to run `! re` or `! sure`. Each build bakes its flake target into the aliases, so one wrong target (e.g. `.#mac` on the work iMac, which is `mac-work`) sticks
- **Always `git commit` before `re`/`sure`** — flakes only see committed files (uncommitted/untracked → "path does not exist"); new files need `git add` first
- Stage only your files (`git add <file> ...`), never `git add -A` — the tree may have unrelated dirty files
- **Live on `main`.** Routine changes commit directly to main; short-lived branches + small PRs for refactors/experiments only. Never let daily work accumulate on a side branch (flakes build whatever is checked out, so a stale main means the repo lies about the machine)
- Refactors: small, comprehensible steps — one logical change per PR (a plan phase with 5 sub-steps = 5 PRs); confirm scope before writing a batch of files and explain new structure in prose first — the user must be able to read every PR end-to-end. Base every PR on `main` (the user merges via the GitHub UI; stacked bases don't retarget and strand commits)
