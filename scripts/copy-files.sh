# Copy files in Place since these are important outside of nix env

case ${HM_TAG-} in
  MAC) VSCODE_DIR="$HOME/Library/Application Support/Code/User" ;;
  FT) VSCODE_DIR="$HOME/.config/Code/User" ;;
esac

# VSCode settings, so VSCode can change it freely without nix interfering
mkdir -p "$VSCODE_DIR"
envsubst < "$HM/configs/vscode-settings.jsonc" > "$VSCODE_DIR/settings.json"
chmod u+w "$VSCODE_DIR/settings.json"

# taskrc, so task can change it freely without nix interfering
mkdir -p "$XDG_CONFIG_HOME/task"
envsubst < "$HM/configs/taskrc.conf" > "$XDG_CONFIG_HOME/task/taskrc"
chmod u+w "$XDG_CONFIG_HOME/task/taskrc"

# Tmux, since we ft-linux needs it outside anyway
mkdir -p "$XDG_CONFIG_HOME/tmux"
envsubst < "$HM/configs/tmux.conf" > "$XDG_CONFIG_HOME/tmux/tmux.conf"
chmod u+w "$XDG_CONFIG_HOME/tmux/tmux.conf"

if [[ ${HM_TAG-} == "FT" ]]; then
  # Alacritty
  mkdir -p "$XDG_CONFIG_HOME/alacritty"
  envsubst < "$HM/configs/alacritty.toml" > "$XDG_CONFIG_HOME/alacritty/alacritty.toml"
  chmod u+w "$XDG_CONFIG_HOME/alacritty/alacritty.toml"

  # Tmux, add default command to always use nix env
  tmux_conf="$XDG_CONFIG_HOME/tmux/tmux.conf"
  tmp_conf="$tmux_conf.tmp"
  printf '%s\n' "set -g default-command 'exec /home/dlu/bin/nix-user-chroot "$HOME/sgoinfre/nix" zsh -l'" | cat - "$tmux_conf" > "$tmp_conf"
  mv "$tmp_conf" "$tmux_conf"

  # bin for autoload tmux and nix
  cat "$HM/configs/tmux-nix.sh" > "/home/dlu/bin/tmux-nix"
  chmod +x "/home/dlu/bin/tmux-nix"
fi
