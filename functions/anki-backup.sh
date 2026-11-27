INSTALL_TAG=(MAC)
INSTALL_PROFILE=(PERSONAL)
REQUIRED_TOOLS=(rsync)
_check_preamble || return 0

# ─────────────────────────────────────────────────────────────────────────────
# anki-backup — copy Anki's own newest collection backup and the media folder to
# Dropbox. Run by hand (a recurring task reminds); nothing is scheduled.
#
#   anki-backup            copy the newest backups/*.colpkg (keep the latest 2
#                          in Dropbox) and rsync collection.media/
#   anki-backup --dry-run  (or -n) show what would be copied
#
# Why this and not an export: Anki writes backups/*.colpkg whole, every 30 min
# while open and on close, so copying one is safe while Anki runs; AnkiConnect's
# exportPackage forces a one-way AnkiWeb sync. The automatic backups carry no
# media, hence the rsync. The live collection.anki2 is never touched.
# Restore: `anki-restore`. Design: tasks/2026-11-anki-setup (architecture-anki-setup.md).
# ─────────────────────────────────────────────────────────────────────────────
anki-backup() {
    local dry_run=false arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run | -n) dry_run=true ;;
            *) echo "usage: anki-backup [--dry-run]" >&2; return 2 ;;
        esac
    done
    local src="$HOME/Library/Application Support/Anki2/Darren Kuro"
    local dst="$HOME/Library/CloudStorage/Dropbox/_backup/claude/anki"
    local newest
    newest=$(ls -t "$src"/backups/backup-*.colpkg 2>/dev/null | head -1)
    if [ -z "$newest" ]; then
        echo "anki-backup: no backups/*.colpkg in $src" >&2
        return 1
    fi
    echo "backup : ${newest##*/} ($(du -h "$newest" | cut -f1)) → $dst/"
    echo "media  : $src/collection.media/ → $dst/collection.media/ (rsync --delete)"
    if $dry_run; then
        echo "(dry run, nothing copied)"
        return 0
    fi
    mkdir -p "$dst"
    cp -p "$newest" "$dst/"
    # keep the latest 2 copies in Dropbox (retention D2 of the setup cleanup)
    ls -t "$dst"/backup-*.colpkg 2>/dev/null | tail -n +3 | while IFS= read -r old; do
        rm -f "$old"
        echo "pruned : ${old##*/}"
    done
    rsync -a --delete "$src/collection.media/" "$dst/collection.media/"
    echo "done   : $(ls "$dst"/backup-*.colpkg | wc -l | tr -d ' ') backups, $(du -sh "$dst/collection.media" | cut -f1) media"
}
