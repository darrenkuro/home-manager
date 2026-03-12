INSTALL_TAG=(MAC FT)
REQUIRED_TOOLS=(git)
_check_preamble || return 0

# --- Source
function pull() {
  git clone "git@github.com:darrenkuro/$1.git" "${2:-$1}" && cd "${2:-$1}"
}
