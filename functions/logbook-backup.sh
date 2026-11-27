INSTALL_TAG=(MAC)
INSTALL_PROFILE=(PERSONAL)
REQUIRED_TOOLS=(sqlite3 tar)
_check_preamble || return 0

# ─────────────────────────────────────────────────────────────────────────────
# logbook-backup — a consistent copy of Logbook's database plus its files to
# Dropbox. Run by hand, or through `backup` with the others; nothing is scheduled.
#
#   logbook-backup            .backup the db, tar files/ + sources/, keep the
#                             latest 2 of each in Dropbox
#   logbook-backup --dry-run  (or -n) show what would be copied
#
# Why `.backup` and not cp: the db runs in WAL mode, so a copied file can miss
# committed pages still in logbook.db-wal; SQLite's online backup is consistent
# while Logbook is open. Data dir: $LOGBOOK_DATA, else $XDG_DATA_HOME/logbook
# (setup-cleanup Area G), else the old in-checkout $DEV/logbook/data.
# Ad-hoc pre-migration snapshots stay at the _backup/claude root (another kind).
# ─────────────────────────────────────────────────────────────────────────────
logbook-backup() {
    local dry_run=false arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run | -n) dry_run=true ;;
            *) echo "usage: logbook-backup [--dry-run]" >&2; return 2 ;;
        esac
    done
    local src="${LOGBOOK_DATA:-${XDG_DATA_HOME:-$HOME/.local/share}/logbook}"
    [ -f "$src/logbook.db" ] || src="${DEV:-$HOME/Documents/dev}/logbook/data"
    if [ ! -f "$src/logbook.db" ]; then
        echo "logbook-backup: no logbook.db in \$LOGBOOK_DATA, ~/.local/share/logbook or \$DEV/logbook/data" >&2
        return 1
    fi
    local dst="$HOME/Library/CloudStorage/Dropbox/_backup/claude/logbook"
    local day dirs=() d
    day=$(date +%F)
    for d in files sources; do [ -d "$src/$d" ] && dirs+=("$d"); done
    echo "db     : $src/logbook.db ($(du -h "$src/logbook.db" | cut -f1)) → $dst/logbook-$day.db"
    echo "files  : ${dirs[*]:-none} → $dst/logbook-files-$day.tgz"
    if $dry_run; then
        echo "(dry run, nothing copied)"
        return 0
    fi
    mkdir -p "$dst"
    # write beside the target, then rename: Dropbox never uploads a half-written file
    sqlite3 "$src/logbook.db" ".backup '$dst/.logbook-$day.db.partial'" || return 1
    # the copy inherits WAL mode, and opening it would leave -wal/-shm files beside it: one self-contained file instead
    sqlite3 "$dst/.logbook-$day.db.partial" 'pragma journal_mode = delete' > /dev/null || return 1
    /bin/rm -f "$dst/.logbook-$day.db.partial-wal" "$dst/.logbook-$day.db.partial-shm" # empty once out of WAL mode
    if [ "$(sqlite3 "$dst/.logbook-$day.db.partial" 'pragma quick_check')" != "ok" ]; then
        echo "logbook-backup: the copy failed quick_check; kept as $dst/.logbook-$day.db.partial" >&2
        return 1
    fi
    mv -f "$dst/.logbook-$day.db.partial" "$dst/logbook-$day.db"
    if [ ${#dirs[@]} -gt 0 ]; then
        tar -czf "$dst/.logbook-files-$day.tgz.partial" -C "$src" "${dirs[@]}" || return 1
        mv -f "$dst/.logbook-files-$day.tgz.partial" "$dst/logbook-files-$day.tgz"
    fi
    # keep the latest 2 of each kind (retention D2 of the setup cleanup); /bin/rm, as rm is aliased to trash
    local old
    {
        command ls -t "$dst"/logbook-[0-9]*.db 2>/dev/null | tail -n +3
        [ ${#dirs[@]} -gt 0 ] && command ls -t "$dst"/logbook-files-*.tgz 2>/dev/null | tail -n +3
    } | while IFS= read -r old; do
        /bin/rm -f "$old"
        echo "pruned : ${old##*/}"
    done
    echo "done   : $(du -h "$dst/logbook-$day.db" | cut -f1) db$([ ${#dirs[@]} -gt 0 ] && echo ", $(du -h "$dst/logbook-files-$day.tgz" | cut -f1) files")"
}
