# nix-darwin system-level macOS config.
{ lib, ... }:

let
  # BTM stub location (managed by home-manager btm module)
  btmStubDir = "/Users/darrenlu/.local/share/app-stubs";
in
{
  # Nix settings
  nix.settings.experimental-features = ["nix-command" "flakes"];

  # User (needed for home-manager integration to infer home.homeDirectory)
  users.users.darrenlu = {
    name = "darrenlu";
    home = "/Users/darrenlu";
  };

  # Take over Nix daemon management from installer for BTM integration
  # This replaces /Library/LaunchDaemons/org.nixos.nix-daemon.plist
  launchd.daemons.nix-daemon = {
    serviceConfig = {
      Label = "org.nixos.nix-daemon";
      ProgramArguments = lib.mkForce [
        "${btmStubDir}/Nix.app/Contents/MacOS/NixDaemonStart"
      ];
      KeepAlive = true;
      RunAtLoad = true;
      LowPriorityIO = false;
      ProcessType = "Standard";
      SoftResourceLimits.NumberOfFiles = 1048576;
      EnvironmentVariables = {
        NIX_SSL_CERT_FILE = "/etc/ssl/certs/ca-certificates.crt";
        OBJC_DISABLE_INITIALIZE_FORK_SAFETY = "YES";
      };
    };
  };

  # This replaces /Library/LaunchDaemons/org.nixos.darwin-store.plist
  launchd.daemons.darwin-store = {
    serviceConfig = {
      Label = "org.nixos.darwin-store";
      ProgramArguments = [
        "${btmStubDir}/Nix.app/Contents/MacOS/NixStoreMount"
      ];
      RunAtLoad = true;
    };
  };

  # nix-darwin state version
  system.stateVersion = 5;
}
