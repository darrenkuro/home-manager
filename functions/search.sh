INSTALL_TAG=(MAC FT)
REQUIRED_TOOLS=(fd fzf tr open)
_check_preamble || return 0

search() {
    fd "$@" | fzf -0 | tr -d "\n" | xargs -0 open
}
