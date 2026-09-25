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

| Tag   | System           | Description                    |
| ----- | ---------------- | ------------------------------ |
| `mac` | `aarch64-darwin` | Personal macOS (Apple Silicon) |
| `mac-work` | `aarch64-darwin` | Lean work macOS (Apple Silicon) |
| `ft`  | `x86_64-linux`   | 42 school Linux (rootless)     |

The `tag` parameter flows through the entire config, conditionally including modules, packages, and aliases per target.

### macOS profiles

`mac` remains the full personal setup. `mac-work` is a separate, lean work
profile: it retains the managed shell, Git, SSH, Helix, Claude, Ghostty,
VS Code, Brave, Slack, Notion, Alfred and the JavaScript/Python/Docker
toolchain. It deliberately excludes personal media, gaming, study, Dropbox,
local PostgreSQL, App Store apps, specialist Rust/assembly/C++ toolchains, and
media-download tools.

The exact app and Dock inventories live in `profiles/macos.nix`, making those
choices easy to review without touching system defaults or dotfiles.

> **Important:** profiles are alternative configurations for the same macOS
> user, not isolated macOS accounts. `homebrew.onActivation.cleanup = "zap"`
> means a full `mac-work` activation removes Homebrew-managed apps absent from
> its work list. Back up or move any data you need first, and use a separate
> macOS account if browser logins, app data, and `~/Library` must be isolated.

## Config Strategies

Configs are managed two ways depending on whether the target app needs write access:

- **Nix symlinks** (`xdg.configFile`) — for read-only configs (starship, dprint, Claude hooks/skills)
- **Copy-in-place** (`scripts/copy-files.sh`) — for configs that apps modify at runtime (VSCode settings, tmux; Claude `settings.json` gets a `jq` key-merge in `modules/apps/claude.nix`)

## Project Structure

```
.
├── flake.nix              # Entry point — machine map (user/arch/profile) +
│                          #   darwinConfigurations (`sure`), homeConfigurations (`re`)
├── darwin.nix             # macOS system: homebrew, defaults, GUI env, service imports
├── home.nix               # User env: packages, shell, activation, service imports
├── lib/
│   ├── launchd-btm.nix    # BTM helpers: mkWrapper, mkStubInstall, stub paths
│   └── xdg-paths.nix      # XDG env vars (shared by shell + GUI scopes)
├── modules/
│   ├── apps/              # Per-app config (git, helix, starship, claude, ssh, …)
│   ├── system/            # Aliases, env vars
│   └── services/<name>/   # Self-contained services: spec.nix + darwin.nix
│                          #   (+ home.nix if user-scoped) + <Name>.app BTM stub
├── functions/             # Shell functions sourced at init (each has tag/dep guard)
├── scripts/               # Shell init chain + activation scripts + btm-patch-nix.sh
└── configs/               # Raw config files (starship, tmux, vscode, claude, …)
```

**Toggling a service** (e.g. polymarket): comment/uncomment its import line in
`darwin.nix` (and `home.nix` if it has a user half), then run `sure` — same UX
as the Homebrew cask list. Shell functions toggle via `INSTALL_TAG=()`.

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

### Work macOS

Full bootstrap order on a fresh machine: Command Line Tools
(`xcode-select --install`) → Nix (step 1 above) → Homebrew (below) →
GitHub SSH key (below) → clone this repo to `~/.config/home-manager` →
`scripts/work-preflight.sh` → the switch command it prints. The preflight
script validates every prerequisite read-only and fails with a fix hint
instead of letting the first activation die halfway.

This configuration uses nix-darwin's Homebrew module for the work applications
(Alfred, Brave, Claude, Ghostty, Notion, Slack, and VS Code). Homebrew is not
installed by Home Manager or nix-darwin, so install it once before the first
switch:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew --version
```

Read the installer prompt before confirming; on Apple Silicon it installs under
`/opt/homebrew`. If the new terminal cannot find `brew`, follow the installer’s
printed "Next steps" to add Homebrew to your shell `PATH`.

The flake includes the private `claude-config` repository over SSH. Complete
this sequence before the first switch. Replace the key path below if you use a
different key name.

```bash
# 1. Only if this Mac does not already have a GitHub SSH key: create one.
ssh-keygen -t ed25519 -C "your-github-email" -f ~/.ssh/id_ed25519

# 2. Copy the PUBLIC key. In GitHub, open Settings → SSH and GPG keys →
#    New SSH key, choose "Authentication Key", and paste it there.
pbcopy < ~/.ssh/id_ed25519.pub

# 3. Load the PRIVATE key into the macOS SSH agent and save its passphrase
#    in Keychain. This is needed because the first Nix activation uses sudo.
#    If no agent is already available, start one for this terminal session.
if [ -z "${SSH_AUTH_SOCK:-}" ]; then eval "$(ssh-agent -s)"; fi
ssh-add --apple-use-keychain ~/.ssh/id_ed25519

# 4. Test normal GitHub access. The expected success message says GitHub does
#    not provide shell access; that is normal and confirms authentication.
ssh -T git@github.com

# 5. Test the same key is visible to the privileged process used by Nix.
sudo env SSH_AUTH_SOCK="$SSH_AUTH_SOCK" ssh -T git@github.com
```

Then run the preflight and, once every check passes, the bootstrap command it
prints (the `SSH_AUTH_SOCK` forwarding is required only for this first
privileged evaluation — it lets root use your already-unlocked SSH agent
rather than looking for a separate root GitHub key):

```bash
~/.config/home-manager/scripts/work-preflight.sh
```

After activation, `re` and `sure` automatically keep using `mac-work`.

If the `sudo env ...` command still reports `Permission denied (publickey)`,
confirm that `ssh-add -l` lists the key and that `ssh -T git@github.com` works
as your normal user. Do not add a private key to `/var/root/.ssh`.

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
