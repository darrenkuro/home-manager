INSTALL_TAG=(MAC)
REQUIRED_TOOLS=(afplay)
_check_preamble || return 0

# noise [track]: toggle a looping background track from ~/.local/share/audio.
# No track means ambience-noise. Naming a different track while one plays switches to it.
noise() {
    local AUDIO_DIR="$HOME/.local/share/audio"
    local TRACK="${1:-ambience-noise}"
    local AUDIO_PATH="$AUDIO_DIR/$TRACK.m4a"
    local PID_FILE="/tmp/loop_audio.pid"
    local TRACK_FILE="/tmp/loop_audio.track"

    # Ensure the audio file exists
    if [ ! -f "$AUDIO_PATH" ]; then
        echo "❌ Audio file not found: $AUDIO_PATH"
        echo "Available: $(cd "$AUDIO_DIR" && ls -- *.m4a | sed 's/\.m4a$//' | tr '\n' ' ')"
        return 1
    fi

    # If already playing, stop it; same track (or no track given) means toggle off
    if [ -f "$PID_FILE" ]; then
        local PID PLAYING
        PID=$(cat "$PID_FILE")
        PLAYING=$(cat "$TRACK_FILE" 2>/dev/null)
        /bin/rm -f "$PID_FILE" "$TRACK_FILE"
        if kill -0 "$PID" 2>/dev/null; then
            # Kill afplay child first, then the subshell
            pkill -P "$PID" 2>/dev/null
            kill "$PID" 2>/dev/null
            if [ -z "$1" ] || [ "$TRACK" = "$PLAYING" ]; then
                return 0
            fi
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
    echo "$TRACK" > "$TRACK_FILE"
}
