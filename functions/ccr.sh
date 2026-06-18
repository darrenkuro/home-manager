INSTALL_TAG=(MAC)
REQUIRED_TOOLS=(claude)
_check_preamble || return 0

# Resume a Claude Code session from any directory by its full session ID.
#
# Claude stores transcripts per launch-directory, so `claude --resume <id>`
# only finds sessions started in the *current* dir. This locates the
# transcript in any project folder, recovers its original cwd (each line
# records "cwd":"..."), and resumes there in a subshell so the caller's
# pwd is untouched.
#
#   $1  - full session ID (UUID)
#   $@  - extra args forwarded verbatim to `claude`
ccr() {
  local id="$1"
  local root="${CLAUDE_CONFIG_DIR:-$HOME/.config/claude}/projects"
  [ -z "$id" ] && { echo "usage: ccr <session-id> [claude args...]"; return 1; }

  local f
  f=$(find "$root" -name "${id}.jsonl" -print -quit 2>/dev/null)
  [ -z "$f" ] && { echo "No session '$id' found under $root"; return 1; }

  local cwd
  cwd=$(grep -o '"cwd":"[^"]*"' "$f" | head -1 | sed 's/.*"cwd":"//;s/"$//')
  [ -z "$cwd" ] && { echo "Couldn't read cwd from $f"; return 1; }

  echo "↻ Resuming ${id%%-*}… in $cwd"
  (cd "$cwd" && claude --resume "$id" --dangerously-skip-permissions "${@:2}")
}
