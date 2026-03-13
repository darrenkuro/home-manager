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
      # Find the Nix Store volume device identifier (e.g., disk3s7)
      # Parse the line BEFORE "Nix Store" which contains the device
      nixVolumeDev=$(/usr/sbin/diskutil apfs list | \
        /usr/bin/awk '/Nix Store/ {print prev} {prev=$0}' | \
        /usr/bin/grep -o 'disk[0-9]*s[0-9]*')

      if [ -z "$nixVolumeDev" ]; then
        echo "Error: Could not find Nix Store volume device" >&2
        exit 1
      fi

      # Get the crypto user UUID from the volume
      nixCryptoUUID=$(/usr/sbin/diskutil apfs listCryptoUsers "$nixVolumeDev" -plist | \
        /usr/bin/plutil -extract Users.0.APFSCryptoUserUUID raw -)

      if [ -z "$nixCryptoUUID" ]; then
        echo "Error: Could not find Nix Store crypto user UUID" >&2
        exit 1
      fi

      /usr/bin/security find-generic-password -s "$nixCryptoUUID" -w | \
        /usr/sbin/diskutil apfs unlockVolume "$nixVolumeDev" -stdinpassphrase -user "$nixCryptoUUID"
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
