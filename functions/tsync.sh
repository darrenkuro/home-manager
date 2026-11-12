INSTALL_TAG=(MAC)
INSTALL_PROFILE=(PERSONAL)
REQUIRED_TOOLS=(unison sqlite3 ssh)
_check_preamble || return 0

# tsync [unison options…]
# Two-way sync with the work iMac: ~/Documents/42tirana and the Claude session
# state (profiles 42tirana + claude in ~/.config/unison, modules/apps/unison.nix).
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
tsync() {
    local peer=work
    local db="${TIRANA_ROOT:-$HOME/Documents/42tirana}/resources/data/42tirana.sqlite"
    local log="$HOME/Library/Logs/unison.log"
    local rc=0

    if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$peer" true 2> /dev/null; then
        printf '%s tsync: %s unreachable, skipped\n' "$(date '+%F %T')" "$peer" | tee -a "$log" >&2
        return 1
    fi

    [ -f "$db" ] && sqlite3 "$db" 'PRAGMA wal_checkpoint(TRUNCATE);' > /dev/null
    # shellcheck disable=SC2029  # $db expands here on purpose: same path on both Macs
    ssh "$peer" "[ -f '$db' ] && sqlite3 '$db' 'PRAGMA wal_checkpoint(TRUNCATE);'" > /dev/null

    # unison exit codes: 0 all done, 1 some items skipped, 2 non-fatal errors, 3 fatal
    local rc2=0
    unison 42tirana "$@" || rc=$?
    unison claude "$@" || rc2=$?
    [ "$rc2" -gt "$rc" ] && rc=$rc2
    return "$rc"
}
