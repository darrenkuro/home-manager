# Nix BTM stub — registers a parent app in BTM for Nix system daemons.
#
# Nix daemons (nix-daemon, darwin-store) are system-level LaunchDaemons
# managed by the Nix installer. BTM groups items by tracing the executable
# path back to an app bundle.
#
# This module:
#   1. Registers Nix.app stub with embedded Mach-O wrappers via btm.stubs
#   2. Patches the Nix LaunchDaemon plists to point ProgramArguments at the
#      wrappers inside Nix.app and add AssociatedBundleIdentifiers
#
# With executables inside the codesigned Nix.app bundle, BTM resolves the
# association and groups both daemons under "Nix" in Login Items.
{ config, lib, pkgs, ... }:

let
  nixBundleId = "com.local.nix.stub";
  stubDir = config.btm.stubDir;

  # Machine-specific APFS volume UUID for the Nix store.
  # Read from the existing NixStoreMount script installed by the Nix installer.
  nixVolumeUUID = "7F2237ED-FBD0-463A-B08C-EC01257136DA";

  # Daemon label → wrapper binary name mapping
  nixDaemons = [
    { plist = "/Library/LaunchDaemons/org.nixos.nix-daemon.plist"; wrapper = "NixDaemonStart"; }
    { plist = "/Library/LaunchDaemons/org.nixos.darwin-store.plist"; wrapper = "NixStoreMount"; }
  ];

  nixWrappers = pkgs.stdenv.mkDerivation {
    name = "nix-btm-wrappers";
    src = ./nix-wrappers;
    buildPhase = ''
      cc -O2 -o NixDaemonStart NixDaemonStart.c
      cc -O2 -DNIX_VOLUME_UUID="\"${nixVolumeUUID}\"" -o NixStoreMount NixStoreMount.c
    '';
    installPhase = ''
      mkdir -p $out/bin
      cp NixDaemonStart NixStoreMount $out/bin/
    '';
  };
in
{
  btm.stubs."Nix" = {
    src = ../../app-stubs/Nix.app;
    wrappers = [
      { drv = nixWrappers; bin = "NixDaemonStart"; }
      { drv = nixWrappers; bin = "NixStoreMount"; }
    ];
  };

  # Patch system LaunchDaemon plists to point at wrappers inside Nix.app
  home.activation.patchNixDaemonPlists = lib.hm.dag.entryAfter [
    "btmLaunchAgents"
  ] ''
    set +e
    _stub_macos="${stubDir}/Nix.app/Contents/MacOS"

    ${lib.concatMapStringsSep "\n" (d: ''
      if [ -f "${d.plist}" ]; then
        _cur_prog=$(/usr/libexec/PlistBuddy -c "Print :ProgramArguments:0" "${d.plist}" 2>/dev/null)
        _cur_bid=$(/usr/libexec/PlistBuddy -c "Print :AssociatedBundleIdentifiers:0" "${d.plist}" 2>/dev/null)
        if [ "$_cur_prog" != "$_stub_macos/${d.wrapper}" ] || [ "$_cur_bid" != "${nixBundleId}" ]; then
          if /usr/bin/sudo -n true 2>/dev/null; then
            /usr/bin/sudo /usr/libexec/PlistBuddy \
              -c "Delete :ProgramArguments" \
              -c "Add :ProgramArguments array" \
              -c "Add :ProgramArguments:0 string $_stub_macos/${d.wrapper}" \
              -c "Delete :AssociatedBundleIdentifiers" \
              -c "Add :AssociatedBundleIdentifiers array" \
              -c "Add :AssociatedBundleIdentifiers:0 string ${nixBundleId}" \
              "${d.plist}" 2>/dev/null && \
              echo "  patched: $(basename "${d.plist}")" || \
              echo "  btm error: failed to patch $(basename "${d.plist}")" >&2
          else
            echo "BTM: Nix daemon plists need patching (requires sudo)."
            echo "  Run: sudo -v && re"
          fi
        fi
      fi
    '') nixDaemons}

    set -e
  '';
}
