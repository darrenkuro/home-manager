# BTM (Background Task Management) Patterns

Guidelines for macOS Login Items / Background Task Management in this repo.

## Overview

BTM controls what appears in System Settings → General → Login Items. The goal is proper naming and icon grouping instead of generic "sh" entries.

## Architecture

All BTM logic is in `darwin.nix`:
- **Wrappers** — named shell scripts via `lib/launchd-btm.nix`
- **App stubs** — static .app bundles with embedded wrappers
- **LaunchAgents/Daemons** — defined via `launchd.user.agents` and `launchd.daemons`
- **Activation** — postActivation installs stubs (no codesigning, ownership only)
- **Post-activation** — btm-patch-nix.sh signs all stubs with real identity

## Key Files

- `darwin.nix` — all BTM: wrappers, stubs config, activation, launchd agents
- `lib/launchd-btm.nix` — `mkWrapper` builder for named binaries
- `scripts/btm-patch-nix.sh` — signs all app stubs + patches Nix daemon plists
- `modules/services/*/` — .app stub bundles only (no .nix files)

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
2. In `darwin.nix`:
   - Define wrapper with `btm.mkWrapper`
   - Add to `btmStubs` config
   - Add `btmAgentMapping` entry
   - Define `launchd.user.agents.<name>`

Example:
```nix
# In darwin.nix let block
myWrapper = btm.mkWrapper {
  name = "MyService";
  runtimeInputs = [ pkgs.mytool ];
  text = ''exec mytool --daemon'';
};

btmStubs = {
  MyApp = {
    src = ./modules/services/myapp/MyApp.app;
    wrappers = [{ drv = myWrapper; bin = "MyService"; }];
  };
};

btmAgentMapping = {
  "com.example.myservice" = "MyApp";
};

# In config block
launchd.user.agents.my-service = {
  serviceConfig = {
    Label = "com.example.myservice";
    ProgramArguments = [ "${btmStubDir}/MyApp.app/Contents/MacOS/MyService" ];
    RunAtLoad = true;
    KeepAlive = true;
  };
};
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
