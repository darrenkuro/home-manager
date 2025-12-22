#!/usr/bin/env bash

set -euo pipefail

NUC="${NUC:-/home/dlu/bin/nix-user-chroot}"
NIXROOT="${NIXROOT:-\"$HOME/sgoinfre/nix\"}"
[[ ! $(command -v nix) && -e '. ~/.nix-profile/etc/profile.d/nix.sh' ]] && source '~/.nix-profile/etc/profile.d/nix.sh'

# If already in a tmux session
if [[ -n "${TMUX-}" ]]; then
  exec "$NUC" "$NIXROOT" zsh -l
fi

exec tmux new-session -As dev "exec \"$NUC\" \"$NIXROOT\" zsh -l"
