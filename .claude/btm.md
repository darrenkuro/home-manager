# BTM (Background Task Management) Patterns

Guidelines for macOS Login Items / Background Task Management in this repo.

## Overview

BTM controls what appears in System Settings → General → Login Items. The goal is proper naming and icon grouping instead of generic "sh" entries.

## Architecture

BTM logic is split between a shared lib and per-service modules:

- **`lib/launchd-btm.nix`** — `mkWrapper` (named binaries), `mkStubInstall` (idempotent manifest-checked stub install + user-agent `AssociatedBundleIdentifiers` patching), `stubDir`/`agentDir` constants
- **`modules/services/<name>/darwin.nix`** — each service defines its wrappers, launchd agents/daemons, and calls `mkStubInstall` for its own stub (appends to `postActivation`; ownership only, no codesigning)
- **`scripts/btm-patch-nix.sh`** — signs all stubs with the real identity + patches the Nix system-daemon plists (runs via `sure`)

## Key Files

- `lib/launchd-btm.nix` — all shared BTM logic (plain functions, no option types)
- `modules/services/<name>/darwin.nix` — per-service wrappers, agents, stub registration
- `modules/services/<name>/<Name>.app/` — static stub bundle (Info.plist, PkgInfo, icon.icns)
- `scripts/btm-patch-nix.sh` — signs all app stubs + patches Nix daemon plists
- `darwin.nix` — only the service imports list (comment out to disable)

## mkWrapper

Creates a named shell script with wait4path:

```nix
btm.mkWrapper {
  name = "PostgresServer";
  runtimeInputs = [ pkgs.postgresql ];
  text = ''exec postgres -D "$PGDATA"'';
}
```

Use `useSystemBash = true` for scripts that run before /nix is mounted.

## Adding a New Service

1. Create .app stub in `modules/services/<name>/<Name>.app`
2. Create `modules/services/<name>/darwin.nix` (copy polymarket's as a template)
3. Add its import line to the root `darwin.nix` services list

Example `modules/services/myapp/darwin.nix`:

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
  launchd.user.agents.my-service = {
    serviceConfig = {
      Label = "com.example.myservice";
      ProgramArguments = [ "${btm.stubDir}/MyApp.app/Contents/MacOS/MyService" ];
      RunAtLoad = true;
      KeepAlive = true;
    };
  };

  system.activationScripts.postActivation.text = btm.mkStubInstall {
    name = "MyApp";
    app = ./MyApp.app;
    wrappers = [ { drv = myWrapper; bin = "MyService"; } ];
    agents = [ "com.example.myservice" ];
  };
}
```

## App Stub Structure

```
MyApp.app/
├── Contents/
│   ├── Info.plist      # CFBundleIdentifier
│   ├── MacOS/          # Wrapper binaries embedded at activation
│   └── Resources/
│       └── icon.icns
```

## Rebuild Commands

- `re` — home-manager only (no BTM, no sudo)
- `sure` — full darwin-rebuild + btm-patch-nix.sh (with sudo)

## Gotchas

1. **Icon refresh requires reboot** — After changing icons, reboot
2. **Never use `sfltool resetbtm`** — Wipes ALL login items system-wide
3. **Codesign happens post-activation** — Keychain not accessible during sudo darwin-rebuild; btm-patch-nix.sh signs as real user
4. **Always use real identity** — Ad-hoc signing (`-s -`) defeats BTM icon grouping
5. **Stub shows as "Dianze Lu" (cert name) with a generic icon** — not a signing problem. Check LaunchServices for a duplicate registration of the stub's bundle id: `lsregister -dump | grep -E '^path:.*(Nix|Postgres)\.app'`. The `/nix/store/*-Nix.app` source copy (unsigned, no `MacOS/`) can get registered after a stub rebuild (seen 2026-10-31, both Nix and Postgres); BTM then resolves `com.local.nix.stub` to it and files the daemons under the developer name. `btm-patch-nix.sh` now unregisters every `/nix/store/*.app` each `sure`. Verified fixed right after the next `sure`, no reboot needed. (Earlier README §6 "rewritten stub, wait for reboot" explanation was wrong for this case — a reboot alone did not fix it.)
6. **Third-party helpers get their own developer row** (e.g. "Dropbox, Inc." = DropboxUpdater, "Steam" = steamclean) when their user agent's `AssociatedBundleIdentifiers` is missing or points at the helper rather than the app. `btm-patch-nix.sh` re-points them at the vendor app (same Team ID required) each `sure` — `THIRD_PARTY` array. Vendors rewrite these plists (steamclean was rewritten the same day), so expect the rows to split again until the next `sure`. **Unverified whether BTM honors the change for an already-known agent**: editing the plist + `launchctl bootout/bootstrap` did NOT change `sfltool dumpbtm`'s parent (2026-10-31); a one-row Login Items screenshot seen right after a reload was a transient, not the merge. Trust `dumpbtm`'s `Parent Identifier` over the Settings pane. Reboot pending as the real test; if still split, drop the entry from `THIRD_PARTY`.
7. **Empty `com.dropbox.dropboxmacupdate.{agent,xpcservice}.plist`** in `~/Library/LaunchAgents` are leftovers from an old updater, never loaded — moved to Dropbox backups 2026-10-31; harmless if they come back.

`lsregister` = `/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister`.
