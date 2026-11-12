INSTALL_TAG=(MAC)
INSTALL_PROFILE=(PERSONAL)
REQUIRED_TOOLS=(unison sqlite3 ssh)
_check_preamble || return 0

# tsync [unison options…]
# Two-way sync with the work iMac: ~/Documents/42tirana and the Claude session
# state (profiles 42tirana + claude in ~/.config/unison, modules/apps/unison.nix),
# plus the Alfred prefs bundle, which is a git repo (modules/apps/alfred.nix)
# and goes by git, not Unison: each side commits what Alfred wrote, pulls with
# rebase and pushes — iMac first over ssh, then here, then the iMac catches up.
# Each Mac only rewrites its own preferences/local/<hash>/, so that never
# conflicts; a conflict on a shared file (a workflow edited on both) is left
# for you with a warning and the Unison part still runs.
# Interactive by default: non-conflicting changes are listed and go through on
# confirmation, conflicts (changed on both sides) are asked one by one.
# `tsync -batch` propagates the non-conflicting changes unattended and leaves the
# conflicts for the next plain run. Run it before switching Macs and after a long
# session; keep one writer between syncs for the hub DB and bocal/.git.
# Checkpoints the hub DB's WAL on both sides first so the .sqlite file alone is
# complete. Skips with a log line when the iMac is not reachable.
#
# Examples:
#   tsync             # review and confirm
#   tsync -batch      # unattended, conflicts skipped
#   tsync -batch -silent
# _tsync_alfred [host] — commit, pull --rebase, push the Alfred bundle on this
# Mac, or on <host> over ssh. Prints one line; returns 1 on a conflict or a
# failed push (the caller carries on with Unison).
_tsync_alfred() {
    local host="${1:-}" label="${1:-laptop}"
    # shellcheck disable=SC2016  # expands where it runs, not here
    local round='export PATH="$HOME/.nix-profile/bin:$PATH"
        cd "$HOME/.config/alfred/Alfred.alfredpreferences" 2> /dev/null || { echo "not cloned"; exit 0; }
        n=$(git status --porcelain | wc -l | tr -d " ")
        [ "$n" != 0 ] && git add -A && git commit -q -m "alfred: $(hostname -s) $(date +%F)"
        git fetch -q || { echo "committed $n, fetch failed (offline?)"; exit 1; }
        b=$(git rev-list --count "HEAD..@{upstream}"); a=$(git rev-list --count "@{upstream}..HEAD")
        if [ "$b" != 0 ] && ! git pull -q --rebase 2> /dev/null; then
            git rebase --abort 2> /dev/null; echo "committed $n, CONFLICT — rebase by hand"; exit 1
        fi
        if [ "$a" != 0 ] && ! git push -q; then echo "committed $n, pulled $b, push FAILED"; exit 1; fi
        echo "committed $n, pulled $b, pushed $a"'
    local out rc=0
    if [ -n "$host" ]; then
        out=$(ssh -o BatchMode=yes "$host" "$round" 2>&1) || rc=1
    else
        out=$(sh -c "$round" 2>&1) || rc=1
    fi
    printf 'tsync: alfred (%s): %s\n' "$label" "$out"
    return "$rc"
}

tsync() {
    local peer=work
    local db="${TIRANA_ROOT:-$HOME/Documents/42tirana}/resources/data/42tirana.sqlite"
    local log="$HOME/Library/Logs/unison.log"
    local rc=0

    if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$peer" true 2> /dev/null; then
        printf '%s tsync: %s unreachable, skipped\n' "$(date '+%F %T')" "$peer" | tee -a "$log" >&2
        return 1
    fi

    # Alfred bundle by git: iMac → here → iMac, so both end on the same commit.
    _tsync_alfred "$peer" || rc=2
    _tsync_alfred || rc=2
    [ "$rc" -eq 0 ] && _tsync_alfred "$peer" > /dev/null

    [ -f "$db" ] && sqlite3 "$db" 'PRAGMA wal_checkpoint(TRUNCATE);' > /dev/null
    # shellcheck disable=SC2029  # $db expands here on purpose: same path on both Macs
    ssh "$peer" "[ -f '$db' ] && sqlite3 '$db' 'PRAGMA wal_checkpoint(TRUNCATE);'" > /dev/null

    # unison exit codes: 0 all done, 1 some items skipped, 2 non-fatal errors, 3 fatal
    local rc1=0 rc2=0
    unison 42tirana "$@" || rc1=$?
    unison claude "$@" || rc2=$?
    [ "$rc1" -gt "$rc" ] && rc=$rc1
    [ "$rc2" -gt "$rc" ] && rc=$rc2
    return "$rc"
}
