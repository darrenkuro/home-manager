# Lessons Learned

Non-obvious failures hit in this repo. BTM-specific gotchas live in `btm.md`.

## Nix Store mount (darwin-store daemon, `modules/services/nix-daemon/spec.nix`)

- It runs BEFORE /nix is mounted, so its wrapper can't use Nix's bash → `mkWrapper { useSystemBash = true; }` (`/bin/bash`).
- `diskutil apfs unlockVolume` needs BOTH the device (`disk3s7`) AND `-user <crypto user UUID>`; the same UUID is the keychain item name (`security find-generic-password -s`).
- In `diskutil apfs list`, "Nix Store" is on the line AFTER the device id → `awk '/Nix Store/ {print prev} {prev=$0}'`.

## nix-darwin deletes daemons a generation stops declaring

Activation removes every `/Library/LaunchDaemons/org.nixos.*` plist the previous generation declared and the new one doesn't. Once the BTM module has run, nix-darwin owns `org.nixos.darwin-store` (the installer's original is gone) — so gating it off (`enableNixBtm = false` for work) silently deleted the volume-unlock daemon on the work iMac; the next reboot left the encrypted Nix Store locked (/nix empty, every /etc and ~ symlink dangling, shell and sshd dead). **Every macOS profile must declare a darwin-store daemon** (`modules/services/nix-daemon/store-mount.nix` is the stub-free one). Manual recovery: `security find-generic-password -s <volume UUID> -w /Library/Keychains/System.keychain | diskutil apfs unlockVolume <dev> -mountpoint /nix -stdinpassphrase`.

## nix-darwin leaves user agents a generation stops declaring

Unlike daemons, removed `launchd.user.agents` stay loaded with their plists in place (seen removing postgresql). When deleting a service with user agents: after the rebuild, `launchctl bootout gui/$UID/<label>`, `rm` the plist, and remove its stub + `.stub-manifest-<Name>` from `~/.local/share/app-stubs`.

## nix-darwin launchd facts

- nix-darwin passes `ProgramArguments` as-is (no `/bin/sh -c` wrapper, unlike HM's `launchd.agents`) — what makes BTM naming work.
- It never adds `AssociatedBundleIdentifiers`; `mkStubInstall` patches it in.
- `system.primaryUser` is required for `launchd.user.agents`, `system.defaults.dock`, etc.
- GUI apps (Dock/Spotlight) only see env from `launchd.user.envVariables`.

## writeTextFile wrappers need `destination = "/bin/${name}"`

`mkStubInstall` expects `${drv}/bin/${name}` (the `writeShellApplication` layout); bare `writeTextFile` outputs to `$out` directly.

## brew bundle cleanup DOES uninstall Mac App Store apps

`sure` runs `brew bundle --zap --force-cleanup`, which uninstalls mas apps missing from `masApps` (Sep 2026: removing 4 entries from `profiles/macos.nix` deleted Pages, Numbers, Trello, OmniFocus). Treat any masApps removal as destructive. Restore = re-add the id and `sure`.

## dprint

- **Nix plugin instability:** `flake.nix`, `lib/launchd-btm.nix` and `modules/apps/claude.nix` fail with "Formatting succeeded initially, but failed when ensuring a stable format" (file left untouched — safe but noisy). Hand-format them. Root cause (bisected 2026-10-31): a function arg set `{ a, b, … }:` longer than `lineWidth` is wrapped into text the plugin cannot re-parse; multi-line arg sets fail outright. Darren.s plugin, github.com/darrenkuro/dprint-plugin-nix issue #1.
- **VSCode extension only formats under the discovered config's folder** — it never falls back to `~/.config/dprint/dprint.json` (the CLI does). Hence `dprint.json` lives at the repo ROOT; moving it under `configs/` silently kills format-on-save repo-wide.

## zsh alias-in-alias expansion (why functions use /bin/rm)

zsh re-expands aliases inside alias text AND inside function bodies at source time. With `rm` aliased to trash on mac, any `rm` there silently becomes `trash` — so `functions/*.sh` call `/bin/rm` explicitly.

## `git checkout -- <file>` reverts ALL uncommitted edits

When undoing a temporary tweak (e.g. a sed-uncommented toggle), stage the file's real changes first or undo with a second sed — checkout reverts to HEAD.

## `re` hangs non-interactively

`re` ends in `exec zsh`; from a script/background shell that becomes an interactive shell idling on a pipe — the switch succeeds but the process never exits. (Moot while rebuilds are manual-only.)
