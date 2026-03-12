# Source all functions in /function dir
# Each script uses _check_preamble to gate on INSTALL_TAG and REQUIRED_TOOLS.

source "$HM/functions/_preamble.sh"

for f in "$HM"/functions/*.sh; do
  [[ "$f" == */_preamble.sh ]] && continue
  [ -r "$f" ] && source "$f"
done

# Source personal bin
if [ -d "$HOME/.local/bin" ]; then
  path=("$HOME/.local/bin" "${path[@]}")
fi

export PATH
