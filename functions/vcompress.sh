INSTALL_TAG=(MAC FT)
REQUIRED_TOOLS=(ffmpeg ffprobe)
_check_preamble || return 0

# vcompress <input.mp4> [more inputs...]
# Thin wrapper around the video-compress skill's compress.sh so it can be run
# by hand. Re-encodes to x265/HEVC alongside the source, never overwriting;
# self-verifies each output (duration match + clean tail decode).
#
# Tunables (env vars, same as the skill):
#   CRF=28        quality — lower is better/bigger (x265 sweet spot 23-28)
#   HEIGHT=720    cap height, keep aspect, never upscale; HEIGHT=0 keeps source res
#   CODEC=x265    x265 (HEVC) | av1 (smaller, slower, less compatible)
#   PRESET=medium x265 preset name (slower = smaller)
#
# Examples:
#   vcompress "movie.mp4"
#   CRF=26 vcompress "clip.mp4"
#   HEIGHT=0 vcompress "screencast.mp4"
vcompress() {
  local script="$HOME/.config/claude/skills/video-compress/scripts/compress.sh"
  if [[ ! -x "$script" ]]; then
    echo "vcompress: skill script not found at $script" >&2
    echo "  (is claude-config deployed? check ~/.config/claude/skills/video-compress/)" >&2
    return 1
  fi
  "$script" "$@"
}
