INSTALL_TAG=(MAC)
REQUIRED_TOOLS=()
_check_preamble || return 0

# ─────────────────────────────────────────────────────────────────────────────
# backup — run every backup at once, like `tidy` / `upgrade` for their halves.
# Run by hand (a monthly reminder says so); nothing is scheduled.
#
#   backup            run each part in order, keep going after a failure
#   backup --dry-run  (or -n) pass --dry-run to every part
#
# The parts are a fixed, ordered list: a new *-backup function is added here by
# hand, never discovered (an alias or an unrelated function named *-backup must
# not run by accident). A part not defined on this machine (its INSTALL_TAG /
# INSTALL_PROFILE gate skipped it) is skipped, not failed. Returns 1 if any part
# failed. UI helpers come from functions/_ui.sh.
# ─────────────────────────────────────────────────────────────────────────────
backup() {
    local args=() arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run | -n) args=(--dry-run) ;;
            *) echo "usage: backup [--dry-run]" >&2; return 2 ;;
        esac
    done
    local parts=(anki-backup logbook-backup)
    local part rc failed=0 summary=()
    for part in "${parts[@]}"; do
        _header "$part"
        if ! typeset -f "$part" > /dev/null; then
            _skip "$part (not installed on this machine)"
            summary+=("○ $part skipped")
            continue
        fi
        "$part" "${args[@]}"
        rc=$?
        if [ $rc -eq 0 ]; then
            summary+=("● $part ok")
        else
            summary+=("✗ $part failed (exit $rc)")
            failed=1
        fi
    done
    _header "Summary"
    for arg in "${summary[@]}"; do printf '  %s\n' "$arg"; done
    return $failed
}
