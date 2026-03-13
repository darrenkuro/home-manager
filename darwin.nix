# Minimal nix-darwin scaffold — system-level macOS config.
# Expand this with system.defaults, homebrew, etc. over time.
{ pkgs, ... }: {
  # Nix settings
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # User (needed for home-manager integration to infer home.homeDirectory)
  users.users.darrenlu = {
    name = "darrenlu";
    home = "/Users/darrenlu";
  };

  # nix-darwin state version
  system.stateVersion = 5;
}
