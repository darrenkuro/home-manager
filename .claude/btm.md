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
