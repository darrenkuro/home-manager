INSTALL_TAG=(MAC FT)
REQUIRED_TOOLS=()
_check_preamble || return 0

# `clean` was merged into `tidy` (functions/tidy.sh), which now does everything
# clean used to plus cache/Xcode/pnpm/Nix reclaim. This thin front-end keeps the
# `clean` muscle-memory working. On the ft box (Linux — `tidy` is MAC-only) it
# falls back to a minimal, dependency-free $HOME scrub.
clean() {
    if command -v tidy > /dev/null 2>&1; then
        tidy "$@"
        return
    fi
    # ── ft fallback: lightweight $HOME scrub (no brew/nix/xcode) ──
    # Uses /bin/rm because `rm` is aliased to `trash`.
    /bin/rm -rf "$HOME/.cache" "$HOME/.npm" "$HOME/.matplotlib" \
        "$HOME/.aspnet" "$HOME/.dotnet" "$HOME/.nuget" "$HOME/.templateengine" \
        "$HOME/.docker" "$HOME/.lesshst" "$HOME"/.zcompdump*(N)
    /bin/rm -f "$HOME/.DS_Store"
    echo "clean: done (minimal scrub)"
}
