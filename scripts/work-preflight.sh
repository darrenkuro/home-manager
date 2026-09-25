#!/bin/bash
# Preflight for the work-Mac (mac-work) bootstrap. Read-only: catches the
# failure modes that otherwise surface halfway through the first
# darwin-rebuild — wrong arch, missing Homebrew, no GitHub SSH auth (the
# claude-config flake input is git+ssh), missing flakes support, repo in the
# wrong place. Run it after the README's SSH-key steps; it prints the
# bootstrap command when everything passes.
# shellcheck disable=SC2016  # single quotes are deliberate: check commands
# expand inside bash -c, and fix hints must print $(…) literally for copying
set -uo pipefail

HM="${HM:-$HOME/.config/home-manager}"
fail=0

# check <label> <fix hint> <command> — command runs via bash -c, silenced;
# the sudo ssh check still prompts on the tty, which is intended.
check() {
  if bash -c "$3" > /dev/null 2>&1; then
    printf '  \033[0;32m✓\033[0m %s\n' "$1"
  else
    printf '  \033[0;31m✗\033[0m %s\n' "$1"
    [[ -n "$2" ]] && printf '      fix: %s\n' "$2"
    fail=1
  fi
}

echo "work-mac preflight:"

check "Apple Silicon (mac-work is aarch64-darwin)" \
  "" \
  '[[ $(uname -m) == arm64 ]]'

check "Command Line Tools" \
  "xcode-select --install" \
  'xcode-select -p'

check "Homebrew at /opt/homebrew" \
  '/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"' \
  '[[ -x /opt/homebrew/bin/brew ]]'

check "Nix installed" \
  'sh <(curl -L https://nixos.org/nix/install) --daemon' \
  'command -v nix'

check "repo at $HM" \
  "git clone git@github.com:darrenkuro/home-manager.git ~/.config/home-manager" \
  "[[ -d $HM/.git ]]"

# ssh -T exits 1 even on success; the banner is the signal.
check "GitHub SSH auth (user)" \
  "see README: create key, add to GitHub, ssh-add --apple-use-keychain" \
  'ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"'

# The first activation evaluates the flake as root; it needs your agent.
check "GitHub SSH auth (sudo, agent forwarded)" \
  'run from a shell where ssh-add -l lists the key' \
  'sudo env SSH_AUTH_SOCK="${SSH_AUTH_SOCK:-}" ssh -T git@github.com 2>&1 | grep -q "successfully authenticated"'

# End-to-end: evaluating flake metadata fetches every input, proving the
# git+ssh ones resolve. Slow-ish on first run (downloads inputs).
[[ $fail -eq 0 ]] && check "flake inputs resolve" \
  "rerun without silencing: nix --extra-experimental-features 'nix-command flakes' flake metadata $HM" \
  "nix --extra-experimental-features 'nix-command flakes' flake metadata --no-write-lock-file $HM"

echo
if [[ $fail -eq 0 ]]; then
  cat << 'EOF'
all checks passed — bootstrap with:

  sudo env SSH_AUTH_SOCK="$SSH_AUTH_SOCK" \
    nix --extra-experimental-features "nix-command flakes" run nix-darwin -- \
    switch --flake ~/.config/home-manager#mac-work

note: cleanup="zap" removes Homebrew/App Store apps not in the work profile
on this first switch. afterwards, `re` and `sure` target mac-work.
EOF
else
  echo "fix the ✗ items above, then rerun: $0"
  exit 1
fi
