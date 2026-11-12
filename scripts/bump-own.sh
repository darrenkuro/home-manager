#!/bin/bash
# Bump my own flake inputs (claude-config, bocal) to their pushed HEAD and keep
# flake.lock in step with origin, so the two Macs never race on lock commits.
# Run by the `re` / `sure` aliases (modules/system/aliases.nix) right before the
# rebuild. Upstream inputs stay a manual `nix flake update`.
#
#   1. pull --rebase --autostash   a lock-only conflict (both Macs bumped) is
#                                  resolved by taking origin's lock; step 2
#                                  re-bumps on top of it
#   2. nix flake update <inputs>
#   3. commit flake.lock if it changed (pathspec: only the lock)
#   4. push                        the other Mac's next `re` starts from here
#
# Fail-soft: offline, no ssh key or a conflict beyond flake.lock warn and the
# build goes on with the local lock. Ctrl-C during the bump exits 130, which
# aborts the alias chain (nix itself exits 1 on SIGINT, same as offline).
set -u

HM="${HM:-$HOME/.config/home-manager}"
INPUTS=(claude-config bocal)
MSG="flake: bump ${INPUTS[0]}, ${INPUTS[1]}"

warn() { printf '\033[1;33m⚠ %s\033[0m\n' "$1" >&2; }
g() { git -C "$HM" "$@"; }
rebasing() { [ -d "$HM/.git/rebase-merge" ] || [ -d "$HM/.git/rebase-apply" ]; }

# During a rebase, "ours" is the side being rebased onto — origin. A commit that
# becomes empty once the lock is taken from origin is skipped, never --continue'd
# (a failing --continue can also mean the *next* commit conflicted, so it is never
# chained with --skip).
resolve_lock_conflicts() {
    local n=0
    while rebasing && [ $((n += 1)) -le 20 ]; do
        [ "$(g diff --name-only --diff-filter=U)" = "flake.lock" ] || return 1
        g checkout -q --ours -- flake.lock && g add flake.lock
        if g diff --cached --quiet; then
            g rebase --skip > /dev/null 2>&1 || return 1
        else
            GIT_EDITOR=true g rebase --continue > /dev/null 2>&1 || true
        fi
    done
    ! rebasing
}

# 1. sync with origin
if ! g pull -q --rebase --autostash origin main 2> /dev/null; then
    if rebasing; then
        if ! resolve_lock_conflicts; then
            g rebase --abort
            warn "hm pull: conflict beyond flake.lock — building the local lock; fix by hand: git -C \$HM pull --rebase"
        fi
    else
        warn "hm pull failed (offline?) — building the local lock"
    fi
fi

# 2. bump own inputs
(
    trap 'exit 130' INT
    nix flake update "${INPUTS[@]}" --flake "$HM"
)
status=$?
[ "$status" -eq 130 ] && exit 130
[ "$status" -ne 0 ] && warn "own-input bump failed — building the current lock"

# 3. commit the lock on its own
g diff --quiet -- flake.lock || g commit -q -m "$MSG" -- flake.lock

# 4. push whatever is ahead of origin (the lock commit rides on top of main)
if [ -n "$(g log --oneline '@{upstream}..' 2> /dev/null)" ]; then
    g push -q origin main 2> /dev/null || warn "hm push failed — push later: git -C \$HM push"
fi
exit 0
