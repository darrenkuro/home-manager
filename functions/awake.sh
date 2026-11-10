INSTALL_TAG=(MAC)
REQUIRED_TOOLS=(caffeinate)
_check_preamble || return 0

# awake [-t SECS | -w PID | <cmd> …]
# Keep display + system awake (Amphetamine replacement). `s` is AC-only.
# Bare `awake` toggles a detached caffeinate: run it again to let the Mac sleep.
# `-t`/`-w` also detach (they end on their own); `awake <cmd>` stays in the
# foreground, since caffeinate lives exactly as long as the command.
#
# Examples:
#   awake             # on until `awake` again
#   awake -t 3600     # one hour, in the background
#   awake make re     # only while the build runs
awake() {
    local PID_FILE="/tmp/awake.pid"

    if [ $# -gt 0 ] && [ "${1#-}" = "$1" ]; then
        caffeinate -dims "$@"
        return
    fi

    # Already on: toggle off
    if [ -f "$PID_FILE" ]; then
        local PID
        PID=$(cat "$PID_FILE")
        /bin/rm "$PID_FILE"
        if kill -0 "$PID" 2> /dev/null && [ $# -eq 0 ]; then
            kill "$PID"
            echo "😴 awake off"
            return 0
        fi
        kill "$PID" 2> /dev/null # replaced by a new -t/-w run
    fi

    caffeinate -dims "$@" &
    disown
    echo $! > "$PID_FILE"
    echo "☕ awake on (pid $!) — \`awake\` again to stop"
}
