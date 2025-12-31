<h1 align="center">Home manager</h1>

<p align="center">
    <img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"/>
    <img src="https://img.shields.io/badge/status-maintained-brightgreen" alt="Status">
    <img src="https://img.shields.io/badge/date-Dec%208%2C%202025-ff6984?style=flat-square&logo=Cachet&logoColor=white" alt="Date"/>
</p>

> My personal flake.nix for home manager.

---

## 🚀 Overview

This repository contains my personal Home Manager configuration, used to declaratively define my user-level environment across multiple machines (macOS and Linux). Linux has no root privilege and therefore is used as rootless.

## 🧰 Tech Stack: ![Nix](https://img.shields.io/badge/-Nix-3f3f3f?style=flat-square&logo=nixos&logoColor=white)

---

## 🛠️ Configuration

### Installation & Usage

```bash
# Install nix
sh <(curl -L https://nixos.org/nix/install)

# Allow nix flakes
mkdir -p ~/.config/nix
echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf

# Run home-manager, current [tag] include mac and ft
nix run home-manager/master -- switch --flake ~/.config/home-manager#[tag]

# To update run:
nix flake update
```

---

## Notes

- You cannot define the same attribute twice in a single Nix file, that is a Nix language thing. But same attribute in different files tend to merge (barring some exceptions?) and that is a home-manager thing.
- On MacOS: /etc/zshenv -> user zshenv -> /etc/zprofile (This is where Apple handle PATH) -> user zprofile -> (/etc/zshrc_Apple_Terminal) -> /etc/zshrc -> user zshrc -> /etc/zlogin -> user zlogin.
- GUI apps highly dependent on the env and the kind of rendering it uses; on 42 machines, GLX lib is dead on rootless it seems, only X11 and GTK4 working; DO NOT TRY OPENGL! Too much work.
- In the rootless nix environment, `code` does not work and fail silently, fix is run `code -no-sandbox` instead; be aware of that this runs vs code with user privilege and could potentially be dangerous.
- Note that nix adds sourcing the env during installation place but may not always be visible. On MacOS for instance that system update could overwrite `/etc/zshrc` and erase the sourcing; manually add `source /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh` somewhere if that were to happen; for rootless (single user) `source ~/.nix-profile/etc/profile.d/nix.sh`.
- In many use cases, copying files in place could be better; for example, in rootless env sometimes config needs to be loaded outside of the nix env and copying in place can ensure correctness. And for vs code settings, where experiments should be allowed, and the app will often try to change it as well.
- Do not over do it with apps that clearly shouldn't be managed by nix! (Basically any GUI, especially ones that updates often, i.e. broswers, Discord, etc.)

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).
