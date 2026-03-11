{ lib, ... }: {
  # macOS defaults applied on every `home-manager switch`.
  # Uses absolute paths since Nix activation env has minimal PATH.
  home.activation.macosDefaults = lib.hm.dag.entryAfter ["writeBoundary"] ''
    /usr/bin/defaults write -g NSRecentDocumentsLimit 0
    /usr/bin/defaults write com.apple.dock show-recents -bool false
  '';
}
