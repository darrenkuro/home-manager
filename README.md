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

## Usage

```bash
# Install Nix
sh <(curl -L https://nixos.org/nix/install)

# Enable flakes
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf

# First run (mac or ft)
nix run home-manager -- switch --flake ~/.config/home-manager#mac

# After initial setup, use the alias
re

# Update flake inputs
nix flake update
```

---

<details>
<summary>Notes</summary>

### macOS

- Zsh load order: `/etc/zshenv` → user zshenv → `/etc/zprofile` (Apple PATH) → user zprofile → `/etc/zshrc` → user zshrc → `/etc/zlogin` → user zlogin.
- macOS system updates can overwrite `/etc/zshrc` and erase the Nix sourcing line. If Nix stops working after an update, re-add: `source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh`.
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
