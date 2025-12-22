# Reorder PATH to ensure nix path is at the very front

# Deduplicate PATH and keep order stable
typeset -gU path PATH

# Nix paths we want first
# Currently symlinks for .nix-profile, so should be fine
nix_bins=(
  /nix/var/nix/profiles/default/bin
  "$HOME/.nix-profile/bin"
)

# Move Nix paths to the front (last insert wins)
for p in "${nix_bins[@]}"; do
  path=("$p" ${path:#$p})
done
