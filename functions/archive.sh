INSTALL_TAG=(MAC)
REQUIRED_TOOLS=()
_check_preamble || return 0

# ─────────────────────────────────────────────────────────────────────────────
# archive — Finder-hide personal scratch/stage folders (_archive _processing
# _trash), split out of `tidy`. NOTE: chflags hidden is a FINDER-ONLY hide —
# it sets the UF_HIDDEN inode flag, which Dropbox web + mobile ignore. To hide
# something in Dropbox's own UI you'd need the com.dropbox.ignored xattr (which
# also stops it syncing), not this.
#
#   archive            hide any newly-appeared scratch folders
#   archive --dry-run  (or -n) preview, hide nothing
#   archive --deep     force a real fd traversal instead of Spotlight
#
# Why two scanners:
#   • mdfind (Spotlight) — index lookup: instant, unlimited depth, and never
#     walks ~/Library/CloudStorage, so the Dropbox FileProvider can't stall it
#     (the old depth-capped `find` hung there for minutes AND missed folders
#     below its depth caps). Trade-off: trusts the index — misses anything
#     Spotlight hasn't (re)indexed.
#   • fd — real traversal with the old roots+depths: no index-staleness risk,
#     but it does touch CloudStorage, so it can be slow on online-only dirs.
#
# Siblings: `tidy` (local disk reclaim) and `upgrade` (brew update/upgrade).
# UI helpers come from functions/_ui.sh.
# ─────────────────────────────────────────────────────────────────────────────
archive() {
    local dry_run=false deep=false arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run | -n) dry_run=true ;;
            --deep) deep=true ;;
        esac
    done

    # Folder names to hide. Kept explicit rather than a '_*' glob so it never
    # catches _-prefixed SOURCE dirs like Jekyll's _posts/_sass or __pycache__.
    local hide_patterns=(_archive _processing _trash)

    # ── Scanner A: Spotlight index lookup (instant, whole $HOME, any depth) ──
    _scan_mdfind() {
        local q="" p
        for p in "${hide_patterns[@]}"; do
            q+="${q:+ || }kMDItemFSName == \"$p\""
        done
        mdfind -onlyin "$HOME" "$q" 2> /dev/null
    }

    # ── Scanner B: fd traversal over the old roots+depths ────────────────────
    # root:maxdepth — depth counts from that root. The macOS Dropbox path
    # (~/Library/CloudStorage/Dropbox) already eats 3 levels from $HOME, so it
    # gets its own deeper root while $HOME stays shallow.
    # fd skips hidden (dot) dirs by default; --no-ignore because _archive dirs
    # are often gitignored and must still be found.
    _scan_fd() {
        local spec root depth
        for spec in "$HOME:3" "$HOME/Library/CloudStorage/Dropbox:6" "$HOME/Documents/dev:5"; do
            root="${spec%:*}" depth="${spec##*:}"
            [[ -d "$root" ]] || continue
            fd --no-ignore -t d -d "$depth" \
                --exclude node_modules --exclude '__*' --exclude venv \
                --exclude target --exclude build --exclude dist \
                --exclude Caches --exclude Library \
                '^(_archive|_processing|_trash)$' "$root" 2> /dev/null
        done
    }

    # ── Candidate selection: which scanner to trust, and what to filter out ──
    # Emits one absolute folder path per line on stdout.
    #
    # Policy: Spotlight unless it's unusable (mdfind missing, indexing disabled)
    # or --deep forces a real traversal; --deep without fd is an error (the
    # whole point was a non-index scan). Both scanners get the same heavy-tree
    # path filter — redundant for fd (its --exclude already prunes) but one
    # grep on ~20 lines buys a single place where the guarantee lives.
    _scan_candidates() {
        local scan=_scan_mdfind
        if $deep || ! command -v mdfind > /dev/null || mdutil -s / 2> /dev/null | grep -qi disabled; then
            if command -v fd > /dev/null; then
                scan=_scan_fd
            elif $deep; then
                printf 'archive: --deep needs fd (not installed)\n' >&2
                return 1
            else
                printf 'archive: fd not installed — trying Spotlight anyway\n' >&2
            fi
        fi
        $scan | grep -vE '/(node_modules|__[^/]*|venv|target|build|dist|Caches)/'
    }

    _header "Hiding special folders"

    local -A seen # dedupe (fd roots can overlap: ~/Documents/dev is under $HOME)
    local hidden_count=0 flags folder
    while IFS= read -r folder; do
        [[ -n "$folder" && -d "$folder" ]] || continue
        [[ -n "${seen[$folder]}" ]] && continue
        seen[$folder]=1
        # %Xf prints hex with NO 0x prefix — force base-16 or it parses as decimal
        flags=$(stat -f "%Xf" "$folder" 2> /dev/null)
        [[ $((0x${flags:-0} & 0x8000)) -ne 0 ]] && continue # already hidden
        _task "Hiding $(_tilde "$folder")"
        if $dry_run; then
            _item "would hide"
        else
            chflags hidden "$folder" 2> /dev/null && {
                _done "Hidden: $(_tilde "$folder")"
                hidden_count=$((hidden_count + 1))
            }
        fi
    done < <(_scan_candidates)

    [[ $hidden_count -eq 0 ]] && printf '  %bNo new folders to hide%b\n' "$_C_DIM" "$_C_RESET" ||
        printf '  %bHidden %d folders%b\n' "$_C_DIM" "$hidden_count" "$_C_RESET"
}
