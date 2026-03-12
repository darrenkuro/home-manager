INSTALL_TAG=(MAC)
REQUIRED_TOOLS=(afplay)
_check_preamble || return 0

# --- Source

function noise {
    local AUDIO_PATH="$DBOX/audio/ambience-noise-30m.aiff"
    local PID_FILE="/tmp/loop_audio.pid"

    # Ensure the audio file exists
    if [ ! -f "$AUDIO_PATH" ]; then
        echo "❌ Audio file not found: $AUDIO_PATH"
        return 1
    fi

    # If already playing, toggle off
    if [ -f "$PID_FILE" ]; then
        local PID
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            # Kill afplay child first, then the subshell
            pkill -P "$PID" 2>/dev/null
            kill "$PID" 2>/dev/null
            /bin/rm "$PID_FILE"
            return 0
        else
            # PID file is stale
            /bin/rm "$PID_FILE"
        fi
    fi

    # afplay has no loop option, so use a shell loop with trap to kill child on exit
    (
        trap 'kill $PID 2>/dev/null; exit' TERM
        while true; do
            afplay -v 0.2 "$AUDIO_PATH" &
            PID=$!
            wait $PID
        done
    ) >/dev/null 2>&1 &!
    echo $! > "$PID_FILE"
}
