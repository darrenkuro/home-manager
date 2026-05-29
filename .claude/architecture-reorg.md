# Home Manager Architecture Reorganization Plan

Last revised: 2026-05-29 (supersedes the earlier `default.nix`-per-service draft).

## Problem Summary

- `darwin.nix` is a 516-line junk drawer (Homebrew, defaults, BTM, services, launchd, env).
- `modules/services/<name>/` directories contain only `.app` bundles — the name lies.
- PostgreSQL constants (paths, port, pg pkg) are duplicated in `home.nix` and `darwin.nix`.
- `launchd.user.envVariables` duplicates ~24 entries from `home.sessionVariables`.
- BTM logic is scattered across `lib/launchd-btm.nix`, `darwin.nix`, and `scripts/btm-patch-nix.sh`.
- `scripts/copy-files.sh` is a 5-app junk drawer (VSCode, tmux, alacritty, tmux-nix, Claude jq merge).
- `enableDataCollector = false` is the only feature toggle and lives buried in a let-binding.
- `modules/system/aliases.nix` mixes real aliases with hidden mini-features (sync-local, kotr, ytd, clean, rm→trash, tmux→brew).
- Hardcoded `/Users/darrenlu` paths even where `homeDir` is in scope.

## Target Architecture

```
home-manager/
├── flake.nix
├── features.nix                            # NEW — single feature-toggle file
├── darwin.nix                              # slimmed: nix settings + imports
├── home.nix                                # slimmed: base + imports
├── lib/
│   ├── btm.nix                             # NEW — replaces launchd-btm.nix
│   │                                       #   exports: mkWrapper, mkStub,
│   │                                       #   installCmd, patchAgentCmd,
│   │                                       #   patchDaemonCmd, services registry
│   └── xdg-paths.nix                       # NEW — { home } -> attrset of XDG paths
├── modules/
│   ├── system/
│   │   ├── env.nix                         # imports xdg-paths.nix(home="$HOME")
│   │   ├── launchd-env.nix                 # NEW — imports xdg-paths.nix(home=hardcoded)
│   │   ├── aliases.nix                     # base only; junk extracted to apps/macos-extras
│   │   ├── aliases-cp.nix                  # badge generators (kept)
│   │   ├── aliases-man.nix                 # /usr/bin/man overrides (kept)
│   │   └── linux-ft.nix
│   ├── apps/
│   │   ├── git.nix, helix.nix, starship.nix, claude.nix, ssh.nix, netusage.nix
│   │   ├── dprint.nix                      # NEW — extracted from home.nix
│   │   ├── vscode.nix                      # NEW — owns settings copy (was copy-files.sh)
│   │   ├── tmux.nix                        # NEW — owns conf copy
│   │   ├── alacritty.nix                   # NEW — ft-only
│   │   ├── colima.nix                      # NEW — docker/colima group
│   │   └── macos-extras.nix                # NEW — sync-local/cloud, kotr, ytd, clean,
│   │                                       #   trash, remoteon/off, tmux brew override
│   └── services/
│       ├── postgresql/
│       │   ├── spec.nix                    # { home } -> { dataDir, logDir, port, pg, ... }
│       │   ├── user.nix                    # HM scope: initdb, env, aliases
│       │   ├── system.nix                  # nix-darwin scope: launchd agents, BTM registration
│       │   ├── Postgres.app/               # BTM stub (existing)
│       │   └── pg_hba.conf                 # moved from configs/postgresql/
│       ├── polymarket/
│       │   ├── spec.nix, user.nix, system.nix
│       │   └── Polymarket.app/
│       └── nix-daemon/
│           ├── spec.nix, system.nix        # no user.nix needed
│           └── Nix.app/
└── scripts/                                # shell-init chain; copy-files.sh deleted
    ├── source.sh, hygiene.sh, load-nix.sh, nix-prepend-path.sh,
    ├── ssh-keychain.sh, repeat-rate.sh
    └── btm-patch-nix.sh                    # still used by `sure` (or merged into lib/btm.nix later)
```

## Patterns

### 1. Service triplet

Each service is one directory with three nix files:

- `spec.nix` — pure facts (paths, ports, package derivations). Takes only `{ home, pkgs }`. No options, no config. Both halves import it.
- `user.nix` — home-manager module. Owns initdb activation, `home.sessionVariables`, `programs.zsh.shellAliases`, packages.
- `system.nix` — nix-darwin module. Owns the wrapper derivations, `launchd.user.agents`/`launchd.daemons`, and `btm.services.<name>` registration.

Top-level imports (after refactor):

```nix
# home.nix
imports = [ ... ] ++ lib.optionals features.postgresql [
  ./modules/services/postgresql/user.nix
];

# darwin.nix
imports = [ ... ] ++ lib.optionals features.postgresql [
  ./modules/services/postgresql/system.nix
];
```

### 2. BTM registry

