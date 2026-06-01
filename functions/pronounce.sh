INSTALL_TAG=(MAC)
REQUIRED_TOOLS=(say ffmpeg curl)
_check_preamble || return 0

# pronounce <word> [voice]
# Generates MP3 audio via macOS `say` (→ AIFF, transcoded with ffmpeg),
# uploads to Anki via AnkiConnect, prints [sound:...] for a card field.
#
# Requires Anki running with the AnkiConnect addon (localhost:8765).
#
# Voices (run `say -v '?'` for the full list):
#   English (default), Anna (German), Thomas (French), Kyoko (Japanese),
#   Mónica (Spanish), Ting-Ting (Mandarin), Yuna (Korean), Milena (Russian)
#
# Examples:
#   pronounce "Eratosthenes"
#   pronounce "Guten Tag" Anna
#   pronounce "Bonjour" Thomas
pronounce() {
  if [ $# -eq 0 ]; then
    echo "usage: pronounce <word> [voice]" >&2
    echo "  list voices: say -v '?'" >&2
    return 1
  fi

  local word="$1"
  local voice="${2:-}"
  local safe="${word//[^A-Za-z0-9._-]/_}"
  local aiff="/tmp/${safe}.aiff"
  local mp3="/tmp/${safe}.mp3"

  # Verify AnkiConnect is reachable
  local ver
  ver=$(curl -s -m 2 http://localhost:8765 -d '{"action":"version","version":6}' 2> /dev/null)
  if [ -z "$ver" ] || ! printf '%s' "$ver" | grep -q '"result"'; then
    echo "AnkiConnect not reachable at localhost:8765 — start Anki with AnkiConnect addon." >&2
    return 1
  fi

  # Generate audio (AIFF)
  if [ -n "$voice" ]; then
    say -v "$voice" -o "$aiff" "$word" || { echo "say failed (unknown voice?)" >&2; return 1; }
  else
    say -o "$aiff" "$word"
  fi

  # Transcode AIFF → MP3 (libmp3lame, 96k CBR — plenty for speech, ~10x smaller than AIFF)
  ffmpeg -y -loglevel error -i "$aiff" -codec:a libmp3lame -b:a 96k "$mp3" \
    || { echo "ffmpeg failed" >&2; /bin/rm -f "$aiff"; return 1; }

  # Upload to Anki's media folder via storeMediaFile (path mode)
  local result
  result=$(curl -s -X POST http://localhost:8765 -d \
    "$(printf '{"action":"storeMediaFile","version":6,"params":{"filename":"%s.mp3","path":"%s"}}' "$safe" "$mp3")")

  if printf '%s' "$result" | grep -q '"error":null'; then
    printf '[sound:%s.mp3]\n' "$safe"
    /bin/rm -f "$aiff" "$mp3"
  else
    echo "Upload failed: $result" >&2
    return 1
  fi
}
