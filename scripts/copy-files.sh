# Copy files in Place since these are important outside of nix env

case ${HM_TAG-} in
  MAC)
    VSCODE_DIR="$HOME/Library/Application Support/Code/User";;
  FT)
    VSCODE_DIR="$HOME/.config/Code/User";;
esac

# VS code settings
mkdir -p "$VSCODE_DIR"
envsubst < ${../../configs/vscode-settings.jsonc} > "$VSCODE_DIR/settings.json"
chmod u+w "$VSCODE_DIR/settings.json"

if [[ ${HM_TAG-} != "FT" ]]; then
  return 0 2>/dev/null || exit 0
fi

# Alacritty
mkdir -p "$HOME/.config/alacritty"
envsubst < ${../../configs/alacritty.toml} > "$HOME/.config/alacritty/alacritty.toml"
chmod u+w "$HOME/.config/alacritty/alacritty.toml"

# tmux
mkdir -p "$HOME/.config/tmux"
envsubst < ${../../configs/tmux.conf} > "$HOME/.config/tmux/tmux.conf"
chmod u+w "$HOME/.config/tmux/tmux.conf"
tmux_conf="$HOME/.config/tmux/tmux.conf"
tmp_conf="$tmux_conf.tmp"
printf '%s\n' "set -g default-command 'exec /home/dlu/bin/nix-user-chroot "$HOME/sgoinfre/nix" zsh -l'" | cat - "$tmux_conf" > "$tmp_conf" && mv "$tmp_conf" "$tmux_conf"

# bin for autoload tmux and nix
cat ${../../configs/tmux-nix.sh} > "/home/dlu/bin/tmux-nix"
chmod +x "/home/dlu/bin/tmux-nix"
