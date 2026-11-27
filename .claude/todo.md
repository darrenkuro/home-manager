# TODO

- [ ] BTM on the work iMac (named Login Items) — plan + risks in `.claude/architecture-btm-work.md`; boot-critical (Nix store mount daemon), needs a signing-cert decision first
- [ ] Suppress BTM "App Background Activity" notifications — `.mobileconfig` profile targeting `com.apple.btmnotificationagent` (only confirmed method; no `defaults write` exists)
- [ ] Dedup stale entries in Notification Settings — surgical dedup of `com.apple.ncprefs.plist` by `bundle-id` (keeps per-app prefs; `killall cfprefsd` after)
- [ ] Declare the remaining global keyboard shortcuts (see below)
- [ ] `tidy`: optional recursive `.DS_Store` sweep — `find "$DEV" "$DBOX" -name .DS_Store -type f -delete` (plain `find` is fine on local dirs; only the CloudStorage walk hung)

---

## Global keyboard shortcuts

Extend the `modules/system/tiling-hotkeys.nix` pattern (per-id `defaults write -dict-add`, never the whole `AppleSymbolicHotKeys` dict — that wipes undeclared ids). Fill + halves (237, 240–243) are done. Remaining state as of 2026-03-16:

- **Disabled:** 15–26 Mission Control / Spaces · 60 previous input source · 164 Notification Center · 176 Focus · 257–258 unknown
- **Enabled:** 61 next input source `[32,49,786432]` · 98 unknown Cmd+Ctrl+/ `[47,44,1179648]` · 233 unknown Cmd+M `[109,46,1048576]` · 238 `[39,39,786432]` · 239 `[114,15,786432]` · 244 `[117,32,786432]` · 245 `[105,34,786432]` · 246 `[106,38,786432]` · 247 `[107,40,786432]`
- Modifiers: `1048576` Cmd · `786432` Ctrl+Opt · `9175040` Fn+Ctrl+Opt · `1179648` Cmd+Ctrl · `262144` Ctrl
- Caveats: ids undocumented and may change across macOS versions; may need logout/login (or `/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u`)
- Per-app menu shortcuts are a separate, safe mechanism: `system.defaults.CustomUserPreferences."<bundle id>".NSUserKeyEquivalents` (`@` Cmd, `^` Ctrl, `~` Opt, `$` Shift)

---

## Anki

Decided 2026-11-27 (tasks/2026-11-anki-setup): Anki stays out of hm except two shell functions, `anki-backup` (run by
hand) and `anki-restore`. The 2026-06-18 copy-in-place add-on draft is superseded (hm `programs.anki` and nixpkgs add-ons
lock the Add-ons dialog and fight Anki's updater; note types live in logbook/anki/models, pushed by `logbook sync anki --models`).

- [ ] recurring task "run backup" (monthly; umbrella over `anki-backup`, `logbook-backup`, tasks/2026-11-setup-cleanup Area G) once Logbook's task CLI is the place for it (2026-11-27)
