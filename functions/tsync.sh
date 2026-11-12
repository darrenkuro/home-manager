INSTALL_TAG=(MAC)
INSTALL_PROFILE=(PERSONAL)
REQUIRED_TOOLS=(unison sqlite3 ssh)
_check_preamble || return 0

# tsync [-claude] [unison options…]
# Two-way sync with the work iMac: ~/Documents/42tirana (Unison profile
# 42tirana in ~/.config/unison, modules/apps/unison.nix), plus, with -claude,
# the Claude session state (profile claude: projects/ incl. memory, plans,
# todos), plus the Alfred prefs bundle, which is a git repo (modules/apps/alfred.nix)
# and goes by git, not Unison: each side commits what Alfred wrote, pulls with
# rebase and pushes — iMac first over ssh, then here, then the iMac catches up.
# Each Mac only rewrites its own preferences/local/<hash>/, so that never
# conflicts; a conflict on a shared file (a workflow edited on both) is left
# for you with a warning and the Unison part still runs.
# Interactive by default (-auto): non-conflicting changes are listed and go
# through on one confirmation, conflicts (changed on both sides) are asked one
# by one — left column is this Mac, right the iMac; `?` lists the keys.
# `tsync -batch` propagates the non-conflicting changes unattended and leaves the
# conflicts for the next plain run. Run it before switching Macs and after a long
# session; keep one writer between syncs for the hub DB and bocal/.git.
# Before Unison, on both Macs, it stops (nothing synced) if anything holds a
# file Unison could replace (_tsync_busy_script) or if the hub DB fails
# quick_check; it checks the DB again afterwards. Skips with a log line when
# the iMac is not reachable.
#
# Examples:
#   tsync             # review and confirm
#   tsync -claude     # also the Claude session state
#   tsync -batch      # unattended, conflicts skipped
#   tsync -batch -silent
#
# Output: Unison runs -terse, its change list and prompts reach the terminal
# untouched (stdout); its stderr (one [BGN]/[END]/Shortcut line per file, the
# summary) goes through _tsync_summary, which keeps one line per profile plus
# the skipped/failed items. The full detail stays in the log.

_tsync_warn() { printf '  %b▲%b %s\n' "$_C_YELLOW" "$_C_RESET" "$1"; }

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
    if [ "$rc" -ne 0 ]; then
        _tsync_warn "alfred ($label): $out"
    elif [ "$out" = "committed 0, pulled 0, pushed 0" ]; then
        _done "alfred ($label): in sync"
    else
        _done "alfred ($label): $out"
    fi
    return "$rc"
}

# Unison's stderr → one summary line, the skipped/failed items, and any error
# text; the per-file [BGN]/[END]/Shortcut lines, the conflict notes (repeated in
# the skipped list) and, with -batch, a second copy of the change list (9-char
# status column, 5-char arrow) are dropped. Nothing at all means nothing changed.
# $1 = 1 when Unison asks "Proceed?": the answer leaves no newline, so the
# first line printed starts with one.
_tsync_summary() {
    awk -v nl="${1:-0}" -v g="$_C_GREEN" -v y="$_C_YELLOW" -v d="$_C_DIM" -v r="$_C_RESET" '
        function out(s) { if (nl) { printf "\n"; nl = 0 } print s }
        /^\[(BGN|END)\] |^Shortcut: |^No updates to propagate/ { next }
        /^.........[<>=?M-][<>=?M-][<>=?M-][<>=?M-][<>=?M-] / { next }
        /^\[CONFLICT\] / { conflict = 1; next }
        conflict && /^  / { next }
        { conflict = 0 }
        /^Synchronization (complete|incomplete) / {
            seen = 1
            n = $0; sub(/.*\(/, "", n); sub(/\).*/, "", n)    # "7 items transferred, 0 skipped, 0 failed"
            split(n, f, ", "); t = f[1] + 0; s = f[2] + 0; x = f[3] + 0
            line = t " synced"
            if (s) line = line ", " s " skipped"
            if (x) line = line ", " x " failed"
            out(sprintf("  %s%s %s", ((s || x) ? y "▲" : g "●"), r, line))
            next
        }
        /^  (skipped|failed): / { sub(/^  /, ""); out(sprintf("    %s→%s %s", d, r, $0)); next }
        NF { seen = 1; out($0) }
        END { if (!seen) out(sprintf("  %s●%s up to date", g, r)) }
    '
}

# _tsync_run <profile> [unison options…] — one Unison profile, -auto -terse,
# stderr through _tsync_summary; returns Unison's exit code.
_tsync_run() {
    local name="$1" urc ask=0
    shift
    [ -t 0 ] && case " $* " in *" -batch "* | *" -silent "*) ;; *) ask=1 ;; esac
    _header "$name"
    printf '  %bscanning both Macs…%b\n' "$_C_DIM" "$_C_RESET"
    # fd 3 keeps stdout on the terminal while stderr alone goes down the pipe.
    # The ( ) matters in zsh: with MULTIOS, `cmd 1>&3 | …` would tee stdout
    # into the pipe as well.
    # shellcheck disable=SC2154  # pipestatus is zsh's PIPESTATUS (1-based)
    {
        (unison "$name" -auto -terse "$@" 2>&1 1>&3 3>&-) | _tsync_summary "$ask"
        urc=${pipestatus[1]:-${PIPESTATUS[0]}}
    } 3>&1
    return "$urc"
}

