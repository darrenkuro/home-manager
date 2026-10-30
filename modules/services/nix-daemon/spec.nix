# Shared facts for the Nix daemon service — imported by both
# `darwin.nix` (BTM takeover, personal profile) and `store-mount.nix`
# (plain daemon, every other profile) so the volume-unlock logic is defined
# exactly once.
#
# Pure attribute set — no module args, no `config`. Safe to import from
# either scope.
{
    # Unlocks and mounts the encrypted "Nix Store" APFS volume at boot. Runs
    # BEFORE /nix exists, so only /bin/sh and /usr/bin, /usr/sbin tools.
    #
    # Looks the volume up by name at runtime (never a hardcoded UUID): a Nix
    # reinstall gives the volume a new UUID and would strand a baked-in one.
    # The installer stores the passphrase in the System keychain under the
    # volume's crypto-user UUID (same as its Volume UUID on installer-made
    # volumes), so that UUID is both the keychain service and the unlock user.
    mountScript = ''
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
}
