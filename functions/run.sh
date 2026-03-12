INSTALL_TAG=(MAC FT)
REQUIRED_TOOLS=(cc grep)
_check_preamble || return 0

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
