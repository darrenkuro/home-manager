# BTM (Background Task Management) Patterns

BTM controls System Settings → General → Login Items. Goal: real names and per-app icon grouping instead of generic "sh" entries. Architecture overview is in `CLAUDE.md`; `darwin.nix` only holds the service imports.

## Adding a New Service

1. Create the stub `modules/services/<name>/<Name>.app` (`Contents/Info.plist` with `CFBundleIdentifier`, `PkgInfo`, `Resources/icon.icns`; `MacOS/` is filled at activation — wrapper binaries must live INSIDE the bundle for icon resolution)
2. Create `modules/services/<name>/darwin.nix` (polymarket's is the template):

```nix
{ lib, pkgs, ... }: let
  btm = import ../../../lib/launchd-btm.nix { inherit lib pkgs; };
  myWrapper = btm.mkWrapper {
    name = "MyService";
    runtimeInputs = [ pkgs.mytool ];
    text = ''exec mytool --daemon'';
  };
in
{
  launchd.user.agents.my-service.serviceConfig = {
    Label = "com.example.myservice";
    ProgramArguments = [ "${btm.stubDir}/MyApp.app/Contents/MacOS/MyService" ];
    RunAtLoad = true;
    KeepAlive = true;
  };

  system.activationScripts.postActivation.text = btm.mkStubInstall {
    name = "MyApp";
    app = ./MyApp.app;
    wrappers = [ { drv = myWrapper; bin = "MyService"; } ];
    agents = [ "com.example.myservice" ];
  };
}
```

3. Add its import line to the root `darwin.nix` services list

## Gotchas

(Numbers are referenced from README.md and `scripts/btm-patch-nix.sh` — keep them stable.)

1. **Icon refresh requires reboot** after changing icons
2. **Never use `sfltool resetbtm`** — wipes ALL login items system-wide
3. **Codesign happens post-activation** — keychain isn't accessible during sudo darwin-rebuild; `btm-patch-nix.sh` signs as the real user
4. **Always use the real identity** — ad-hoc signing (`-s -`) defeats BTM icon grouping
5. **Stub shows as "Dianze Lu" (cert name) with a generic icon** — not a signing problem: a duplicate LaunchServices registration of the stub's bundle id. Check `lsregister -dump | grep -E '^path:.*Nix\.app'`. The unsigned `/nix/store/*-Nix.app` source copy (no `MacOS/`) can get registered after a stub rebuild; BTM then resolves `com.local.nix.stub` to it and files the daemons under the developer name. `btm-patch-nix.sh` unregisters every `/nix/store/*.app` each `sure`; fixed right after the next `sure`, no reboot (a reboot alone does not fix it).
6. **Third-party helpers get their own developer row** (e.g. "Dropbox, Inc." = DropboxUpdater) when their user agent's `AssociatedBundleIdentifiers` is missing or points at the helper. `btm-patch-nix.sh` (`THIRD_PARTY` array) re-points them at the vendor app (same Team ID required) each `sure`. **Editing the plist alone never moves the row**: BTM fixes an item's parent (`container` in the `.btm` db) when it first records it; later edits update the stored `associatedBundleIdentifiers` but not the parent. Fix (`reregister_agent`, run whenever the script rewrites a plist): `launchctl bootout`, move the plist out of `~/Library/LaunchAgents`, wait until the item leaves the db (~1–2 min, no reboot), move it back, `launchctl bootstrap` → fresh record under `2.<app bundle id>`. Vendors rewrite these plists: an association-only rewrite stays grouped, a delete-and-recreate splits it again until the next `sure`. Trust `sfltool dumpbtm`'s `Parent Identifier` over the Settings pane; without sudo the db is world-readable at `/private/var/db/com.apple.backgroundtaskmanagement/BackgroundItems-v18-<uuid>.btm` (NSKeyedArchiver plist; `plistlib` + resolve `$objects` UIDs, look at `identifier`/`container`).
7. **Empty `com.dropbox.dropboxmacupdate.{agent,xpcservice}.plist`** in `~/Library/LaunchAgents` are never-loaded leftovers of an old updater — harmless if they reappear.

`lsregister` = `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister`.