`lib/btm.nix` exposes a declarative `btm.services` attrset, processed once at the top level. Each service registers itself:

```nix
# services/postgresql/system.nix
{ ... }: {
  btm.services.postgresql = {
    app = ./Postgres.app;
    wrappers = {
      PostgresServer = postgresServerWrapper;
      PostgresBackup = postgresBackupWrapper;
    };
    agents = [ "org.postgresql.server" "org.postgresql.backup" ];
  };
  launchd.user.agents.postgresql-server = { ... };
  launchd.user.agents.postgresql-backup = { ... };
}
```

`lib/btm.nix` consumers (in `darwin.nix`):

- expand `btm.services` into the `btmStubCommands` activation block
- expand into `patchAgentCommands` for `AssociatedBundleIdentifiers`
- system daemons still need `btm-patch-nix.sh` until we move daemon patching into the lib too

### 3. Single-source XDG env

`lib/xdg-paths.nix`:

```nix
{ home }: {
  XDG_CONFIG_HOME = "${home}/.config";
  XDG_CACHE_HOME = "${home}/.cache";
  # ... all path-shaped vars (16 entries)
  DOTNET_CLI_TELEMETRY_OPTOUT = "1";  # constants live here too
}
```

- `modules/system/env.nix` imports with `home = "$HOME"` — produces shell-expandable strings for `home.sessionVariables`.
- `modules/system/launchd-env.nix` imports with `home = "/Users/darrenlu"` — produces literal paths for `launchd.user.envVariables`.

Shell-only vars (`HISTFILE`, `ZSH_SESSION_DIR`, color codes, `DBOX`, `DEV`, `HM`, `HM_TAG`) stay in `env.nix` only.

### 4. Feature toggles

`features.nix`:

```nix
{ tag }: {
  postgresql = tag == "mac";
  polymarket = false;          # replaces enableDataCollector
  nix-daemon = tag == "mac";
  colima = tag == "mac";
}
```

Passed via `extraSpecialArgs` from `flake.nix`. `enableDataCollector` deleted.

### 5. Retire `copy-files.sh`

Each app's writable-config activation moves into its own module:

- VSCode → `modules/apps/vscode.nix` (owns `envsubst < vscode-settings.jsonc > ...`)
- Tmux → `modules/apps/tmux.nix`
- Alacritty → `modules/apps/alacritty.nix` (ft-only)
- tmux-nix bin → `modules/apps/tmux.nix` (ft branch)
- Claude `settings.json` jq merge → `modules/apps/claude.nix`

`scripts/copy-files.sh` deleted; the activation block in `home.nix` that sourced it deleted.

## Phased Plan

### Phase 0 — Quick wins (this session)

1. `lib/xdg-paths.nix` + `modules/system/launchd-env.nix`; cut the duplicated block from `darwin.nix`.
2. `modules/services/postgresql/spec.nix`; both `home.nix` and `darwin.nix` import it. No structural move yet.

Goal: prove the spec.nix pattern and the xdg-paths pattern with the smallest possible diff.

### Phase 1 — Service triplets

3. `services/postgresql/user.nix` + `system.nix`. `home.nix` and `darwin.nix` import them. Delete inlined PG sections.
4. Same for `services/polymarket/{user,system}.nix` (currently disabled — still validate it builds).
5. Same for `services/nix-daemon/system.nix` (system-only).

### Phase 2 — BTM registry

6. `lib/btm.nix` exports declarative `btm.services` registry; `darwin.nix` consumes once.
7. Per-service `system.nix` registers via `btm.services.<name> = { ... }`.

### Phase 3 — Retire copy-files.sh + new app modules

8. `modules/apps/vscode.nix`, `tmux.nix`, `alacritty.nix`, `dprint.nix`, `colima.nix`, `macos-extras.nix`.
9. Delete `scripts/copy-files.sh` and the `writableConfigs` activation in `home.nix`.

### Phase 4 — Feature toggles + slim darwin.nix

10. `features.nix` + plumb through `extraSpecialArgs`. Replace `enableDataCollector`.
11. Verify `darwin.nix` is down to ~150 lines (nix settings, homebrew, system.defaults, imports, BTM postActivation glue).

## Verification per phase

After each phase:

1. `dprint fmt`
2. `git add <files> && git commit -m "..."` (flakes only see committed)
3. `re` — fast HM rebuild. Verify shell still loads, aliases work.
4. `sure` — full rebuild. Verify `launchctl list | grep postgresql` shows running agents.
5. Reboot for BTM icon changes (Phase 2 only).
6. Open Claude Desktop — verify GUI env vars are present (Phase 0).

## Decisions (locked)

- Service split: **triplet** (`user.nix` + `system.nix` + `spec.nix` per service).
- BTM: **full registry** in `lib/btm.nix`.
- `copy-files.sh`: **retire entirely**.
- Start with: **quick wins** (Phase 0).
