# TODO

- [ ] Manage VSCode extensions via Nix (see implementation details below)
- [ ] Suppress BTM "App Background Activity" notifications — install `.mobileconfig` profile targeting `com.apple.btmnotificationagent` (only confirmed working method; no `defaults write` solution exists)
- [ ] Clean up duplicate/stale entries in Notification Settings — surgical dedup of `com.apple.ncprefs.plist` by `bundle-id` (preserves per-app prefs, needs `killall cfprefsd` after)
- [ ] Declare global keyboard shortcuts in `darwin.nix` (see implementation details below)
- [ ] Set up Telegram channel config in hm activation — create `~/.claude/channels/telegram/` dir, seed default `access.json` (pairing mode), and placeholder `.env` for bot token. Add to `claude.nix` activation (it owns all Claude config now, incl. the settings.json merge — copy-files.sh no longer handles Claude). Need to decide secret management for bot token (placeholder vs agenix/sops-nix).

---

## Declarative Global Keyboard Shortcuts

### Overview

Persist custom macOS global keyboard shortcuts (System Settings > Keyboard > Keyboard Shortcuts) in `darwin.nix` so they survive a fresh install.

### Why not `CustomUserPreferences`?

`system.defaults.CustomUserPreferences` uses `defaults write domain key value` — the three-argument form. For `com.apple.symbolichotkeys`, the entire `AppleSymbolicHotKeys` dict is a single top-level key. Writing it **replaces the whole dict**, wiping any IDs not specified. This means you'd need to declare every single ID (hundreds, and they vary by macOS version) — brittle and unmaintainable.

### Recommended approach: `plutil` in activation script

Use `system.activationScripts.postActivation.text` (already used in `darwin.nix`) with `plutil -replace` for surgical per-key edits:

```bash
# Disable a shortcut
plutil -replace AppleSymbolicHotKeys.15.enabled -bool false \
  ~/Library/Preferences/com.apple.symbolichotkeys.plist

# Set a shortcut with specific key combo
plutil -replace AppleSymbolicHotKeys.237.enabled -bool true \
  ~/Library/Preferences/com.apple.symbolichotkeys.plist
plutil -replace AppleSymbolicHotKeys.237.value.parameters -json '[92,42,786432]' \
  ~/Library/Preferences/com.apple.symbolichotkeys.plist
plutil -replace AppleSymbolicHotKeys.237.value.type -string standard \
  ~/Library/Preferences/com.apple.symbolichotkeys.plist
```

`plutil` is in `$PATH` (`/usr/bin/plutil`), standard Apple tool, cleaner CLI than PlistBuddy for simple key-value edits.

### Why not PlistBuddy?

Both work, but PlistBuddy lives in `/usr/libexec/` (not in `$PATH`), uses a colon-separated path syntax, and is better suited for array manipulation (used in BTM patching). `plutil` is cleaner for the flat key-value edits needed here.

### IDs to persist (current state as of 2026-03-16)

**Disabled shortcuts:**

- 15-26 — Mission Control / Spaces (all disabled)
- 60 — Previous input source (disabled)
- 164 — Show Notification Center (disabled)
- 176 — Focus mode (disabled)
- 257-258 — Unknown (disabled)

**Enabled shortcuts:**

- 61 — Next input source: Ctrl+Opt+Space `[32, 49, 786432]`
- 98 — Unknown: Cmd+Ctrl+/ `[47, 44, 1179648]`
- 233 — Unknown: Cmd+M `[109, 46, 1048576]`
- 237 — Window tiling: Ctrl+Opt+\ `[92, 42, 786432]`
- 238 — Window tiling: Ctrl+Opt+' `[39, 39, 786432]`
- 239 — Window tiling: Ctrl+Opt+R `[114, 15, 786432]`
- 240-243 — Window tiling: Fn+Ctrl+Opt+Arrow keys `[_, key, 9175040]`
- 244 — Window tiling: Ctrl+Opt+U `[117, 32, 786432]`
- 245 — Window tiling: Ctrl+Opt+I `[105, 34, 786432]`
- 246 — Window tiling: Ctrl+Opt+J `[106, 38, 786432]`
- 247 — Window tiling: Ctrl+Opt+K `[107, 40, 786432]`

