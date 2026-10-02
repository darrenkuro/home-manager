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
    [ -z "$id" ] && {
        echo "usage: ccr <session-id> [claude args...]"
        return 1
    }

    local f
    f=$(find "$root" -name "${id}.jsonl" -print -quit 2> /dev/null)
    [ -z "$f" ] && {
        echo "No session '$id' found under $root"
        return 1
    }

    local cwd
    cwd=$(grep -o '"cwd":"[^"]*"' "$f" | head -1 | sed 's/.*"cwd":"//;s/"$//')
    [ -z "$cwd" ] && {
        echo "Couldn't read cwd from $f"
        return 1
    }

    echo "↻ Resuming ${id%%-*}… in $cwd"
    # Claude discovers a session by mapping cwd → a projects/ bucket and only
    # looks there (it does NOT search by id globally), so we must launch from
    # $cwd itself. If the original dir was deleted, fabricate it just for the
    # session — then rmdir it on exit if still empty, so a deleted project
    # doesn't leave a ghost dir behind. (rmdir only removes empty dirs, so
    # anything you create during the session is preserved.)
    (
        local fabricated=
        if ! cd "$cwd" 2> /dev/null; then
            echo "  (original dir gone — fabricating $cwd for this session)"
            if ! { mkdir -p "$cwd" && cd "$cwd"; }; then
                echo "Couldn't create $cwd" >&2
                exit 1
            fi
            fabricated=1
        fi
        claude --resume "$id" --dangerously-skip-permissions "${@:2}"
        [ -n "$fabricated" ] && rmdir "$cwd" 2> /dev/null &&
            echo "  (removed empty $cwd)"
    )
}
