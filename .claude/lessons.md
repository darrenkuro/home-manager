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

## dprint Nix Plugin Instability

`dprint fmt` errors on `flake.nix` and `lib/launchd-btm.nix` with
"Formatting succeeded initially, but failed when ensuring a stable format"
— a dprint-plugin-nix bug triggered by certain constructs (it leaves the
file untouched, so it's safe but noisy). Hand-format those two files in
repo style; everything else formats normally. Also: from the repo root,
plain `dprint fmt` needs `--config-discovery=global` (config lives at
~/.config/dprint/dprint.json, not in-repo).

## zsh Alias-in-Alias Expansion (why functions use /bin/rm)

zsh re-expands aliases in an alias's expansion text, AND expands aliases
inside function bodies at definition (source) time. With `rm` aliased to
trash on mac, any `rm` in an alias string or sourced function silently
becomes `trash`. That's why `functions/*.sh` call `/bin/rm` explicitly —
follow that convention in new functions.

## git checkout -- <file> Reverts ALL Uncommitted Edits

When testing a temporary tweak (e.g. uncommenting a toggle with sed),
don't restore with `git checkout -- <file>` unless the file's real
changes are already committed/staged — it reverts to HEAD and eats them.
Stage first, or undo the tweak with a second sed.
