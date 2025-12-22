{lib, ...}: {
  # home.packages = with pkgs; [ ];

  programs.zsh.initContent = ''
    # # Source Nix (42 dir)
    #   [[ ! $(command -v nix) && -e '. ~/.nix-profile/etc/profile.d/nix.sh' ]] && source '~/.nix-profile/etc/profile.d/nix.sh'

    # Set faster keyboard repeat rate (only on X11)
    if command -v xset >/dev/null 2>&1 && [ -n "$DISPLAY" ]; then
      xset r rate 200 60 2>/dev/null || true
    fi
  '';

  # Copy user setting, not symlink, to make it usable outside of nix env
  home.activation.configCopy = lib.hm.dag.entryAfter ["writeBoundary"] ''
    mkdir -p "$HOME/.config/Code/User"
    envsubst < ${../../configs/settings.json} > "$HOME/.config/Code/User/settings.json"
    chmod u+w "$HOME/.config/Code/User/settings.json"

    mkdir -p "$HOME/.config/alacritty"
    envsubst < ${../../configs/alacritty.toml} > "$HOME/.config/alacritty/alacritty.toml"
    chmod u+w "$HOME/.config/alacritty/alacritty.toml"

    mkdir -p "$HOME/.config/tmux"
    envsubst < ${../../configs/tmux.conf} > "$HOME/.config/tmux/tmux.conf"
    chmod u+w "$HOME/.config/tmux/tmux.conf"
    tmux_conf="$HOME/.config/tmux/tmux.conf"
    tmp_conf="$tmux_conf.tmp"
    printf '%s\n' "set -g default-command 'exec /home/dlu/bin/nix-user-chroot "$HOME/sgoinfre/nix" zsh -l'" | cat - "$tmux_conf" > "$tmp_conf" && mv "$tmp_conf" "$tmux_conf"

    cat ${../../configs/tmux-nix.sh} > "/home/dlu/bin/tmux-nix"
    chmod +x "/home/dlu/bin/tmux-nix"


  '';

  programs.zsh.shellAliases = {
    re = "home-manager switch --flake ~/.config/home-manager#ft && exec zsh";
  };
}
