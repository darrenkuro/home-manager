# Simplify & Reorganize home-manager

> Status: executed 2026-06-11 — PRs #6–#15. All phases landed; see git log for the per-phase commits.
> Post-plan amendments: #14 delivered commits stranded by stacked-PR bases (#12/#13 had merged into a feature branch); #15 restored `modules/system/linux-ft.nix` as an intentional placeholder, reversing part of Phase 1.

## Context

Audit (2026-06-11) of `~/.config/home-manager` against the goal: _simple, organized, maintainable by the owner without help_. Findings:

1. **The old refactor plan is itself the overengineering source.** `.claude/architecture-reorg.md` prescribes a `btm.services` options registry (started as untracked `lib/btm-options.nix` — module submodule types for 2 services) and a `features.nix` bool file (contradicts the comment-out-imports preference). It is superseded by this plan.
2. **Git sprawl.** Daily work lives on `refactor/phase-1-triplets` (7 commits, local-only); `main` is stale; 5 other branches + 1 leftover worktree exist — all verified fully merged into HEAD (`git merge-base --is-ancestor` checked for each).
3. **`darwin.nix` (486 ln) junk drawer.** Hardest code in repo: Nix-generating-bash stub installer with escaped manifests (`darwin.nix:201-262`), 60-line backup script inline in a Nix string (`darwin.nix:67-124`), ~80 lines of disabled Polymarket config behind `enableDataCollector = false`.
4. **Dead code.** Empty `modules/system/linux-ft.nix` (`{...}: {}`). (Note: `functions/icon.sh` with `INSTALL_TAG=()` is NOT dead — that's the deliberate function-level toggle-off state, kept.)
5. **Drift/duplication.** `home.nix:75` repeats `postgresql_17.withPackages` instead of `pg.pkg` from the spec it imports; README documents nonexistent files (ghostty, taskrc), omits `darwin.nix`/`lib/`; Claude config split between `claude.nix` and the jq merge in `copy-files.sh`; mini-programs squashed into alias strings (`clean`, `sync-local`/`sync-cloud` Swift one-liners in `aliases.nix`).

**Verified enabler:** nix-darwin's `system.activationScripts.<name>.text` is `types.lines` (checked pinned source: `modules/lib/write-text.nix`) — multiple imported modules can each append their own activation snippet. Per-service self-contained modules need **no registry**.

## Decisions (locked with user)

- **Structure:** per-service self-contained modules; root `darwin.nix`/`home.nix` become thin import lists.
- **Toggle convention:** disable a service by commenting out its import line (Homebrew-style). No `enableXxx` bools, no `features.nix`, no options registry.
- **Polymarket:** keep as a complete module with its import commented out (user wants it available later).
- **Aliases:** extract `clean` and `sync-local`/`sync-cloud` into `functions/*.sh`.
- **Workflow:** live on `main`; branches only for experiments.

## Target layout

```
flake.nix                  # unchanged (fix 1 stale comment)
darwin.nix                 # ~160 ln: nix settings, homebrew, system.defaults,
                           #   defaults-write postActivation, users, GUI env, imports
home.nix                   # ~170 ln: identity, packages, shell, activation, imports
lib/
  launchd-btm.nix          # mkWrapper (exists) + mkStubInstall (new) — plain functions
  xdg-paths.nix            # unchanged
modules/
  system/                  # aliases.nix (slimmer), env.nix, aliases-cp/man.nix
  apps/                    # + claude.nix gains settings.json hooks merge
  services/
    postgresql/            # spec.nix · darwin.nix · home.nix · backup.sh · pg_hba.conf · Postgres.app/
    nix-daemon/            # darwin.nix · Nix.app/
    polymarket/            # darwin.nix (import commented out) · Polymarket.app/
functions/                 # + clean.sh, icloud-sync.sh (icon.sh kept, toggled off)
scripts/                   # copy-files.sh loses claude block; btm-patch-nix.sh unchanged
```

Toggle UX in root `darwin.nix`:

```nix
imports = [
  ./modules/services/postgresql/darwin.nix
  ./modules/services/nix-daemon/darwin.nix
  # ./modules/services/polymarket/darwin.nix   # disabled — uncomment + `sure` to enable
];
```

## Phases — one PR per phase, smallest comprehensible steps

**Git workflow (locked):** Phase 0 happens directly on `main` (it _is_ the branch cleanup). Each later phase: short-lived branch off `main` → one commit → verify → show full PR title/body/diff → push + PR only with approval → merge to `main` → delete branch → next phase. No long-lived refactor branch.

> Every phase: `dprint fmt` → `shellcheck` touched scripts → `git add <files> && git commit` **before** `re`/`sure` (flakes only see committed files).

### Phase 0 — Git hygiene (no code change)

1. `git checkout main && git merge --ff-only refactor/phase-1-triplets`, push main (with approval).
2. Delete merged branches — local: `nix-darwin`, `nix-darwin-migration`, `refactor/phase-0-dedup`, `refactor/remove-templates-simplify-init`, `refactor/phase-1-triplets`, `claude/sleepy-aryabhata`; remote: same four that exist on origin. `git worktree remove .claude/worktrees/sleepy-aryabhata` first (prunable).
3. `rm lib/btm-options.nix` (untracked, abandoned registry).
4. Save this plan as `.claude/architecture-simplify.md`; delete `.claude/architecture-reorg.md`.

### Phase 1 — Dead code & drift

- Delete `modules/system/linux-ft.nix` + its import (`home.nix:203`); retarget ft alias `p` → `$HM/home.nix` (`aliases.nix:66`).
- `home.nix:75`: replace literal `postgresql_17.withPackages …` with `pg.pkg`.
- Fix stale `flake.nix:79` comment ("during transition" → describe the intentional `re`/`sure` split).

### Phase 2 — BTM helper consolidation (darwin.nix only shrinks; behavior identical)

- `lib/launchd-btm.nix` gains `mkStubInstall { name, app, wrappers, agents ? [] }` → returns the bash for: idempotent manifest-checked stub install (keep the manifest — it prevents BTM re-prompt churn), ownership fix, and `AssociatedBundleIdentifiers` patching for the listed agent labels. Single definition of the tricky logic; plain function, no option types.
- Root `darwin.nix`: replace `btmStubCommands` + `btmAgentMapping` + `patchAgentCommands` codegen (lines 199–262) with one `mkStubInstall` call per stub.

### Phase 3a — PostgreSQL module

- `modules/services/postgresql/darwin.nix`: pgConf, both wrappers, both launchd agents, its `postActivation` snippet via `mkStubInstall` (incl. its 2 agent labels). `homeDir = "/Users/darrenlu";` one-liner in its `let` (honest, greppable).
- Extract backup script → `modules/services/postgresql/backup.sh`; wrapper text becomes `export PG_PORT=… PG_SOCKET=… PG_LOG_DIR=… PG_BACKUP_DIR=…` prelude + `builtins.readFile ./backup.sh` (script reads env vars; shellcheck still enforced by `writeShellApplication`).
- `modules/services/postgresql/home.nix`: initdb activation block, `PGDATA`/`PGHOST` sessionVariables, `pglog`/`pgbackuplog`/`pgstatus` aliases, `pg.pkg` package — all moved from root `home.nix`.
- Root `home.nix` imports it inside the existing `lib.optionals (tag == "mac")` list; root `darwin.nix` imports the darwin half. Delete the moved sections + the `pg` let-binding from both roots.

### Phase 3b — nix-daemon module

- `modules/services/nix-daemon/darwin.nix`: `NixDaemonStart` + `NixStoreMount` wrappers, both `launchd.daemons`, stub install snippet. (System-daemon plist patching stays in `scripts/btm-patch-nix.sh` — unchanged, it works.)

### Phase 3c — Polymarket module (the toggle exemplar)

- `modules/services/polymarket/darwin.nix`: wrapper, agent, stub install, `mkdir -p /tmp/polymarket` (moves from `home.nix:141-143` — delete `serviceTmpDirs` block).
- Import line added **commented out** in root `darwin.nix`; delete `enableDataCollector` and all `lib.optionalAttrs`/`mkIf` gating.
- Drift guard: when `mkStubInstall`'s signature ever changes, temporarily uncomment and run the dry-run build to confirm it still evaluates.

### Phase 4 — Claude config single-owner

- Move the settings.json jq hooks merge (last ~15 lines of `scripts/copy-files.sh`) into `modules/apps/claude.nix`'s existing activation block (use `${pkgs.jq}/bin/jq`). `copy-files.sh` becomes purely envsubst file copies (VSCode/tmux/alacritty/tmux-nix).

### Phase 5 — Aliases → functions

- `functions/clean.sh` (`INSTALL_TAG=(MAC FT)`) replacing the `clean` concat-chain; `functions/icloud-sync.sh` (`INSTALL_TAG=(MAC)`, `REQUIRED_TOOLS=(swift)`) with readable multi-line `sync-local`/`sync-cloud`. Remove both from `aliases.nix`.

### Phase 6 — Docs catch up to reality

- README: structure tree (add `darwin.nix`, `lib/`, services layout + toggle convention), config-strategies section (drop taskrc/ghostty; Claude settings → claude.nix), keep troubleshooting as-is.
- CLAUDE.md: Module Organization → per-service modules + toggle convention; copy-files.sh description; add "live on main" workflow note.
- Document BOTH toggle conventions side by side: services → comment out the import line; shell functions → `INSTALL_TAG=()` (e.g. `functions/icon.sh` is the existing exemplar, kept as-is).
- `.claude/btm.md`: update "all BTM logic is in darwin.nix" key-files map to new layout.

## Explicitly NOT doing (guardrails against re-overengineering)

- No `features.nix`, no `btm.services` option types, no `extraSpecialArgs` plumbing for toggles.
- Not splitting `copy-files.sh` into per-app Nix modules (linear bash is the clearer form).
- Not touching `_preamble.sh` convention, `tidy.sh`, `claude-usage.sh`, `btm-patch-nix.sh` internals, starship/helix/git modules.
- Not "fixing" subtle redundancies with behavior risk (e.g. `HISTFILE` in env.nix vs `programs.bash.historyFile`) — noted, deliberately left.
- Not deleting toggled-off code: disabled ≠ dead in this repo. `functions/icon.sh` (`INSTALL_TAG=()`) and the Polymarket module stay, parked behind their respective toggles.

## Size targets

| File                | Before         | After   |
| ------------------- | -------------- | ------- |
| darwin.nix          | 486            | ~160    |
| home.nix            | 204            | ~170    |
| aliases.nix         | 78             | ~45     |
| copy-files.sh       | 50             | ~35     |
| lib/btm-options.nix | 39 (untracked) | deleted |

## Verification

- **Every phase:** `nix build .#darwinConfigurations.mac.system --dry-run` (full eval) and `nix eval .#homeConfigurations.ft.activationPackage.drvPath` (ft never breaks).
- **Home-side phases (1, 3a-home, 4, 5):** `re`; open new shell; spot-check (`type clean sync-local`, `pgstatus`, settings.json hooks key re-merged after deleting it).
- **Darwin-side phases (2, 3a-c):** user runs `! sure`; then `launchctl list | grep -E 'postgresql|nixos'`, `pgstatus`, `psql -l`; activation log shows `stub unchanged` (Phase 2) or one-time reinstall (Phase 3a — wrapper drv changes once; bundle IDs/paths unchanged so BTM identity and icons persist, no reboot expected; `sure` re-signs via btm-patch-nix.sh).
- **Backup path (3a):** run the `PostgresBackup` wrapper once manually; check `backup.log` + a `.dump` appears; confirm retention prune lines sane.
- **Phase 0:** `git branch -a` shows only `main` (+ remotes); `git status` clean.

## Implementation notes

- User-authored spots (learning mode): (1) the imports/toggle comment block in root `darwin.nix` — the interface he'll live with; (2) `functions/clean.sh` purge list — his data decisions.
- Never `git add -A`; stage named files. Push only after showing the diff and getting approval.
