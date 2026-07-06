INSTALL_TAG=(MAC)
REQUIRED_TOOLS=(brew)
_check_preamble || return 0

# ─────────────────────────────────────────────────────────────────────────────
# tidy — one-shot macOS maintenance. Reclaims disk from regenerable caches,
# scrubs dead dotfile scatter from $HOME, prunes package stores, garbage-collects
# Nix, and keeps Homebrew current. Absorbs the old `clean` function.
#
#   tidy            run everything
#   tidy --dry-run  (or -n) preview every action + size, delete NOTHING
#
# Safety invariants:
#   • Deletes with /bin/rm, never `rm` (which is aliased to `trash`) — so cache
#     clears actually free space instead of silently refilling the Trash.
#   • $HOME scrubbing is whitelist-only (see _safe_rm): it refuses any symlink
#     into /nix/store (home-manager-managed dotfiles) and only removes an explicit
#     allow-list of regenerable junk. Credential/state dirs (.ssh .gnupg .aws
#     .config .local …) are never candidates.
#   • Cache clears remove directory *contents*, keeping the dir itself — apps
#     expect it to exist and regenerate only what they need.
# ─────────────────────────────────────────────────────────────────────────────
tidy() {
    # $'…' so these are real ESC bytes — they render whether printf uses %b or %s
    local CYAN=$'\033[0;36m' GREEN=$'\033[0;32m' YELLOW=$'\033[0;33m' \
        DIM=$'\033[2m' RESET=$'\033[0m' BOLD=$'\033[1m'

    _header() { printf '\n%b━━━%b %b%s%b\n' "$CYAN" "$RESET" "$BOLD" "$1" "$RESET"; }
    _task() { printf '  %b○%b %s' "$DIM" "$RESET" "$1"; }
    _done() { printf '\r  %b●%b %s\n' "$GREEN" "$RESET" "$1"; }
    _skip() { printf '\r  %b○%b %s %b(skipped)%b\n' "$YELLOW" "$RESET" "$1" "$DIM" "$RESET"; }
    _item() { printf '    %b→%b %s\n' "$DIM" "$RESET" "$1"; }

    local dry_run=false
    [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]] && dry_run=true

    local total_freed=0 # kB, accumulated across cache clears

    # ── Home-audit config (edit as your setup evolves) ────────────────────────
    # Approved top-level $HOME entries. Anything present but NOT listed here is
    # flagged by the "Auditing $HOME" section so new scatter can't hide. Grouped
    # by *why* it's allowed — move borderline entries in once you've decided to
    # keep them; leave them out to keep getting reminded every run.
    local home_approved=(
        # nix / home-manager managed dotfiles + infra
        .bash_profile .bashrc .profile .zshenv .nix-defexpr .nix-profile
        # XDG base dirs
        .cache .config .local
        # macOS standard home
        Applications Desktop Documents Downloads Library Movies Music Pictures Public .Trash
        # hardcoded-path tools (can't be XDG'd — deleting forces re-link/re-setup)
        .ssh .dropbox Dropbox .yarn
        # data we intentionally keep in-place
        .claude .vscode .vscode-shared
        # SwiftPM compat symlinks (0B) → real data lives in ~/Library; auto-regenerated
        .swiftpm
    )

    # Legacy path → the env var that is supposed to relocate it out of $HOME.
    # If the legacy path still exists AND the var is set, that's XDG *drift*:
    # a stale copy the var failed to prevent. Reported (never auto-deleted) so
    # you can confirm each relocation is actually taking effect.
    local -A xdg_relocated=(
        .wakatime   WAKATIME_HOME
        .cargo      CARGO_HOME
        .bundle     BUNDLE_USER_HOME
        .docker     DOCKER_CONFIG
        .npm        NPM_CONFIG_CACHE
        .matplotlib MPLCONFIGDIR
        .gem        GEM_HOME
        .rbenv      RBENV_ROOT
        .android    ANDROID_USER_HOME
        .nuget      NUGET_PACKAGES
        .pkuseg     PKUSEG_HOME
        .rustup     RUSTUP_HOME
    )

    # container free space (bytes) for the end-of-run reclaim report
    _free_bytes() { diskutil info / 2> /dev/null | awk -F'[()]' '/Container Free Space/{gsub(/[^0-9]/,"",$2); print $2}'; }
    local free_before
    free_before=$(_free_bytes)

    # tilde-abbreviate a path for display
    _tilde() { case "$1" in "$HOME"/*) printf '~/%s' "${1#"$HOME"/}" ;; *) printf '%s' "$1" ;; esac; }

    # Remove one regenerable $HOME entry (file or dir). Refuses nix-store symlinks.
    _safe_rm() {
        local p="$1"
        [[ -e "$p" || -L "$p" ]] || return 0
        if [[ -L "$p" ]] && readlink "$p" | grep -q '/nix/store'; then
            _item "skip $(_tilde "$p") (home-manager symlink)"
            return 0
        fi
        if $dry_run; then
            _item "would remove $(_tilde "$p")"
        else
            /bin/rm -rf "$p" 2> /dev/null && _item "removed $(_tilde "$p")"
        fi
        removed=$((removed + 1))
    }

    # Clear the CONTENTS of a cache dir (keep the dir), with size accounting.
    _clear_contents() {
        local dir="$1"
        [[ -d "$dir" ]] || return 0
        local kb
        kb=$(du -sk "$dir" 2> /dev/null | cut -f1)
        total_freed=$((total_freed + kb))
        _task "$(_tilde "$dir")"
        if $dry_run; then
            _item "would free ~$((kb / 1024))MB"
        else
            /bin/rm -rf "${dir:?}"/* 2> /dev/null
            _done "$(_tilde "$dir") (${DIM}~$((kb / 1024))MB${RESET})"
        fi
    }

    # ─────────────────────────────────────────────────────────────────────────
    # 1. Scrub $HOME — dead dotfile scatter (absorbed from the old `clean`)
    # ─────────────────────────────────────────────────────────────────────────
    _header "Scrubbing \$HOME"

    # Regenerable caches/artifacts that keep reappearing in $HOME despite XDG.
    # (.docker is safe here because DOCKER_CONFIG points at $XDG_CONFIG_HOME/docker,
    #  so this is a redundant copy, not your registry auth.)
    local home_junk=(
        "$HOME/.npm" "$HOME/.matplotlib" "$HOME/.node-gyp"
        "$HOME/.aspnet" "$HOME/.dotnet" "$HOME/.nuget" "$HOME/.templateengine"
        "$HOME/.docker" "$HOME/.lesshst"
        "$HOME/.DS_Store" "$HOME/.claude.json.backup"
    )
    local removed=0 p name
    for p in "${home_junk[@]}"; do _safe_rm "$p"; done
    # host/version-suffixed zsh compdumps ((N) = expand to nothing if absent)
    for p in "$HOME"/.zcompdump*(N); do _safe_rm "$p"; done

    # Empty dead dirs from tools you don't use — removed ONLY while still empty,
    # so if you ever start using one, its data is automatically spared.
    for name in .ansible .bun .yarn .pdf-filler-profiles .pdf-toolkit-files; do
        p="$HOME/$name"
        [[ -d "$p" && -z "$(ls -A "$p" 2> /dev/null)" ]] && _safe_rm "$p"
    done
    [[ $removed -eq 0 ]] && printf '  %bnothing to scrub%b\n' "$DIM" "$RESET"

    # ─────────────────────────────────────────────────────────────────────────
    # 2. Clear caches (contents only; every entry regenerates on demand)
    # ─────────────────────────────────────────────────────────────────────────
    _header "Clearing caches"

    local dir
    local cache_dirs=(
        "$HOME/Library/Caches"                              # app caches: Spotify, Brave, Homebrew…
        "$HOME/.cache"                                      # XDG caches: npm, pnpm, nix, typescript
        "$HOME/Library/Application Support/Caches"          # shared app cache bucket
        "$HOME/Library/Application Support/Code/CachedData" # VS Code compiled-code cache
    )
    for dir in "${cache_dirs[@]}"; do _clear_contents "$dir"; done

    # ─────────────────────────────────────────────────────────────────────────
    # 3. Xcode / iOS simulator caches — the big reclaimers
    #    DeviceSupport = per-iOS-VERSION debug symbols. Deleting them costs a
    #    ONE-TIME ~1–3 min re-extract the next time you connect a device running
    #    a given iOS version — NOT every plug-in, and only for versions you
    #    actually connect again. DerivedData rebuilds. Archives are left alone.
    # ─────────────────────────────────────────────────────────────────────────
    _header "Clearing Xcode caches"

    local xcode_dirs=(
        "$HOME/Library/Developer/Xcode/DerivedData"
        "$HOME/Library/Developer/Xcode/iOS DeviceSupport"
        "$HOME/Library/Developer/Xcode/watchOS DeviceSupport"
        "$HOME/Library/Developer/Xcode/tvOS DeviceSupport"
    )
    for dir in "${xcode_dirs[@]}"; do _clear_contents "$dir"; done

    # Delete only simulators whose runtime is no longer installed (orphans);
    # your active/usable simulators are kept.
    if command -v xcrun > /dev/null 2>&1; then
        _task "Removing unavailable simulators"
        if $dry_run; then
            _item "would run: xcrun simctl delete unavailable"
        else
            xcrun simctl delete unavailable > /dev/null 2>&1 && _done "Unavailable simulators removed"
        fi
    fi

    if $dry_run; then
        printf '  %bWould free: ~%dMB%b\n' "$DIM" "$((total_freed / 1024))" "$RESET"
    else
        printf '  %bTotal freed: ~%dMB%b\n' "$DIM" "$((total_freed / 1024))" "$RESET"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # 4. Prune package-manager stores (safe: only unreferenced content removed)
    # ─────────────────────────────────────────────────────────────────────────
    _header "Pruning package stores"

    if command -v pnpm > /dev/null 2>&1; then
        _task "pnpm store prune"
        if $dry_run; then
            _item "would run: pnpm store prune"
        else
            pnpm store prune > /dev/null 2>&1 && _done "pnpm store pruned"
        fi
    else
        _skip "pnpm not installed"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # 5. Hide special folders in user spaces
    # ─────────────────────────────────────────────────────────────────────────
    _header "Hiding special folders"

    local hide_patterns=("_archive" "_processing" "_old" "_backup" "_temp" "_wip")
    local hidden_count=0 flags pattern folder
    for pattern in "${hide_patterns[@]}"; do
        while IFS= read -r -d '' folder; do
            flags=$(stat -f "%Xf" "$folder" 2> /dev/null)
            if [[ $((flags & 0x8000)) -eq 0 ]]; then
                _task "Hiding $folder"
                if $dry_run; then
                    _item "would hide"
                else
                    chflags hidden "$folder" 2> /dev/null && {
                        _done "Hidden: $folder"
                        hidden_count=$((hidden_count + 1))
                    }
                fi
            fi
        done < <(find "$HOME" -maxdepth 4 -type d -name "$pattern" -print0 2> /dev/null)
    done
    [[ $hidden_count -eq 0 ]] && printf '  %bNo new folders to hide%b\n' "$DIM" "$RESET" \
        || printf '  %bHidden %d folders%b\n' "$DIM" "$hidden_count" "$RESET"

    # ─────────────────────────────────────────────────────────────────────────
    # 6. Homebrew — update, upgrade, cleanup, drop unused deps
    # ─────────────────────────────────────────────────────────────────────────
    _header "Updating Homebrew"

    if $dry_run; then
        _item "would run: brew update && brew upgrade && brew cleanup && brew autoremove"
    else
        _task "Updating formulae..."
        brew update --quiet && _done "Formulae updated"

        _task "Upgrading packages..."
        local outdated
        outdated=$(brew outdated --quiet)
        if [[ -n "$outdated" ]]; then
            brew upgrade --quiet
            _done "Packages upgraded"
            printf '  %bUpgraded:%b\n' "$DIM" "$RESET"
            echo "$outdated" | while read -r pkg; do
                _item "$pkg"
            done
        else
            _skip "All packages up to date"
        fi

        _task "Cleaning up..."
        brew cleanup --quiet && _done "Cleanup complete"

        _task "Removing unused dependencies..."
        brew autoremove --quiet && _done "Autoremove complete"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # 7. Nix garbage collection — drop generations older than 7 days.
    #    User + home-manager profiles only (no sudo); these are what `re` creates.
    #    The root-owned nix-darwin system profile is GC'd via nix.gc in darwin.nix.
    # ─────────────────────────────────────────────────────────────────────────
    _header "Nix garbage collection"

    if ! command -v nix-collect-garbage > /dev/null 2>&1; then
        _skip "nix not installed"
    elif $dry_run; then
        _task "Scanning generations (dry run)..."
        local ngc_preview
        ngc_preview=$(nix-collect-garbage --delete-older-than 7d --dry-run 2>&1 | grep -iE "would|delete" | tail -1)
        _done "Nix GC"
        _item "${ngc_preview:-would delete generations older than 7d}"
    else
        _task "Deleting generations older than 7d..."
        local ngc_freed
        ngc_freed=$(nix-collect-garbage --delete-older-than 7d 2>&1 | grep -iE "freed" | tail -1)
        _done "Nix GC (${DIM}${ngc_freed:-done}${RESET})"
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # 8. Audit $HOME — report-only. Two checks:
    #    (a) XDG drift  — a relocated tool left a legacy copy behind ($var set
    #        but the old ~/.foo still exists → the relocation isn't winning).
    #    (b) Unlisted   — a top-level entry absent from home_approved above.
    #    Nothing is deleted here; this is the "is my $HOME still correct?" report.
    # ─────────────────────────────────────────────────────────────────────────
    _header "Auditing \$HOME"

    # (a) XDG drift — legacy path present despite its relocation var being set.
    local drift=0 var val
    for name in "${(@k)xdg_relocated}"; do # @k: each key stays a separate word
        var="${xdg_relocated[$name]}"
        val="${(P)var}" # indirect: value of the env var *named* $var
        if [[ -e "$HOME/$name" && -n "$val" ]]; then
            printf '  %b⚠%b %s exists but %b$%s%b→%s %b(stale copy — safe to remove)%b\n' \
                "$YELLOW" "$RESET" "$name" "$BOLD" "$var" "$RESET" "$(_tilde "$val")" "$DIM" "$RESET"
            drift=$((drift + 1))
        fi
    done
    [[ $drift -eq 0 ]] && printf '  %b✓ no XDG drift — every relocated tool stays out of $HOME%b\n' "$DIM" "$RESET"

    # (b) Unlisted entries — present in $HOME but not on the approved list.
    #     (drift entries already reported above are skipped to avoid double-listing)
    local -A approved_set
    for name in "${home_approved[@]}"; do approved_set[$name]=1; done
    local unlisted=0 e
    for e in "$HOME"/.*(N) "$HOME"/*(N); do
        name="${e:t}" # zsh basename
        [[ "$name" == "." || "$name" == ".." ]] && continue
        [[ -n "${approved_set[$name]}" || -n "${xdg_relocated[$name]}" ]] && continue
        printf '  %b?%b %s %b(unlisted — review, then approve or clean)%b\n' \
            "$CYAN" "$RESET" "$name" "$DIM" "$RESET"
        unlisted=$((unlisted + 1))
    done
    [[ $unlisted -eq 0 ]] && printf '  %b✓ every top-level entry is on the approved list%b\n' "$DIM" "$RESET"

    # ─────────────────────────────────────────────────────────────────────────
    if ! $dry_run; then
        local free_after delta
        free_after=$(_free_bytes)
        delta=$((free_after - free_before))
        printf '  %b♻%b Reclaimed %s GB — now %s GB free\n' "$GREEN" "$RESET" \
            "$(awk -v d="$delta" 'BEGIN{printf "%.1f", d/1e9}')" \
            "$(awk -v f="$free_after" 'BEGIN{printf "%.1f", f/1e9}')"
    fi
    printf '\n%b✓%b %bTidy complete%b\n\n' "$GREEN" "$RESET" "$BOLD" "$RESET"
}
