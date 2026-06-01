INSTALL_TAG=(MAC)
REQUIRED_TOOLS=(say curl)
_check_preamble || return 0

# pronounce <word> [voice]
# Generates AIFF audio via macOS `say`, uploads to Anki via AnkiConnect,
# prints the [sound:...] reference to paste into a card field.
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
  local file="/tmp/${safe}.aiff"

  # Verify AnkiConnect is reachable
  local ver
  ver=$(curl -s -m 2 http://localhost:8765 -d '{"action":"version","version":6}' 2> /dev/null)
  if [ -z "$ver" ] || ! printf '%s' "$ver" | grep -q '"result"'; then
    echo "AnkiConnect not reachable at localhost:8765 — start Anki with AnkiConnect addon." >&2
    return 1
  fi

  # Generate audio
  if [ -n "$voice" ]; then
    say -v "$voice" -o "$file" "$word" || { echo "say failed (unknown voice?)" >&2; return 1; }
  else
    say -o "$file" "$word"
  fi

  # Upload to Anki's media folder via storeMediaFile (path mode)
  local result
  result=$(curl -s -X POST http://localhost:8765 -d \
    "$(printf '{"action":"storeMediaFile","version":6,"params":{"filename":"%s.aiff","path":"%s"}}' "$safe" "$file")")

  if printf '%s' "$result" | grep -q '"error":null'; then
    printf '[sound:%s.aiff]\n' "$safe"
    /bin/rm -f "$file"
  else
    echo "Upload failed: $result" >&2
    return 1
  fi
}
