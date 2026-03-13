# Nix BTM stub — groups Nix system daemons under a friendly icon in Login Items.
#
# Creates Nix.app stub with wrapper scripts that nix-darwin's launchd.daemons
# configuration (in darwin.nix) points to. The wrappers are inside the .app
# bundle so BTM can resolve the association and display "Nix" with a custom icon.
{ lib, pkgs, ... }:

let
  btm = import ../../../lib/launchd-btm.nix { inherit lib pkgs; };

  # Shell wrappers embedded in Nix.app
  nixDaemonWrapper = btm.mkWrapper {
    name = "NixDaemonStart";
    text = ''
      /bin/wait4path /nix/var/nix/profiles/default/bin/nix-daemon
      exec /nix/var/nix/profiles/default/bin/nix-daemon
    '';
  };

  nixStoreMountWrapper = btm.mkWrapper {
    name = "NixStoreMount";
    text = ''
      # Dynamically find the Nix Store volume UUID by name
      # This handles UUID changes after Nix reinstalls
      nixVolumeUUID=$(/usr/sbin/diskutil apfs list | \
        /usr/bin/awk '/Volume disk.*[0-9A-F-]{36}/ {uuid=$NF} /Nix Store/ && uuid {print uuid; exit}')

      if [ -z "$nixVolumeUUID" ]; then
        echo "Error: Could not find Nix Store volume UUID" >&2
        exit 1
      fi

      /usr/bin/security find-generic-password -s "$nixVolumeUUID" -w | \
        /usr/sbin/diskutil apfs unlockVolume "$nixVolumeUUID" -mountpoint /nix -stdinpassphrase
    '';
  };
in
{
  btm.stubs."Nix" = {
    src = ./Nix.app;
    wrappers = [
      { drv = nixDaemonWrapper; bin = "NixDaemonStart"; }
      { drv = nixStoreMountWrapper; bin = "NixStoreMount"; }
    ];
  };
}
