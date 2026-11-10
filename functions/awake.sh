INSTALL_TAG=(MAC)
REQUIRED_TOOLS=(caffeinate)
_check_preamble || return 0

# awake [off | -t SECS | -w PID | <cmd> …]
# Keep display + system awake (Amphetamine replacement). `s` is AC-only.
# Runs detached so the shell is free; `awake off` lets the Mac sleep again.
# A new `awake`/`-t`/`-w` replaces the running one. `awake <cmd>` stays in the
# foreground, since caffeinate lives exactly as long as the command.
#
# Examples:
#   awake             # on until `awake off`
#   awake off
#   awake -t 3600     # one hour, in the background
#   awake make re     # only while the build runs
awake() {
    local PID_FILE="/tmp/awake.pid"

    if [ $# -gt 0 ] && [ "$1" != off ] && [ "${1#-}" = "$1" ]; then
        caffeinate -dims "$@"
        return
    fi

    # Stop the running one: `off`, or about to be replaced
    if [ -f "$PID_FILE" ]; then
        kill "$(cat "$PID_FILE")" 2> /dev/null
        /bin/rm "$PID_FILE"
    fi
    if [ "$1" = off ]; then
        echo "😴 awake off"
        return 0
    fi

    caffeinate -dims "$@" &
    disown
    echo $! > "$PID_FILE"
    echo "☕ awake on (pid $!) — \`awake off\` to stop"
}
