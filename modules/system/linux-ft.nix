{
  pkgs,
  lib,
  config,
  ...
}: {
  home.packages = with pkgs; [
    # Only add as needed!
    # rustc
    # nodejs_latest
    # typescript
    # nodePackages.typescript-language-server

    # python311
    # python311Packages.pip
    # python311Packages.virtualenv
  ];

  # Set faster keyboard repeat rate (only on X11)
  programs.zsh.initContent = ''
    if command -v xset >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
      xset r rate 200 60 2>/dev/null || true
    fi
  '';

  # Copy user setting, not symlink, to make it usable
  home.activation.configCopy = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p "$HOME/.config/Code/User"
    envsubst < ${../../ext/settings.json} > "$HOME/.config/Code/User/settings.json"
    chmod u+w "$HOME/.config/Code/User/settings.json"

    mkdir -p "$HOME/.config/alacritty"
    envsubst < ${../../ext/alacritty.toml} > "$HOME/.config/alacritty/alacritty.toml"
    chmod u+w "$HOME/.config/alacritty/alacritty.toml"

    mkdir -p "$HOME/.config/tmux"
    envsubst < ${../../ext/tmux.conf} > "$HOME/.config/tmux/tmux.conf"
    chmod u+w "$HOME/.config/tmux/tmux.conf"
    tmux_conf="$HOME/.config/tmux/tmux.conf"
    tmp_conf="$tmux_conf.tmp"
    printf '%s\n' "set -g default-command 'exec /home/dlu/bin/nix-user-chroot "$HOME/sgoinfre/nix" zsh -l'" | cat - "$tmux_conf" > "$tmp_conf" && mv "$tmp_conf" "$tmux_conf"

    cat ${../../ext/tmux-nix} > "/home/dlu/bin/tmux-nix"
    chmod +x "/home/dlu/bin/tmux-nix"

    src="${config.home.profileDirectory}/share/vscode/extensions"
    dest="$HOME/.vscode/extensions"

    mkdir -p "$dest"
    for ext in "$src"/*; do
      name=$(basename "$ext")
      cp -RL --no-preserve=mode,ownership,timestamps "$ext" "$dest/$name"
    done
  '';

  programs.zsh.shellAliases = {
    re = "home-manager switch --flake ~/.config/home-manager#ft";
  };
}
