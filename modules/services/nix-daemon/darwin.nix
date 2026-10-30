# Nix daemon + store mount — system half: launchd daemons + BTM stub.
#
# Takes over /Library/LaunchDaemons/org.nixos.{nix-daemon,darwin-store}.plist
# from the Nix installer so BTM shows named, icon-grouped entries instead of
# generic "sh". These are system DAEMONS: their AssociatedBundleIdentifiers
# are patched by scripts/btm-patch-nix.sh (run via `sure`), not by the
# user-agent patching in mkStubInstall.
#
# No home.nix half — nothing user-scoped to manage.
{ lib, pkgs, homeDir, config, ... }: let
    btm = import ../../../lib/launchd-btm.nix { inherit lib pkgs homeDir; };
    spec = import ./spec.nix;

    # nix-darwin's Nix (nix.package, tracks the locked nixpkgs), as its own
    # daemon module runs it — not the installer's frozen default profile.
    nixDaemon = lib.getExe' config.nix.package "nix-daemon";

    nixDaemonWrapper = btm.mkWrapper {
        name = "NixDaemonStart";
        text = ''
      /bin/wait4path ${nixDaemon}
      exec ${nixDaemon}
    '';
    };

    # useSystemBash = true because this runs BEFORE /nix is mounted.
    # Script shared with ./store-mount.nix (the non-BTM profiles' daemon).
    nixStoreMountWrapper = btm.mkWrapper {
        name = "NixStoreMount";
        useSystemBash = true;
        text = spec.mountScript;
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
