# Nix daemon + store mount — system half: launchd daemons + BTM stub.
#
# Takes over /Library/LaunchDaemons/org.nixos.{nix-daemon,darwin-store}.plist
# from the Nix installer so BTM shows named, icon-grouped entries instead of
# generic "sh". These are system DAEMONS: their AssociatedBundleIdentifiers
# are patched by scripts/btm-patch-nix.sh (run via `sure`), not by the
# user-agent patching in mkStubInstall.
#
# No home.nix half — nothing user-scoped to manage.
{ lib, pkgs, ... }: let
    btm = import ../../../lib/launchd-btm.nix { inherit lib pkgs; };

    nixDaemonWrapper = btm.mkWrapper {
        name = "NixDaemonStart";
        text = ''
      /bin/wait4path /nix/var/nix/profiles/default/bin/nix-daemon
      exec /nix/var/nix/profiles/default/bin/nix-daemon
    '';
    };

    # useSystemBash = true because this runs BEFORE /nix is mounted
    nixStoreMountWrapper = btm.mkWrapper {
        name = "NixStoreMount";
        useSystemBash = true;
        text = ''
      nixVolumeDev=$(/usr/sbin/diskutil apfs list | \
        /usr/bin/awk '/Nix Store/ {print prev} {prev=$0}' | \
        /usr/bin/grep -o 'disk[0-9]*s[0-9]*')
      if [ -z "$nixVolumeDev" ]; then
        echo "Error: Could not find Nix Store volume device" >&2
        exit 1
      fi
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
    # Take over Nix daemon management from installer for BTM integration
    launchd.daemons.nix-daemon = {
        serviceConfig = {
            Label = "org.nixos.nix-daemon";
            ProgramArguments = lib.mkForce [
                "${btm.stubDir}/Nix.app/Contents/MacOS/NixDaemonStart"
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

    launchd.daemons.darwin-store = {
        serviceConfig = {
            Label = "org.nixos.darwin-store";
            ProgramArguments = [ "${btm.stubDir}/Nix.app/Contents/MacOS/NixStoreMount" ];
            RunAtLoad = true;
        };
    };

    system.activationScripts.postActivation.text = btm.mkStubInstall {
        name = "Nix";
        app = ./Nix.app;
        wrappers = [
            { drv = nixDaemonWrapper; bin = "NixDaemonStart"; }
            { drv = nixStoreMountWrapper; bin = "NixStoreMount"; }
        ];
    };
}
