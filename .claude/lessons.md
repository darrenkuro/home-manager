# Lessons Learned

Patterns and fixes discovered while working on this repo.

## Nix Store Mount (darwin-store LaunchDaemon)

### Problem: Wrapper script can't run before /nix is mounted
- `writeShellApplication` uses Nix's bash: `#!/nix/store/.../bash`
- The darwin-store mount script runs BEFORE /nix is mounted
- Chicken-and-egg: script needs bash from /nix, but /nix doesn't exist yet

**Fix:** Added `useSystemBash = true` option to `mkWrapper` in `lib/launchd-btm.nix`.
This uses `/bin/bash` instead of Nix's bash for pre-mount scripts.

### Problem: diskutil apfs unlockVolume requires -user flag
- The encrypted APFS volume has a crypto user UUID
- `diskutil apfs unlockVolume` requires BOTH:
  - Device identifier (e.g., `disk3s7`)
  - `-user $UUID` flag with the crypto user UUID
- The UUID is used for both `security find-generic-password -s` AND `diskutil -user`

**Correct unlock command:**
```bash
# Get device and UUID
nixVolumeDev=$(diskutil apfs list | awk '/Nix Store/ {print prev} {prev=$0}' | grep -o 'disk[0-9]*s[0-9]*')
nixCryptoUUID=$(diskutil apfs listCryptoUsers "$nixVolumeDev" -plist | plutil -extract Users.0.APFSCryptoUserUUID raw -)

# Unlock
security find-generic-password -s "$nixCryptoUUID" -w | \
  diskutil apfs unlockVolume "$nixVolumeDev" -stdinpassphrase -user "$nixCryptoUUID"
```

### Problem: Parsing diskutil apfs list output
- "Nix Store" appears on the line AFTER the device identifier line
- Need to print the PREVIOUS line when "Nix Store" is found:
  ```bash
  awk '/Nix Store/ {print prev} {prev=$0}'
  ```

## BTM (Background Task Management)

- Wrapper binaries must be INSIDE the .app bundle for BTM icon resolution
- After icon changes, REBOOT to refresh BTM (don't use `sfltool resetbtm`)
- `sfltool resetbtm` wipes ALL login items system-wide — never use it

## Nix Derivation Output Structures

### writeShellApplication vs writeTextFile
- `writeShellApplication` outputs to `$out/bin/<name>`
- `writeTextFile` outputs to `$out` directly (just the file)
- btm.nix expects `${drv}/bin/${name}` structure for all wrappers

**Fix:** When using `writeTextFile`, set `destination = "/bin/${name}"` to match the expected structure:
```nix
pkgs.writeTextFile {
  inherit name;
  destination = "/bin/${name}";  # <-- critical!
  executable = true;
  text = "...";
}
```

## nix-darwin Migration (Complete)

- LaunchAgents migrated to darwin.nix (`launchd.user.agents`)
- BTM patching moved to darwin.nix post-activation script
- Removed env-setter (replaced by `launchd.user.envVariables`)
- Simplified btm.nix (removed agent logic, ~120 lines deleted)
- Added system.defaults from audit (NSGlobalDomain, dock, finder, trackpad, menuExtraClock)

