# Source all functions in /function dir
# Each script uses _check_preamble to gate on INSTALL_TAG and REQUIRED_TOOLS.

source "$HM/functions/_preamble.sh"

for f in "$HM"/functions/*.sh; do
  [[ "${f##*/}" == _* ]] && continue
  [ -r "$f" ] && source "$f"
done

# Note: ~/.local/bin is on PATH via home.sessionPath (env.nix), which loads in
# .zshenv — early and for all shell types. It was added here previously, but
# .zshrc runs too late (interactive-only) for tools needed at source time.
