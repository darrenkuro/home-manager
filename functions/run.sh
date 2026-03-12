INSTALL_TAG=(MAC FT)

# --- Installation check
install=false
for tag in "${INSTALL_TAG[@]}"; do
  if [ "$tag" = "$HM_TAG" ]; then
    install=true
    break
  fi
done

$install || {
  unset INSTALL_TAG install
  return 0 2> /dev/null || exit 0 # Context-aware exit
}

# --- Dependency check
_SCRIPT_NAME=${BASH_SOURCE[0]:-${(%):-%N}}
_SCRIPT_NAME=${_SCRIPT_NAME##*/}
REQUIRED_TOOLS=(cc grep)
_missing_tools=()

for cmd in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$cmd" > /dev/null 2>&1; then
    _missing_tools+=("$cmd")
  fi
done

if [ ${#_missing_tools[@]} -gt 0 ]; then
  printf '⚠️ Skipping sourcing of %s — missing required tools: %s\n' \
    "$_SCRIPT_NAME" "${_missing_tools[*]}" >&2
  unset REQUIRED_TOOLS _missing_tools _SCRIPT_NAME INSTALL_TAG install
  return 1 2> /dev/null || exit 1
fi

unset REQUIRED_TOOLS _missing_tools _SCRIPT_NAME INSTALL_TAG install

# --- Source
function run() {
  if [ $# -eq 0 ]; then
    cc -Wall -Wextra -Werror -x c <(grep -hv "////" *.c)
  else
    cc -Wall -Wextra -Werror -x c <(grep -v "////" "$1")
  fi
  ./a.out "${@:2}"
  local ret=$?
  /bin/rm a.out
  return $ret
}
