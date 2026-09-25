# Shared terminal-UI helpers for the maintenance commands (tidy/upgrade/archive).
#
# Underscore-prefixed → skipped by the source.sh auto-load loop and sourced
# explicitly right after _preamble.sh (same pattern, see _preamble.sh header).
#
# Colors are globals so command bodies can use them inline ($_C_DIM …) without
# each function redeclaring its own palette. $'…' makes them real ESC bytes, so
# they render whether printf sees them via %b or %s.
typeset -g _C_CYAN=$'\033[0;36m' _C_GREEN=$'\033[0;32m' _C_YELLOW=$'\033[0;33m' \
    _C_DIM=$'\033[2m' _C_RESET=$'\033[0m' _C_BOLD=$'\033[1m'

_header() { printf '\n%b━━━%b %b%s%b\n' "$_C_CYAN" "$_C_RESET" "$_C_BOLD" "$1" "$_C_RESET"; }
_task() { printf '  %b○%b %s' "$_C_DIM" "$_C_RESET" "$1"; }
_done() { printf '\r  %b●%b %s\n' "$_C_GREEN" "$_C_RESET" "$1"; }
_skip() { printf '\r  %b○%b %s %b(skipped)%b\n' "$_C_YELLOW" "$_C_RESET" "$1" "$_C_DIM" "$_C_RESET"; }
_item() { printf '    %b→%b %s\n' "$_C_DIM" "$_C_RESET" "$1"; }

# tilde-abbreviate a path for display
_tilde() { case "$1" in "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;; *) printf '%s' "$1" ;; esac }
