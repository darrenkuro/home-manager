# Ensure nix is on PATH when not already available (e.g. GUI shells).
# Tries the multi-user daemon profile first (mac, hetzner), then the
# single-user profile (ft's chroot nix).

if ! command -v nix > /dev/null 2>&1; then
    for _nix_sh in /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh \
        "$HOME/.nix-profile/etc/profile.d/nix.sh"; do
        if [[ -r $_nix_sh ]]; then
            # shellcheck disable=SC1090
            source "$_nix_sh"
            break
        fi
    done
    unset _nix_sh
fi
