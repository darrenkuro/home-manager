# Home Manager Architecture Reorganization Plan

## Problem Summary

The current architecture has:
- **darwin.nix is a 540-line monolith** containing all BTM, services, Homebrew, system defaults
- **Service definitions scattered** across 4-5 files (darwin.nix, home.nix, modules/services/, scripts/)
- **Tag conditionals repeated** 20+ times across files (`lib.mkIf (tag == "mac")`)
- **Module namespaces confusing**: `modules/services/` contains only .app bundles, not actual Nix modules
- **Env vars duplicated**: defined in env.nix AND hardcoded in darwin.nix for launchd

## Proposed Architecture

```
home-manager/
├── flake.nix                    # Entry point (unchanged)
├── darwin.nix                   # Slimmed: Homebrew, system.defaults, imports services
├── home.nix                     # Slimmed: base config, imports modules
├── lib/
│   ├── launchd-btm.nix         # mkWrapper (unchanged)
│   └── paths.nix               # Centralized path definitions (NEW)
├── modules/
│   ├── shell/                  # Shell configuration
│   │   ├── aliases.nix         # From modules/system/aliases.nix
│   │   ├── env.nix             # From modules/system/env.nix (single source of truth)
│   │   └── functions.nix       # References functions/*.sh
│   ├── programs/               # Per-app config (renamed from apps/)
│   │   ├── git.nix
│   │   ├── helix.nix
│   │   ├── starship.nix
│   │   ├── claude.nix
│   │   └── ssh.nix
│   ├── services/               # Self-contained service modules (NEW)
│   │   ├── postgresql/
│   │   │   ├── default.nix     # HM + darwin config combined
│   │   │   └── Postgres.app/   # Bundle (existing)
│   │   ├── polymarket/
│   │   │   ├── default.nix
│   │   │   └── Polymarket.app/
│   │   └── nix-daemon/
│   │       ├── default.nix
│   │       └── Nix.app/
│   └── platform/               # Platform-specific overrides (NEW)
│       ├── darwin.nix          # Mac-only: homebrew, system.defaults
│       └── linux-ft.nix        # 42-specific config
└── scripts/                    # (unchanged)
```

## Key Changes

### 1. Self-Contained Service Modules

Each service becomes a single module with all its config:

**modules/services/postgresql/default.nix**:
```nix
{ config, lib, pkgs, tag, ... }:
let
  cfg = config.services.postgresql;
  pg = pkgs.postgresql_17.withPackages (ps: [ps.pgvector]);
  paths = import ../../lib/paths.nix { inherit config; };
in {
  options.services.postgresql.enable = lib.mkEnableOption "PostgreSQL";

  config = lib.mkIf (cfg.enable && tag == "mac") {
    # Packages
    home.packages = [ pg ];

    # Session variables
    home.sessionVariables = {
      PGDATA = paths.postgresql.data;
      PGHOST = paths.postgresql.socket;
    };

    # Aliases
    programs.zsh.shellAliases = { ... };

    # Activation
    home.activation.postgresqlInit = ...;

    # Darwin-specific (conditionally merged)
    # Wrappers, LaunchAgents, BTM stubs defined here
  };
}
```

**Usage in home.nix**:
```nix
imports = [ ./modules/services/postgresql ];
services.postgresql.enable = true;
```

### 2. Centralized Paths

**lib/paths.nix**:
```nix
{ config }: {
  btmStubs = "${config.home.homeDirectory}/.local/share/app-stubs";
  postgresql = {
    data = "${config.xdg.dataHome}/postgresql/data";
    logs = "${config.xdg.stateHome}/postgresql";
    backups = "${config.xdg.dataHome}/postgresql/backups";
    socket = "/tmp";
    port = "5432";
  };
  polymarket = {
    workDir = "${config.home.homeDirectory}/Documents/dev/polymarket-trading-bot";
    logs = "/tmp/polymarket";
  };
}
```

### 3. Env Vars Single Source

Remove hardcoded env vars from darwin.nix. Instead, generate `launchd.user.envVariables` from `home.sessionVariables`:

```nix
# darwin.nix
launchd.user.envVariables = lib.filterAttrs
  (k: v: !(lib.hasPrefix "$" v))  # Filter out shell-only vars
  config.home-manager.users.darrenlu.home.sessionVariables;
```

### 4. Slim darwin.nix

After extracting services, darwin.nix becomes ~150 lines:
- Nix settings
- Homebrew config
- system.defaults
- Import service modules
- BTM postActivation (shared)

### 5. Module Rename

- `modules/apps/` → `modules/programs/` (matches home-manager naming)
- `modules/system/` → `modules/shell/` (more accurate)
- `modules/services/` → actual Nix modules (not just .app bundles)

## Implementation Phases

### Phase 1: Extract Services (Low Risk)
1. Create `lib/paths.nix`
2. Create `modules/services/postgresql/default.nix` with all PostgreSQL config
3. Create `modules/services/polymarket/default.nix`
4. Create `modules/services/nix-daemon/default.nix`
5. Import from home.nix/darwin.nix, remove duplicated code
6. Test with `re` and `sure`

### Phase 2: Consolidate Shell Config (Low Risk)
1. Rename `modules/system/` → `modules/shell/`
2. Rename `modules/apps/` → `modules/programs/`
3. Update imports in home.nix

### Phase 3: Single-Source Env Vars (Medium Risk)
1. Remove hardcoded env vars from darwin.nix
2. Generate launchd.user.envVariables from home.sessionVariables
3. Test GUI apps receive env vars after reboot

### Phase 4: Platform Modules (Optional)
1. Create `modules/platform/darwin.nix` for Homebrew/system.defaults
2. Create `modules/platform/linux-ft.nix` for 42-specific config
3. Slim darwin.nix further

## Files to Modify

| File | Action | Size Change |
|------|--------|-------------|
| darwin.nix | Extract services → ~150 lines | -400 lines |
| home.nix | Extract services, update imports | -50 lines |
| lib/paths.nix | New | +30 lines |
| modules/services/postgresql/default.nix | New (consolidated) | +150 lines |
| modules/services/polymarket/default.nix | New (consolidated) | +40 lines |
| modules/services/nix-daemon/default.nix | New (consolidated) | +60 lines |
| modules/shell/ | Rename from system/ | 0 |
| modules/programs/ | Rename from apps/ | 0 |

**Net effect**: Similar total LOC but much better organization. Each service is self-contained.

## Verification

After each phase:
1. `dprint fmt` — format
2. `re` — fast home-manager rebuild
3. Check shell aliases work
4. `sure` — full darwin-rebuild
5. `launchctl list | grep postgresql` — services running
6. Reboot, verify BTM icons appear correctly
7. Open Claude Desktop, verify it reads env vars

## Decisions

1. **Keep both standalone and embedded HM** — preserves fast `re` workflow
2. **Simple enable flags** — `services.postgresql.enable = true` with hardcoded defaults
