# Source all functions in /function dir
# _preamble.sh sorts first (underscore < letters) and defines _check_preamble.
# Each remaining script uses it to gate on INSTALL_TAG and REQUIRED_TOOLS.

for f in "$HM"/functions/*.sh; do
  [ -r "$f" ] && source "$f"
done

# Source personal bin
if [ -d "$HOME/.local/bin" ]; then
  path=("$HOME/.local/bin" "${path[@]}")
fi

export PATH
