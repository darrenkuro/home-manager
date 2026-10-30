# Nix store mount — plain daemon for profiles without the BTM takeover.
#
# Why this exists: once the BTM module (./darwin.nix) has activated on a
# machine, nix-darwin owns /Library/LaunchDaemons/org.nixos.darwin-store.plist
# and the installer's original is gone. If a later generation stops declaring
# the daemon, nix-darwin's activation deletes the plist — and the next reboot
# leaves the encrypted Nix Store volume locked, /nix empty, and every
# /etc + ~ symlink into /nix/store dangling (work iMac, Oct 2026). So every
# profile must declare a darwin-store daemon; this is the stub-free one.
#
# No home.nix half — nothing user-scoped to manage.
{ ... }: let
    spec = import ./spec.nix;
in
{
    launchd.daemons.darwin-store = {
        serviceConfig = {
            Label = "org.nixos.darwin-store";
            ProgramArguments = [ "/bin/sh" "-c" spec.mountScript ];
            RunAtLoad = true;
        };
    };
}
