# Work iMac profile — make `profile` and machine identity first-class

Approved 2026-09-25. Delete this file when all five commits have landed.

## Goal

One repo, three machines (`mac` personal, `mac-work` iMac, `ft` Linux):
machine identity (user, home, arch) and profile (app set, services) declared
exactly once — no hardcoded `darrenlu` anywhere — and a checked, documented
bootstrap path for the work iMac.

Decisions made with Darren:

- Parameterize ALL usernames/home paths (iMac user may diverge later)
- iMac is Apple Silicon (same `aarch64-darwin`, `/opt/homebrew`)
- Work keeps `cleanup = "zap"` (same as personal; destructive-on-first-run
  behavior is understood — see lessons.md re: mas apps)
- Work is minimal: NO BTM takeover (stock nix-darwin daemons, no stubs, no
  codesigning, no encrypted-Nix-Store assumption); `sure` on work skips
  `btm-patch-nix.sh`

## Design

### Machine map in flake.nix (single source of truth)

```nix
machines = {
  mac      = { system = "aarch64-darwin"; tag = "mac"; profile = "personal"; user = "darrenlu"; };
  mac-work = { system = "aarch64-darwin"; tag = "mac"; profile = "work";     user = "darrenlu"; };
  ft       = { system = "x86_64-linux";   tag = "ft";  profile = "personal"; user = "dlu"; };
};
```

`homeDir` derived (`/Users/…` darwin, `/home/…` linux). `mkDarwin`/`mkHome`
helpers build all targets from the map; `specialArgs` carry
`tag profile user homeDir system` to every module. Kills the two duplicated
darwinConfigurations blocks.

### Threading

- `home.nix`: `home.username = user; home.homeDirectory = homeDir` (tag chain gone)
- `darwin.nix`: plain module (no `{ profile ? … }:` wrapper); `users.users.${user}`,
  `system.primaryUser = user`, Finder path from `homeDir`
- `lib/launchd-btm.nix`: takes `homeDir`; services pass it (drop their hardcodes)

### Profile catalogue additions (profiles/macos.nix)

- `enableNixBtm`: personal `true`, work `false` — gates the nix-daemon service
  import (the `NixStoreMount` wrapper requires the personal machine's encrypted
  volume + keychain entry; it would hard-fail on a stock install)
- `sure` alias becomes profile-aware (work: no btm-patch step)

### HM_PROFILE

`env.nix` exports `HM_PROFILE` (PERSONAL/WORK) beside `HM_TAG`;
`_preamble.sh` gains optional `INSTALL_PROFILE=(…)` gate (absent = all).

### Bootstrap

`scripts/work-preflight.sh` (read-only): arch check, brew present, GitHub SSH
auth (claude-config input is git+ssh), nix + flakes, repo location. README
work section shrinks to: CLT → Nix → Homebrew → SSH key → clone → preflight →
one switch command.

## Commits

1. Machine map + user threading (flake.nix, home.nix, darwin.nix)
2. homeDir into BTM lib + services (launchd-btm.nix, services)
3. enableNixBtm gating + profile-aware sure (profiles, darwin.nix, aliases.nix)
4. HM_PROFILE + preamble gate (env.nix, _preamble.sh)
5. Preflight script + README rewrite

## Verification

- Commits 1–2 are pure refactors: `darwinConfigurations.mac.system.drvPath`
  must be BYTE-IDENTICAL before/after (also mac-work for commit 1)
- Every commit: `nix eval` of all targets (mac, mac-work system drvs; ft
  activationPackage)
- Commit 3: only mac-work's drv may change
- After commit 4: fresh shell shows HM_PROFILE (needs `re` first)
- Commit 5: shellcheck the preflight script (bash, real shebang)
- Final: dprint fmt, audit pass for repetition/minimality

## Non-goals

tag system, comment-out service toggles, `re`/`sure` semantics on personal,
work app list contents, anything about `ft`, polymarket stays parked.
