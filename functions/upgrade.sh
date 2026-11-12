INSTALL_TAG=(MAC)
REQUIRED_TOOLS=(brew git)
_check_preamble || return 0

# ─────────────────────────────────────────────────────────────────────────────
# upgrade — the network half split out of `tidy`: brew update + upgrade, a
# fast-forward pull of the Alfred prefs repo, plus a report-only Nix inputs
# reminder. Never mutates the hm repo (nix flake update changes flake.lock,
# which needs a commit — that stays manual).
#
#   upgrade            update + upgrade everything
#   upgrade --dry-run  (or -n) show what would be upgraded, change nothing
#
# Siblings: `tidy` (local disk reclaim — run it after to drop the old kegs an
# upgrade leaves behind) and `archive` (Finder-hides _archive/… folders).
# UI helpers come from functions/_ui.sh.
# ─────────────────────────────────────────────────────────────────────────────
upgrade() {
    local dry_run=false
    [[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]] && dry_run=true

    # ─────────────────────────────────────────────────────────────────────────
    # 1. Homebrew — update formulae index, then upgrade outdated packages
    # ─────────────────────────────────────────────────────────────────────────
    _header "Updating Homebrew"

    _task "Updating formulae..."
    if $dry_run; then
        _skip "Updating formulae (dry run: index untouched)"
    else
        brew update --quiet > /dev/null 2>&1 && _done "Formulae updated"
    fi

    _task "Checking outdated packages..."
    # NO_AUTO_UPDATE: `brew outdated` otherwise implicitly refreshes the index —
    # we update explicitly above, and a dry run must stay read-only.
    local outdated
    outdated=$(HOMEBREW_NO_AUTO_UPDATE=1 brew outdated --quiet)
    if [[ -z "$outdated" ]]; then
        _skip "All packages up to date"
    elif $dry_run; then
        _done "Outdated packages:"
        echo "$outdated" | while read -r pkg; do _item "$pkg"; done
        _item "would run: brew upgrade"
    else
        brew upgrade --quiet
        _done "Packages upgraded"
        printf '  %bUpgraded:%b\n' "$_C_DIM" "$_C_RESET"
        echo "$outdated" | while read -r pkg; do _item "$pkg"; done
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # 2. Alfred prefs repo — the other Mac's commits (modules/apps/alfred.nix).
    #    Fast-forward only; a dirty tree is left alone (doctor nags about it).
    # ─────────────────────────────────────────────────────────────────────────
    _header "Alfred prefs repo"

    local alfred_dir="${XDG_CONFIG_HOME:-$HOME/.config}/alfred/Alfred.alfredpreferences"
    if [[ ! -d "$alfred_dir/.git" ]]; then
        _skip "Alfred prefs repo not cloned (run: re)"
    elif [[ -n "$(git -C "$alfred_dir" status --porcelain 2> /dev/null)" ]]; then
        _skip "Alfred prefs repo is dirty — commit first, then pull"
        git -C "$alfred_dir" status --short | while read -r line; do _item "$line"; done
    else
        _task "Fetching..."
        if ! git -C "$alfred_dir" fetch --quiet 2> /dev/null; then
            _skip "Alfred prefs fetch failed (offline?)"
        else
            local behind ahead
            behind=$(git -C "$alfred_dir" rev-list --count 'HEAD..@{upstream}' 2> /dev/null || echo 0)
            ahead=$(git -C "$alfred_dir" rev-list --count '@{upstream}..HEAD' 2> /dev/null || echo 0)
            if [[ "$behind" == 0 ]]; then
                _skip "Alfred prefs up to date"
            elif $dry_run; then
                _done "Alfred prefs: $behind commit(s) to pull"
                _item "would run: git pull --ff-only"
            elif git -C "$alfred_dir" pull --ff-only --quiet 2> /dev/null; then
                _done "Alfred prefs: pulled $behind commit(s)"
            else
                _skip "Alfred prefs: not fast-forwardable — rebase by hand"
            fi
            [[ "$ahead" != 0 ]] && _item "$ahead local commit(s) not pushed"
        fi
    fi

    # ─────────────────────────────────────────────────────────────────────────
    # 3. Nix inputs — report-only. `nix flake update` rewrites flake.lock in
    #    the hm repo and needs a commit before `re`, so it stays a manual step;
    #    this just surfaces how stale the inputs are.
    # ─────────────────────────────────────────────────────────────────────────
    _header "Nix flake inputs"

    local lock="${HM:-$HOME/.config/home-manager}/flake.lock"
    if [[ -f "$lock" ]]; then
        local age_days
        age_days=$((($(date +%s) - $(stat -f %m "$lock")) / 86400))
        printf '  %bℹ%b inputs last updated %b%d day(s) ago%b — refresh with: %bnix flake update && re%b\n' \
            "$_C_CYAN" "$_C_RESET" "$_C_BOLD" "$age_days" "$_C_RESET" "$_C_BOLD" "$_C_RESET"
    else
        _skip "flake.lock not found"
    fi

    printf '\n%b✓%b %bUpgrade complete%b %b— run `tidy` to reclaim old kegs%b\n\n' \
        "$_C_GREEN" "$_C_RESET" "$_C_BOLD" "$_C_RESET" "$_C_DIM" "$_C_RESET"
}
