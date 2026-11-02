# TODO — BTM on the work iMac (mac-work)

Status: **not started**, planned 2026-11-02. Cosmetic only — Login Items show raw `sh` /
`bash` / `nix-daemon` names on the iMac because the work profile runs without BTM. Nothing
works differently once it is on, so do it only when the risks below are handled.

## Why it is off (history)

- `bed3eea` gated the BTM nix-daemon takeover per profile (`enableNixBtm`, work = false): no
  `.app` stubs, no codesigning identity on the iMac.
- `1255dd2`: the first `sure` after that dropped `org.nixos.darwin-store` (nix-darwin deletes
  any `org.nixos.*` plist a generation stops declaring), and the next reboot left the
  encrypted Nix Store volume locked, `/nix` empty and every `/etc` + `~` symlink dangling.
  Fixed by `store-mount.nix`; both daemon variants now share the unlock script in
  `modules/services/nix-daemon/spec.nix`.

## What turning it on touches

1. `profiles/macos.nix`: `work.enableNixBtm = true` swaps `store-mount.nix` for
   `nix-daemon/darwin.nix` (the takeover, with `NixStoreMount` / `NixDaemonStart` wrappers in
   a stub). This is the boot-critical part.
2. `modules/system/aliases.nix`: `sure` runs `scripts/btm-patch-nix.sh` only when
   `profile == "personal"`. Gate it on the profile's `enableNixBtm` instead.
3. Codesigning identity on the iMac. `btm-patch-nix.sh` signs as
   `Apple Development: odon5ht@gmail.com (497TM5HK44)`; ad-hoc is forbidden (`btm.md` #4).
   Options, decide first:
   - export cert + private key from the personal Mac as `.p12`, import on the iMac; or
   - let Xcode issue a second Apple Development cert for the iMac under the same Apple ID
     (then `CODESIGN_ID` must become per-machine, not a constant).
     Either way the personal Apple ID's signing key lives on a work machine — a policy call.
4. `docs/manual-setup.md`: the cert row says `mac personal` only; update it.
5. Optional: give the temporary `cal-notice` agent a stub `.app` so it gets a name too (only
   if it is still around — it is meant to be deleted).

## Steps

1. Decide the cert option; install it on the iMac; `security find-identity -v -p codesigning`
   lists it.
2. Make changes 1, 2 (and 4) in one commit; `nix eval` that `mac-work`'s activate script
   declares `org.nixos.darwin-store` and `org.nixos.nix-daemon` (diff against the current
   generation: only the daemon plists and the stub install should change).
3. On the iMac: `sure`.
4. **Before any reboot** verify:
   - `sudo launchctl print system/org.nixos.darwin-store` — loaded, program is the stub's
     `NixStoreMount`, exit 0;
   - the unlock path works: run the store-mount script by hand (it should find the volume
     and its keychain password and report already mounted);
   - `sfltool dumpbtm` shows the Nix entries under the stub's bundle id;
   - `codesign -dv` on the stub shows the real identity.
5. Only then reboot, and check `/nix/store` is mounted and `nix --version` works.

## Rollback

Set `work.enableNixBtm = false` again and `sure` — `store-mount.nix` re-declares
`org.nixos.darwin-store`, so the store stays mountable. Never `sfltool resetbtm` (`btm.md` #2).
