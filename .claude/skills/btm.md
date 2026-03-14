# BTM (Background Task Management) Patterns

Guidelines for macOS Login Items / Background Task Management in this repo.

## Overview

BTM controls what appears in System Settings → General → Login Items. The goal is proper naming and icon grouping instead of generic "sh" entries.

## Architecture

- **LaunchAgents** → defined in `darwin.nix` via `launchd.user.agents`
- **App stubs** → registered via `btm.stubs` for icon grouping
- **BTM patching** → darwin.nix post-activation adds `AssociatedBundleIdentifiers`

## Key Files

- `lib/launchd-btm.nix` — `mkWrapper` for named binaries
- `modules/services/btm.nix` — copies stubs, embeds wrappers, codesigns
- `darwin.nix` — LaunchAgents + BTM patching in post-activation

## mkWrapper

Creates a named shell script:

```nix
btm.mkWrapper {
  name = "PostgresServer";
  runtimeInputs = [ pkgs.postgresql ];
  text = ''exec postgres -D "$PGDATA"'';
}
```

Use `useSystemBash = true` for scripts that run before /nix is mounted.

## Registering a Service

```nix
# In service.nix — stub only
btm.stubs."Postgres" = {
  src = ./Postgres.app;
  wrappers = [
    { drv = serverWrapper; bin = "PostgresServer"; }
  ];
};

# In darwin.nix — agent definition
launchd.user.agents.postgresql-server = {
  serviceConfig = {
    Label = "org.postgresql.server";
    ProgramArguments = [ "${btmStubDir}/Postgres.app/Contents/MacOS/PostgresServer" ];
    RunAtLoad = true;
    KeepAlive = true;
  };
};

# In darwin.nix — BTM mapping for icon grouping
btmAgentMapping = {
  "org.postgresql.server" = "Postgres";
};
```

## App Stub Structure

```
Postgres.app/
├── Contents/
│   ├── Info.plist      # CFBundleIdentifier
│   ├── MacOS/          # Wrapper binaries embedded here
│   └── Resources/
│       └── icon.icns
```

## Gotchas

1. **Icon refresh requires reboot** — After changing icons, reboot
2. **Never use `sfltool resetbtm`** — Wipes ALL login items system-wide
3. **Codesign with real identity** — Ad-hoc signing may not work
