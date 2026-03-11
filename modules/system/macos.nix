{ lib, ... }: {
  # macOS defaults and cleanup applied on every `home-manager switch`.
  # Uses absolute paths since Nix activation env has minimal PATH.
  home.activation.macosDefaults = lib.hm.dag.entryAfter ["writeBoundary"] ''
    # Prevent new recent documents in Apple Menu > Recent Items
    /usr/bin/defaults write -g NSRecentDocumentsLimit 0

    # Hide recent apps section in Dock
    /usr/bin/defaults write com.apple.dock show-recents -bool false

    # Clear existing recent documents (global + per-app)
    /usr/bin/sfltool resetlist com.apple.LSSharedFileList.RecentDocuments 2>/dev/null || true
    /usr/bin/sfltool resetlist com.apple.LSSharedFileList.RecentApplications 2>/dev/null || true
    /usr/bin/sfltool resetlist com.apple.LSSharedFileList.ApplicationRecentDocuments 2>/dev/null || true
  '';
}
