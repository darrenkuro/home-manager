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

# Claude Code settings.json — owned by Claude, hm only injects hooks key
CLAUDE_SETTINGS="$XDG_CONFIG_HOME/claude/settings.json"
# Remove old hm symlink if present
if [[ -L "$CLAUDE_SETTINGS" ]]; then
  rm "$CLAUDE_SETTINGS"
fi
# Seed with empty object if missing
if [[ ! -f "$CLAUDE_SETTINGS" ]]; then
  echo '{}' > "$CLAUDE_SETTINGS"
fi
# Idempotently merge hooks config (preserves all other keys)
jq '. * {"hooks":{"PreToolUse":[{"matcher":{"tools":["Read","Edit","Write","MultiEdit","Bash"]},"hooks":[{"type":"command","command":"~/.config/claude/hooks/protect-env.sh"}]}]}}' \
  "$CLAUDE_SETTINGS" > "$CLAUDE_SETTINGS.tmp" \
  && mv "$CLAUDE_SETTINGS.tmp" "$CLAUDE_SETTINGS"
chmod u+w "$CLAUDE_SETTINGS"
