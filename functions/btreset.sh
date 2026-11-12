INSTALL_TAG=(MAC)
INSTALL_PROFILE=(PERSONAL)
REQUIRED_TOOLS=(blueutil ssh)
_check_preamble || return 0

# btreset [host]
# Power-cycle Bluetooth to get Universal Control (and other Continuity links)
# going again. Without an argument it cycles this Mac; with an ssh host
# (`btreset work`) it cycles that Mac over ssh, which rides on Tailscale and
# never depends on Bluetooth. Laptop-only on purpose: the work iMac has no
# keyboard of its own, so its radio is only ever cycled from here, where a
# failed power-on is still recoverable by running it again. After switching
# the radio back on it waits for `blueutil -p` to report 1, retrying a few
# times, and reports failure instead of leaving the radio off silently.
#
# Examples:
#   btreset           # this Mac
#   btreset work      # the iMac, over ssh
btreset() {
    local host="${1:-}"
    # One POSIX sh snippet, run locally or on the remote side; the PATH line
    # covers non-interactive ssh, where ~/.nix-profile/bin may be missing.
    # shellcheck disable=SC2016  # expands where it runs, not here
    local cycle='export PATH="$HOME/.nix-profile/bin:$PATH"
        blueutil -p 0 && sleep 3
        for i in 1 2 3 4 5; do
            blueutil -p 1
            sleep 2
            [ "$(blueutil -p)" = 1 ] && exit 0
        done
        exit 1'

    if [ -n "$host" ]; then
        if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$host" true 2> /dev/null; then
            echo "btreset: $host unreachable" >&2
            return 1
        fi
        if ssh -o BatchMode=yes "$host" "$cycle"; then
            echo "btreset: $host Bluetooth back on"
        else
            echo "btreset: $host Bluetooth did NOT come back on — run again or 'ssh $host blueutil -p 1'" >&2
            return 1
        fi
    else
        if sh -c "$cycle"; then
            echo "btreset: Bluetooth back on"
        else
            echo "btreset: Bluetooth did NOT come back on — run 'blueutil -p 1'" >&2
            return 1
        fi
    fi
}