# _tsync_busy_script — a sh script (arg: 1 with -claude) that prints one line
# per process that could be writing into what Unison is about to replace, on
# the Mac it runs on; nothing means safe. Unison renames a new file over the
# old one, so a process holding the old one keeps writing to a ghost, and an
# SQLite connection keeps a -shm index that no longer matches the file (how
# the hub DB got corrupted on 2026-11-12). Flags any SQLite file open in any
# mode, and any file open for writing, under ~/Documents/42tirana (minus what
# the profile ignores); with -claude, any running Claude Code, since it
# appends to its transcripts without holding them open.
_tsync_busy_script() {
    cat << 'EOF'
root="$HOME/Documents/42tirana/"
lsof -nP -w -F pcan 2> /dev/null | awk -v root="$root" -v home="$HOME/" '
    /^p/ { pid = substr($0, 2) }
    /^c/ { cmd = substr($0, 2) }
    /^f/ { mode = "" }
    /^a/ { mode = substr($0, 2) }
    /^n/ {
        p = substr($0, 2)
        if (index(p, root) != 1 || index(p, root "tmp/") == 1 || p ~ /\/(node_modules|\.next|\.venv)\//) next
        if (mode !~ /[wu]/ && p !~ /\.(sqlite|db)(-wal|-shm|-journal)?$/) next
        if (pid in seen) next
        seen[pid] = 1
        print cmd " (pid " pid ") has ~/" substr(p, length(home) + 1) " open"
    }'
[ "$1" = 1 ] && ps -axo pid=,comm= | awk '{ n = $2; sub(/.*\//, "", n) } n == "claude" { print "Claude Code (pid " $1 ") is running" }'
exit 0
EOF
}

# _tsync_db_ok [host] — checkpoint the hub DB's WAL (so the .sqlite file alone
# is complete) and quick_check it, here or on <host>. True when fine or absent.
_tsync_db_ok() {
    local db="${TIRANA_ROOT:-$HOME/Documents/42tirana}/resources/data/42tirana.sqlite"
    local check="[ ! -f '$db' ] || { sqlite3 '$db' 'PRAGMA wal_checkpoint(TRUNCATE);' > /dev/null && [ \"\$(sqlite3 -readonly '$db' 'PRAGMA quick_check;')\" = ok ]; }"
    # shellcheck disable=SC2029  # $check expands here on purpose: same path on both Macs
    if [ -n "${1:-}" ]; then ssh "$1" "$check"; else sh -c "$check"; fi 2> /dev/null
}

tsync() {
    local peer=work
    local log="$HOME/Library/Logs/unison.log"
    local rc=0 claude=0 arg
    local -a opts=()
    for arg in "$@"; do
        if [ "$arg" = -claude ]; then claude=1; else opts+=("$arg"); fi
    done

    if ! ssh -o BatchMode=yes -o ConnectTimeout=10 "$peer" true 2> /dev/null; then
        printf '%s tsync: %s unreachable, skipped\n' "$(date '+%F %T')" "$peer" >> "$log"
        _tsync_warn "$peer unreachable, nothing synced"
        return 1
    fi

    _header "tsync ⇄ $peer"

    # Alfred bundle by git: iMac → here → iMac, so both end on the same commit.
    _tsync_alfred "$peer" || rc=2
    _tsync_alfred || rc=2
    [ "$rc" -eq 0 ] && _tsync_alfred "$peer" > /dev/null

    # Nothing may hold what Unison replaces, on either Mac.
    local busy line
    busy=$(
        _tsync_busy_script | sh -s -- "$claude" | sed 's/^/laptop: /'
        _tsync_busy_script | ssh -o BatchMode=yes "$peer" sh -s -- "$claude" | sed "s/^/$peer: /"
    )
    if [ -n "$busy" ]; then
        _tsync_warn "in use, nothing synced — close these, then rerun:"
        while IFS= read -r line; do _item "$line"; done <<< "$busy"
        return 3
    fi
    _done "nothing open in the synced folders"

    # A corrupt DB would be propagated like any other change.
    if ! _tsync_db_ok; then
        _tsync_warn "hub DB fails quick_check here (laptop), nothing synced"
        return 3
    fi
    if ! _tsync_db_ok "$peer"; then
        _tsync_warn "hub DB fails quick_check on $peer, nothing synced"
        return 3
    fi
    _done "hub DB checked on both Macs"

    # -auto: one-sided changes (new, edited, deleted) go without a per-item
    # prompt; only conflicts are asked, then one "Proceed?" for the lot.
    # unison exit codes: 0 all done, 1 some items skipped, 2 non-fatal errors, 3 fatal
    local rc1=0 rc2=0
    _tsync_run 42tirana "${opts[@]}" || rc1=$?
    # Should never fire after the checks above; the replaced copy is in the backup.
    if ! _tsync_db_ok || ! _tsync_db_ok "$peer"; then
        _tsync_warn "hub DB fails quick_check after the sync — the previous copy is in ~/.local/state/unison/backup"
        rc1=3
    fi
    [ "$claude" -eq 1 ] && { _tsync_run claude "${opts[@]}" || rc2=$?; }
    [ "$rc1" -gt "$rc" ] && rc=$rc1
    [ "$rc2" -gt "$rc" ] && rc=$rc2
    return "$rc"
}
