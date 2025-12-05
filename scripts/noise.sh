function noise
{
    AUDIO_PATH="$DROPBOX/audio/ambience-noise.mp3"
    PID_FILE="/tmp/loop_audio.pid"

    # Check if ffplay is installed
    if ! command -v ffplay &>/dev/null; then
        echo "❌ ffplay not found. Install it with: brew install ffmpeg"
        return 1
    fi

    # Ensure the audio file exists
    if [ ! -f "$AUDIO_PATH" ]; then
        # osascript -e 'display notification "Audio file not found ❌"'
        echo "❌ Audio file not found: $AUDIO_PATH"
        return 1
    fi

    # If already playing
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if kill -0 "$PID" 2>/dev/null; then
            kill "$PID"
            /bin/rm "$PID_FILE"
            # osascript -e 'display notification "Stopped audio loop 🔇"'
            return 0
        else
            # PID file is stale
            /bin/rm "$PID_FILE"
        fi
    fi

    ffplay -nodisp -loop 0 "$AUDIO_PATH" </dev/null &> /dev/null &! 
    echo $! > "$PID_FILE"
    # osascript -e 'display notification "Started audio loop 🔁"'
}
