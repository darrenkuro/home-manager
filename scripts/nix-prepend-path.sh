# Reorder PATH to ensure nix path is at the very front

# Deduplicate PATH and keep order stable
typeset -gU path PATH

# Nix paths we want first
# Currently symlinks for .nix-profile, so should be fine
nix_bins=(
  "$HOME/.nix-profile/bin"
)

# The installer's default profile is the only Nix on Linux. On macOS nix-darwin
# owns Nix (/run/current-system/sw/bin, already on PATH); forcing the frozen
# installer copy first would shadow it.
[[ $OSTYPE == darwin* ]] || nix_bins=(/nix/var/nix/profiles/default/bin "${nix_bins[@]}")

# Move Nix paths to the front (last insert wins)
for p in "${nix_bins[@]}"; do
  path=("$p" ${path:#$p})
done
