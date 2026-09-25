INSTALL_TAG=(MAC)
REQUIRED_TOOLS=(brew)
_check_preamble || return 0

# ─────────────────────────────────────────────────────────────────────────────
# upgrade — the network half split out of `tidy`: brew update + upgrade, plus
# a report-only Nix inputs reminder. Never mutates the hm repo (nix flake
# update changes flake.lock, which needs a commit — that stays manual).
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
    # 2. Nix inputs — report-only. `nix flake update` rewrites flake.lock in
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
