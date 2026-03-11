{ lib, ... }: {
  # macOS defaults applied on every `home-manager switch`.
  # Uses `defaults write` since we don't use nix-darwin.
  # Add new defaults here to ensure they're set on fresh installs.
  home.activation.macosDefaults = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Disable recent documents for all apps
    defaults write -g NSRecentDocumentsLimit 0
  '';
}
