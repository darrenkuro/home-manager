<h1 align="center">Home Manager</h1>

<p align="center">
    <img src="https://img.shields.io/badge/license-MIT-blue?style=flat-square&logo=opensourceinitiative&logoColor=white" alt="License"/>
    <img src="https://img.shields.io/badge/status-maintained-brightgreen?style=flat-square&logo=git&logoColor=white" alt="Status">
</p>

> Declarative user environment for macOS and rootless Linux, powered by Nix flakes.

---

## Overview

Personal [Home Manager](https://github.com/nix-community/home-manager) configuration that defines shell, editor, toolchain, and dotfile setup across two machines. The Linux target (42 school) runs without root privileges, so the config is designed to work in a rootless Nix installation.

## Targets

| Tag   | System             | Description                  |
|-------|--------------------|------------------------------|
| `mac` | `aarch64-darwin`   | Personal macOS (Apple Silicon) |
| `ft`  | `x86_64-linux`     | 42 school Linux (rootless)   |

The `tag` parameter flows through the entire config, conditionally including modules, packages, and aliases per target.

## Config Strategies

Configs are managed two ways depending on whether the target app needs write access:

- **Nix symlinks** (`xdg.configFile`) — for read-only configs (starship, helix, clang-format, Claude hooks/skills)
- **Copy-in-place** (`scripts/copy-files.sh`) — for configs that apps modify at runtime (VSCode settings, taskrc, tmux, Claude `settings.json`)

## Project Structure

```
.
├── flake.nix              # Entry point — defines mac/ft homeConfigurations
├── home.nix               # Main module — packages, shell, imports
├── modules/
│   ├── apps/              # Per-app config (git, helix, starship, claude, ssh)
│   ├── system/            # Aliases, env vars, platform-specific settings
│   └── services/          # launchd/systemd services
├── functions/             # Shell functions sourced at init (each has tag/dep guard)
├── scripts/               # Shell init chain + activation scripts
└── configs/               # Raw config files (starship, ghostty, claude, etc.)
```

## Installation

### macOS (with nix-darwin)

```bash
# 1. Install Nix (multi-user/daemon mode)
sh <(curl -L https://nixos.org/nix/install) --daemon

# 2. First-time setup (runs both nix-darwin + home-manager)
sudo -v && sudo nix --extra-experimental-features "nix-command flakes" run nix-darwin -- switch --flake ~/.config/home-manager#mac && sudo ~/.config/home-manager/scripts/btm-patch-nix.sh && exec zsh

# 3. After initial setup, use the alias for updates
re

# 4. Update flake inputs
nix flake update
```

**Note:** On macOS, nix-darwin includes home-manager as a module, so `darwin-rebuild switch` activates both system and user config together.

### Updating an external flake input

Tools/configs installed via `flake = false` inputs (`netusage`, `claude-config`, `obsidian-skills`, etc.) are pinned to a specific commit in `flake.lock`. To bump just one to its latest:

```bash
# 1. Push the upstream change first (e.g., in ~/Documents/dev/netusage)
git push

# 2. In this repo, refresh just that input
nix flake lock --update-input netusage

# 3. Commit the new flake.lock and rebuild
git add flake.lock
git commit -m "Bump netusage to latest"
re   # or sure, depending on what changed
```

Use `nix flake update` only when you want to refresh **all** inputs (nixpkgs, home-manager, plus every `flake = false` source tree). For routine tool updates, `--update-input <name>` is faster and produces a smaller diff.

### Linux (rootless, 42 school)

```bash
# 1. Install Nix (single-user mode for rootless)
sh <(curl -L https://nixos.org/nix/install) --no-daemon

# 2. Enable flakes
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf

# 3. First run
nix run home-manager -- switch --flake ~/.config/home-manager#ft

# 4. After initial setup, use the alias
re

# 5. Update flake inputs
nix flake update
```

## Post-Reboot (macOS)

If `nix` is not found after a reboot, it means your current shell didn't initialize properly. Simply restart your shell:

```bash
exec zsh
```

The nix-daemon LaunchDaemon starts automatically on boot, and `/etc/zshrc` sources the Nix environment. A shell restart is usually all you need.

## Troubleshooting (macOS)

If Nix is broken after a reboot or system update, try these in order:

### 1. Nix Store Not Mounted

The most common issue. Check if `/nix/store` is empty or missing:

```bash
ls /nix/store
```

If empty, the encrypted APFS volume needs to be unlocked and mounted:

```bash
# Find the Nix Store volume device and crypto user UUID
diskutil apfs list | grep -B3 "Nix Store"
diskutil apfs listCryptoUsers disk3s7  # replace with actual device

# Unlock and mount (replace disk3s7 and UUID with values from above)
sudo security find-generic-password -s 7F2237ED-FBD0-463A-B08C-EC01257136DA -w | \
  sudo diskutil apfs unlockVolume disk3s7 -stdinpassphrase -user 7F2237ED-FBD0-463A-B08C-EC01257136DA
```

The `darwin-store` LaunchDaemon should handle this automatically on boot. If it's failing, check the logs:

```bash
log show --predicate 'senderImagePath contains "NixStoreMount"' --last 5m
```

### 2. nix-daemon Not Running

If `nix` commands hang or fail with daemon errors:

```bash
# Check status
sudo launchctl list | grep nix

# Reload the daemon
sudo launchctl load /Library/LaunchDaemons/org.nixos.nix-daemon.plist
```

### 3. Firmlink Missing

If `/nix` doesn't exist at all (rare, usually after major macOS updates):

```bash
# Check synthetic.conf
cat /etc/synthetic.conf

# If "nix" line is missing, add it and reboot
echo 'nix' | sudo tee -a /etc/synthetic.conf
# Then reboot for the firmlink to be created
```

### 4. Shell Not Sourcing Nix

If `/nix` exists and is mounted but `nix` command not found:

```bash
# Source manually
source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh

# Or restart shell
exec zsh
```

If `/etc/zshrc` was overwritten by a macOS update, restore it:

```bash
sudo darwin-rebuild switch --flake ~/.config/home-manager#mac
```

### 5. Nuclear Option — Reinstall Nix

If nothing else works:

```bash
curl -L https://nixos.org/nix/install | sh -s -- --daemon
```

Then re-run the first-time setup command from the Installation section.

---

<details>
<summary>Notes</summary>

### macOS

- Zsh load order: `/etc/zshenv` → user zshenv → `/etc/zprofile` (Apple PATH) → user zprofile → `/etc/zshrc` → user zshrc → `/etc/zlogin` → user zlogin.
- macOS system updates can overwrite `/etc/zshrc`. If this happens, run `sudo darwin-rebuild switch --flake $HM#mac` to restore the Nix sourcing. Alternatively, manually re-add to `/etc/zshrc`: `source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`.
- nix-darwin manages system LaunchDaemons (`/Library/LaunchDaemons/org.nixos.*`) which auto-start on boot.
- Avoid managing GUI apps through Nix — browsers, Discord, etc. update too frequently and fight with Nix's immutable store.

### Rootless Linux (42)

- VSCode requires `code --no-sandbox` in rootless Nix (silently fails otherwise). This runs without sandboxing — be aware of the security implications.
- GLX is broken on 42 machines under rootless Nix. Only X11 and GTK4 rendering work. Avoid OpenGL-dependent GUI apps.
- For rootless (single-user) Nix, source: `source ~/.nix-profile/etc/profile.d/nix.sh`.

### General Nix

- Same attribute in one file = error (Nix language). Same attribute across files = merged (Home Manager behavior).
- Copying configs in place is sometimes better than symlinking — especially when the app needs to modify the file, or when the config must be available outside the Nix env.

</details>

---

## License

[MIT](LICENSE) - Darren Kuro
