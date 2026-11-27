INSTALL_TAG=(MAC)
INSTALL_PROFILE=(PERSONAL)
REQUIRED_TOOLS=(rsync unzip)
_check_preamble || return 0

# ─────────────────────────────────────────────────────────────────────────────
# anki-restore — overwrite the Anki collection file with a backup and copy the
# media back. For the case where AnkiWeb has bad data too; when only the Mac's
# copy is broken, "Download from AnkiWeb" in Anki is simpler and newer.
#
#   anki-restore [backup.colpkg]        show the plan (default: newest backup in
#                                       Dropbox or Anki's backups/)
#   anki-restore [backup.colpkg] --go   quit Anki, back the profile up, restore
#
# Everything but media lives in collection.anki2 (notes, cards, revlog, note
# types with templates and CSS, deck presets). A .colpkg is a zip whose
# collection.anki21b is that SQLite file, zstd-compressed. Anki's automatic
# backups carry no media: the Dropbox mirror from `anki-backup` supplies it.
# After the restore Anki asks for a sync direction: Upload (this Mac wins) when
# AnkiWeb was the broken side, Download otherwise; then sync the phone.
# Design: tasks/2026-11-anki-setup (architecture-anki-setup.md).
# ─────────────────────────────────────────────────────────────────────────────
anki-restore() {
    local go=false file="" arg
    for arg in "$@"; do
        case "$arg" in
            --go) go=true ;;
            -*) echo "usage: anki-restore [backup.colpkg] [--go]" >&2; return 2 ;;
            *) file="$arg" ;;
        esac
    done
    local profile="$HOME/Library/Application Support/Anki2/Darren Kuro"
    local mirror="$HOME/Library/CloudStorage/Dropbox/_backup/claude/anki"
    local stamp
    stamp=$(date +%Y-%m-%d-%H%M)
    local safety="$HOME/Library/CloudStorage/Dropbox/_backup/claude/anki-prerestore-$stamp"
    if [ -z "$file" ]; then
        file=$(ls -t "$mirror"/backup-*.colpkg "$profile"/backups/backup-*.colpkg 2>/dev/null | head -1)
    fi
    if [ ! -f "$file" ]; then
        echo "anki-restore: no backup found ($file)" >&2
        return 1
    fi
    local zstd_cmd="zstd"
    command -v zstd >/dev/null 2>&1 || zstd_cmd="nix run nixpkgs#zstd --"
    echo "restore : ${file##*/}"
    echo "into    : $profile/collection.anki2 (current files moved to $safety/)"
    echo "media   : $mirror/collection.media/ → $profile/collection.media/ (no deletes)"
    echo "then    : open Anki, sync, choose the direction (Upload if AnkiWeb was the broken side)"
    if ! $go; then
        echo "(plan only; add --go)"
        return 0
    fi
    if pgrep -x Anki >/dev/null; then
        echo "quitting Anki…"
        osascript -e 'quit app "Anki"'
        local i=0
        while pgrep -x Anki >/dev/null; do
            sleep 1
            i=$((i + 1))
            if [ "$i" -ge 30 ]; then
                echo "anki-restore: Anki did not quit" >&2
                return 1
            fi
        done
    fi
    mkdir -p "$safety"
    local f
    for f in collection.anki2 collection.anki2-wal collection.anki2-shm collection.media.db2; do
        [ -e "$profile/$f" ] && mv "$profile/$f" "$safety/"
    done
    # shellcheck disable=SC2086  # zstd_cmd may be several words (nix run …)
    unzip -p "$file" collection.anki21b | $zstd_cmd -d -q -o "$profile/collection.anki2" || {
        echo "anki-restore: decompression failed; the old files are in $safety" >&2
        return 1
    }
    if [ -d "$mirror/collection.media" ]; then
        rsync -a "$mirror/collection.media/" "$profile/collection.media/"
    fi
    echo "restored: $(du -h "$profile/collection.anki2" | cut -f1) collection; old files in $safety"
    echo "next    : open -a Anki → sync → pick the direction → sync the phone"
}
