# BTM (Background Task Management) Patterns

Guidelines for macOS Login Items / Background Task Management in this repo.

## Overview

BTM controls what appears in System Settings → General → Login Items. The goal is proper naming and icon grouping instead of generic "sh" entries.

## Key Files

- `lib/launchd-btm.nix` — Pure builders: `mkWrapper`, `mkPlist`
- `modules/services/btm.nix` — Activation: copies stubs, embeds wrappers, codesigns
- `configs/app-stubs/` — Static `.app` bundles with icons
- `modules/services/*/service.nix` — Individual service definitions

## How BTM Icon Grouping Works

1. **Executable inside .app bundle** — BTM resolves icons by path containment
2. **AssociatedBundleIdentifiers** — Links agent to parent app's bundle ID
3. **Codesigning** — Bundle must be signed for grouping to work

## mkWrapper

Creates a named shell script that becomes the executable:

```nix
btm.mkWrapper {
  name = "PostgresServer";
  runtimeInputs = [ pkgs.postgresql ];
  text = ''
    exec postgres -D "$PGDATA"
  '';
}
```

Output: `${drv}/bin/PostgresServer`

### useSystemBash Option

For scripts that run BEFORE /nix is mounted (like darwin-store):

```nix
btm.mkWrapper {
  name = "NixStoreMount";
  useSystemBash = true;  # Uses /bin/bash instead of /nix/store/.../bash
  text = "...";
}
```

## mkPlist

Creates launchd plist with BundleProgram (relative path):

```nix
btm.mkPlist {
  Label = "org.postgresql.server";
  BundleProgram = "Contents/MacOS/PostgresServer";  # Relative to .app root
  RunAtLoad = true;
  KeepAlive = true;
}
```

During activation, btm.nix converts `BundleProgram` to absolute `ProgramArguments` and adds `AssociatedBundleIdentifiers`.

## Registering a Service

```nix
btm.stubs."Postgres" = {
  src = ./Postgres.app;           # Static .app stub from repo
  wrappers = [
    { drv = serverWrapper; bin = "PostgresServer"; }
    { drv = backupWrapper; bin = "PostgresBackup"; }
  ];
  agents = {
    "org.postgresql.server" = serverPlist;
    "org.postgresql.backup" = backupPlist;
  };
};
```

## App Stub Structure

```
Postgres.app/
├── Contents/
│   ├── Info.plist      # CFBundleIdentifier, CFBundleName
│   ├── PkgInfo         # "APPL????"
│   ├── MacOS/
│   │   └── Stub        # Dummy executable (printf '#!/bin/sh\nexit 0')
│   └── Resources/
│       └── icon.icns   # App icon
```

## Gotchas

1. **Icon refresh requires reboot** — After changing icons, logout/login or reboot
2. **Never use `sfltool resetbtm`** — It wipes ALL login items system-wide
3. **Codesign with real identity** — Ad-hoc signing may not work for BTM grouping
4. **Change detection** — btm.nix uses manifest hashes to skip redundant codesigns

## nix-darwin Migration

nix-darwin's `launchd.user.agents` can replace btm.nix's agent management:
- nix-darwin handles bootstrap/bootout automatically
- BUT: doesn't add AssociatedBundleIdentifiers
- KEEP: btm.nix stub copying, wrapper embedding, codesigning

See `lessons.md` for migration cleanup checklist.
