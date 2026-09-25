# lib/activation.nix — fail-soft helpers for darwin activation.
#
# nix-darwin assembles all activation steps into one bash script under a
# single `set -e`, so any failing step aborts everything after it. Observed
# failure mode (Sep 2026): two dead masApps ids made `brew bundle` exit
# non-zero, which skipped home-manager activation and all BTM patching while
# darwin-rebuild still looked switched (the generation symlink flips before
# activation runs).
#
# These helpers let non-critical steps (brew, defaults, BTM stubs) fail with
# a recorded warning instead of aborting. Steps that must stay fatal (users,
# launchd plist installation) are nix-darwin internals and are not wrapped.
{ lib }: rec {
    warnFile = "/var/tmp/hm-activation-warnings";

    # Defines _hm_warn for all later steps. Installed via the extraActivation
    # hook, which nix-darwin splices in before homebrew and postActivation.
    prelude = ''
        # ── fail-soft prelude (lib/activation.nix) ──
        : > ${warnFile}
        _hm_warn() {
          printf '\033[1;33mwarning: %s — continuing activation\033[0m\n' "$1" >&2
          printf '%s\n' "$1" >> ${warnFile}
        }
    '';

    # Run a block so its failure warns instead of aborting activation.
    # The subshell must be a plain command with errexit off in the parent:
    # bash disables `set -e` inside anything on the left of `||` or under
    # `if !`, which would let a mid-block failure fall through (e.g. stub
    # deleted, copy failed, manifest still written).
    failSoft = name: text: ''
        set +e
        (
          set -e
          ${text}
        )
        _hm_status=$?
        set -e
        if [ "$_hm_status" -ne 0 ]; then
          _hm_warn "${name} failed (exit $_hm_status)"
        fi
    '';

    # End-of-activation recap; mkAfter orders it last within postActivation
    # so long step output can't bury the warnings.
    summary = lib.mkAfter ''
        if [ -s ${warnFile} ]; then
          printf '\033[1;33m── activation completed with warnings ──\033[0m\n' >&2
          /bin/cat ${warnFile} >&2
        fi
    '';
}
