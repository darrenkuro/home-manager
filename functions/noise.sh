INSTALL_TAG=(MAC)

# --- Installation check
install=false
for tag in "${INSTALL_TAG[@]}"; do
  if [ "$tag" = "$HM_TAG" ]; then
    install=true
    break
  fi
done

$install || {
  unset INSTALL_TAG install
  return 0 2> /dev/null || exit 0 # Context-aware exit
}

# --- Dependency check
REQUIRED_TOOLS=(ffplay)
_missing_tools=()

# Determine script name (works in both bash and zsh)
_SCRIPT_NAME=${BASH_SOURCE[0]:-${(%):-%N}}
_SCRIPT_NAME=${_SCRIPT_NAME##*/}

for cmd in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    _missing_tools+=("$cmd")
  fi
done

if [ ${#_missing_tools[@]} -gt 0 ]; then
  printf '⚠️ Skipping sourcing of %s — missing required tools: %s\n' \
    "$_SCRIPT_NAME" "${_missing_tools[*]}" >&2
  unset REQUIRED_TOOLS _missing_tools _SCRIPT_NAME
  return 1 2>/dev/null || exit 1
fi

unset REQUIRED_TOOLS _missing_tools _SCRIPT_NAME

# --- Source

function noise {
    AUDIO_PATH="$DBOX/audio/ambience-noise.mp3"
    PID_FILE="/tmp/loop_audio.pid"

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
