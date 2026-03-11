# Nix BTM stub — registers a parent app in BTM for Nix system daemons.
#
# Nix daemons (nix-daemon, darwin-store) are system-level LaunchDaemons
# managed by the Nix installer. They show as "Unknown Developer" in BTM
# because they have no AssociatedBundleIdentifiers.
#
# This module:
#   1. Registers a Nix.app stub (icon + bundle ID) via btm.stubs
#   2. Patches the Nix LaunchDaemon plists to add AssociatedBundleIdentifiers
#      (requires sudo, idempotent — skips if already patched)
{ config, lib, ... }:

let
  nixBundleId = "com.local.nix.stub";
  nixDaemonPlists = [
    "/Library/LaunchDaemons/org.nixos.nix-daemon.plist"
    "/Library/LaunchDaemons/org.nixos.darwin-store.plist"
  ];
in
{
  btm.stubs."Nix" = {
    src = ../../app-stubs/Nix.app;
    wrappers = [];
  };

  home.activation.patchNixDaemonPlists = lib.hm.dag.entryAfter [
    "btmLaunchAgents"
  ] ''
    set +e
    _need_sudo=0

    for plist in ${lib.concatStringsSep " " nixDaemonPlists}; do
      [ -f "$plist" ] || continue

      # Check if AssociatedBundleIdentifiers already contains our bundle ID
      _existing=$(/usr/libexec/PlistBuddy -c "Print :AssociatedBundleIdentifiers:0" "$plist" 2>/dev/null)
      if [ "$_existing" = "${nixBundleId}" ]; then
        continue
      fi

      _need_sudo=1
      break
    done

    if [ "$_need_sudo" -eq 1 ]; then
      # Try sudo — works if user has cached credentials or NOPASSWD
      if /usr/bin/sudo -n true 2>/dev/null; then
        echo "BTM: patching Nix daemon plists..."
        for plist in ${lib.concatStringsSep " " nixDaemonPlists}; do
          [ -f "$plist" ] || continue

          _existing=$(/usr/libexec/PlistBuddy -c "Print :AssociatedBundleIdentifiers:0" "$plist" 2>/dev/null)
          if [ "$_existing" = "${nixBundleId}" ]; then
            echo "  already patched: $(basename "$plist")"
            continue
          fi

          /usr/bin/sudo /usr/libexec/PlistBuddy -c "Delete :AssociatedBundleIdentifiers" "$plist" 2>/dev/null
          /usr/bin/sudo /usr/libexec/PlistBuddy \
            -c "Add :AssociatedBundleIdentifiers array" \
            -c "Add :AssociatedBundleIdentifiers:0 string ${nixBundleId}" \
            "$plist" && \
            echo "  patched: $(basename "$plist")" || \
            echo "  btm error: failed to patch $(basename "$plist")" >&2
        done
      else
        echo "BTM: Nix daemon plists need patching (one-time, requires sudo)."
        echo "  Run manually:"
        for plist in ${lib.concatStringsSep " " nixDaemonPlists}; do
          [ -f "$plist" ] || continue
          echo "  sudo /usr/libexec/PlistBuddy -c 'Add :AssociatedBundleIdentifiers array' -c 'Add :AssociatedBundleIdentifiers:0 string ${nixBundleId}' $plist"
        done
        echo "  Then reboot for BTM to pick up the change."
      fi
    fi

    set -e
  '';
}
