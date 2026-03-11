# Nix BTM stub — registers a parent app in BTM for Nix system daemons.
#
# Nix daemons (nix-daemon, darwin-store) are system-level LaunchDaemons
# managed by the Nix installer. They show as "Unidentified Developer" in BTM
# because the launcher scripts at /usr/local/bin/ are shell scripts with no
# Team Identifier — macOS BTM ignores AssociatedBundleIdentifiers for them.
#
# This module:
#   1. Registers a Nix.app stub (icon + bundle ID) via btm.stubs
#   2. Compiles Mach-O wrapper binaries (NixDaemonStart, NixStoreMount)
#   3. Codesigns them with Apple Development cert (Team ID matches Nix.app stub)
#   4. Installs them to /usr/local/bin/ replacing the original shell scripts
#   5. Patches the Nix LaunchDaemon plists to add AssociatedBundleIdentifiers
#
# With Mach-O binaries + matching Team IDs, BTM can resolve the association
# and group both daemons under the Nix.app stub in Login Items.
{ config, lib, pkgs, ... }:

let
  nixBundleId = "com.local.nix.stub";

  # Machine-specific APFS volume UUID for the Nix store.
  # Read from the existing NixStoreMount script installed by the Nix installer.
  nixVolumeUUID = "7F2237ED-FBD0-463A-B08C-EC01257136DA";

  nixDaemonPlists = [
    "/Library/LaunchDaemons/org.nixos.nix-daemon.plist"
    "/Library/LaunchDaemons/org.nixos.darwin-store.plist"
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

  codesignId = "Apple Development: odon5ht@gmail.com (497TM5HK44)";
in
{
  btm.stubs."Nix" = {
    src = ../../app-stubs/Nix.app;
    wrappers = [];
  };

  home.activation.installNixWrappers = lib.hm.dag.entryAfter [
    "btmLaunchAgents"
  ] ''
    set +e

    echo "BTM: checking Nix Mach-O wrappers..."

    _need_sudo=0

    for bin in NixDaemonStart NixStoreMount; do
      _src="${nixWrappers}/bin/$bin"
      _dst="/usr/local/bin/$bin"

      # Skip if installed binary matches source (pre-codesign)
      # We track the source hash in a sidecar file since codesigning changes the binary
      _hash_file="${config.home.homeDirectory}/.local/share/app-stubs/.nix-wrapper-hash-$bin"
      _src_hash=$(/usr/bin/shasum -a 256 "$_src" | /usr/bin/cut -d' ' -f1)

      if [ -f "$_hash_file" ] && [ "$(/bin/cat "$_hash_file")" = "$_src_hash" ]; then
        continue
      fi

      _need_sudo=1
      break
    done

    if [ "$_need_sudo" -eq 0 ]; then
      set -e
      return 0 2>/dev/null || true
    fi

    if /usr/bin/sudo -n true 2>/dev/null; then
      for bin in NixDaemonStart NixStoreMount; do
        _src="${nixWrappers}/bin/$bin"
        _dst="/usr/local/bin/$bin"
        _tmp="/tmp/btm-$bin"
        _hash_file="${config.home.homeDirectory}/.local/share/app-stubs/.nix-wrapper-hash-$bin"
        _src_hash=$(/usr/bin/shasum -a 256 "$_src" | /usr/bin/cut -d' ' -f1)

        if [ -f "$_hash_file" ] && [ "$(/bin/cat "$_hash_file")" = "$_src_hash" ]; then
          continue
        fi

        /bin/cp "$_src" "$_tmp"
        /bin/chmod 755 "$_tmp"
        /usr/bin/codesign -fs "${codesignId}" "$_tmp"

        /usr/bin/sudo /bin/cp "$_tmp" "$_dst"
        /usr/bin/sudo /usr/sbin/chown root:wheel "$_dst"
        /usr/bin/sudo /bin/chmod 755 "$_dst"
        /bin/rm -f "$_tmp"

        echo "$_src_hash" > "$_hash_file"
        echo "  installed Mach-O wrapper: $bin"
      done
    else
      echo "BTM: Nix wrappers need sudo to install. Run manually:"
      for bin in NixDaemonStart NixStoreMount; do
        _src="${nixWrappers}/bin/$bin"
        echo "  cp $_src /tmp/btm-$bin && codesign -fs '${codesignId}' /tmp/btm-$bin && sudo cp /tmp/btm-$bin /usr/local/bin/$bin && sudo chown root:wheel /usr/local/bin/$bin"
      done
    fi

    set -e
  '';

  # Patch system LaunchDaemon plists with AssociatedBundleIdentifiers
  home.activation.patchNixDaemonPlists = lib.hm.dag.entryAfter [
    "installNixWrappers"
  ] ''
    set +e
    _need_sudo=0

    for plist in ${lib.concatStringsSep " " nixDaemonPlists}; do
      [ -f "$plist" ] || continue

      _existing=$(/usr/libexec/PlistBuddy -c "Print :AssociatedBundleIdentifiers:0" "$plist" 2>/dev/null)
      if [ "$_existing" = "${nixBundleId}" ]; then
        continue
      fi

      _need_sudo=1
      break
    done

    if [ "$_need_sudo" -eq 1 ]; then
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