### Parameter format

`parameters = [ascii_code, virtual_keycode, modifier_flags]`

- Modifier flags: `1048576` = Cmd, `786432` = Ctrl+Opt, `9175040` = Fn+Ctrl+Opt, `1179648` = Cmd+Ctrl, `262144` = Ctrl

### Caveats

- Symbolic hotkey IDs are undocumented by Apple — community-maintained mappings only
- Changes typically require **logout/login** to take effect
- Running `activateSettings -u` may help for some settings: `/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u`
- IDs may change across major macOS versions

### Per-app shortcuts (separate concern)

Per-app menu shortcuts (e.g. remap "Quit Safari") use a different mechanism — `NSUserKeyEquivalents` in each app's plist. These _can_ safely use `CustomUserPreferences` since each app's dict is independent:

```nix
system.defaults.CustomUserPreferences."com.apple.Safari".NSUserKeyEquivalents = {
  "Quit Safari" = "@^q";  # @ = Cmd, ^ = Ctrl, ~ = Opt, $ = Shift
};
```

---

## VSCode Extensions via Nix

### Overview

Use `nix-vscode-extensions` flake (nix-community, 363 stars, daily bot updates at 3am UTC, ~80k extensions vs ~456 in nixpkgs) with home-manager's `programs.vscode.extensions`. Extensions are pinned to flake.lock — update via `nix flake update nix-vscode-extensions && re`.

### Step 1: Add flake input

**File**: `flake.nix`

```nix
inputs = {
  # ... existing inputs
  nix-vscode-extensions.url = "github:nix-community/nix-vscode-extensions";
};
```

Pass it through to home-manager modules like other inputs (`claude-config`, etc.).

### Step 2: Apply overlay to pkgs

Either in `flake.nix` where pkgs is constructed, or via a module:

```nix
nixpkgs.overlays = [ nix-vscode-extensions.overlays.default ];
```

This adds `pkgs.vscode-marketplace` and `pkgs.open-vsx` attrsets.

### Step 3: Declare extensions

**File**: `modules/apps/vscode.nix` (NEW — or inline in `home.nix`)

```nix
programs.vscode = {
  enable = true;
  package = pkgs.vscode;  # or keep manual Homebrew install
  mutableExtensionsDir = true;  # default — allows manual installs alongside Nix ones
  extensions = with pkgs.vscode-marketplace; [
    dprint.dprint
    jnoortheen.nix-ide
    github.github-vscode-theme
    pkief.material-icon-theme
    ms-python.python
    rust-lang.rust-analyzer
    # ... list current extensions
  ];
};
```

Extension names are lowercased `<publisher>.<name>`.

### Step 4: Reconcile settings strategy

**Problem**: Currently `copy-files.sh` does `envsubst < vscode-settings.jsonc > settings.json` (full overwrite). Enabling `programs.vscode` would want to own `settings.json` as a Nix-managed file too.

**Options**:

1. **Migrate settings to Nix** — use `programs.vscode.userSettings = { ... }` and delete the copy-files.sh VSCode block. Settings become read-only symlinks (can't edit in VSCode UI, must edit Nix).
2. **Keep copy-in-place for settings, only use programs.vscode for extensions** — don't set `programs.vscode.userSettings`, only set `.extensions`. The module may still conflict with the copy-files.sh settings path.
3. **Hybrid** — use `programs.vscode.userSettings` as source of truth but use `mkOutOfStoreSymlink` or similar to keep it editable.

**Recommended**: Option 1 (full Nix). The settings file is already Nix-managed via copy-files.sh anyway — making it a proper Nix attrset is cleaner and enables type checking. Remove the VSCode block from `copy-files.sh`.

### Step 5: Update extensions

```bash
nix flake update nix-vscode-extensions && re
```

### Known gotchas

- `config.allowUnfree = true` may be needed (open issue #180)
- Extension packs don't auto-expand — list each extension individually
- Extensions that write to their own dir (e.g., vscode-lldb) may break as Nix store paths
- "Extensions modified on disk" popup after `re` (harmless, issue #2981)
- Last human commit to nix-vscode-extensions: Oct 7, 2025 — repo is on autopilot (stable but low active development)
