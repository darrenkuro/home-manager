# TODO

- [ ] Manage VSCode extensions via Nix (see implementation details below)
- [ ] Suppress BTM "App Background Activity" notifications — install `.mobileconfig` profile targeting `com.apple.btmnotificationagent` (only confirmed working method; no `defaults write` solution exists)
- [ ] Clean up duplicate/stale entries in Notification Settings — surgical dedup of `com.apple.ncprefs.plist` by `bundle-id` (preserves per-app prefs, needs `killall cfprefsd` after)
- [ ] Declare global keyboard shortcuts in `darwin.nix` (see implementation details below)
- [ ] Set up Telegram channel config in hm activation — create `~/.claude/channels/telegram/` dir, seed default `access.json` (pairing mode), and placeholder `.env` for bot token. Add to `claude.nix` activation (it owns all Claude config now, incl. the settings.json merge — copy-files.sh no longer handles Claude). Need to decide secret management for bot token (placeholder vs agenix/sops-nix).
- [ ] Manage Anki add-ons declaratively in hm + relocate note-type CSS source of truth out of `german-anki` (see implementation details below)

---

## Anki — declarative add-ons + CSS source of truth

### Overview

Two separate concerns, because AnkiWeb sync treats them differently:

- **Add-ons** are **per-device** (NOT synced by AnkiWeb) → manage declaratively in hm.
- **Note-type CSS/templates** live **inside the synced `collection.anki2` SQLite DB** and AnkiWeb already propagates them to every device → hm cannot manage them as files; an external `.css` is only a version-controlled source of truth, applied via AnkiConnect.

macOS data dir: `~/Library/Application Support/Anki2/`. Per-profile collection + media live under `<profile>/` (e.g. `Darren Kuro/`); add-ons under `addons21/`.

### Add-ons: how "installed + activated" actually works

Verified on-disk (2026-06-18). An add-on is just a folder under `~/Library/Application Support/Anki2/addons21/<id>/` containing:

- `__init__.py` — required entry point.
- `meta.json` — **the activation switch**: `{"name": "...", "disabled": false, ...}`. **Anki writes this file** (enable/disable toggles + user config overrides under a `config` key).
- `manifest.json` — present **only for AnkiWeb downloads** (records `ankiweb_id`, version, conflicts). Manual/git installs don't need it. The numeric folder name is just the AnkiWeb id (convention, lets updates/conflicts resolve); manual installs may use any name.

Current add-ons on mac:

- `2055492159` — **AnkiConnect** (manual install: has `meta.json` but **no** `manifest.json`). Required by the `anki` Claude skill (talks to `localhost:8765`).
- `1771074083` — **Review Heatmap** (Glutanimate; AnkiWeb install, has `manifest.json`).

### Add-ons: hm approach — COPY, don't symlink

The user's intuition is correct: hm can `fetchFromGitHub` the source, drop it in `addons21/<id>/`, and write `meta.json` to activate. **Gotcha:** `home.file`/`xdg` create **read-only** symlinks into the Nix store; Anki then can't write `meta.json` (enable/disable + config edits via Tools → Add-ons → Config), so the add-on manager UI goes inert. **Fix: copy (writable), not symlink**, via an activation script:

```nix
let
  ankiconnect = pkgs.fetchFromGitHub {
    owner = "amikey"; repo = "anki-connect"; rev = "..."; hash = "...";
  };
in {
  home.activation.ankiAddons = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    addons="$HOME/Library/Application Support/Anki2/addons21"
    install_addon() {  # $1=id  $2=src
      mkdir -p "$addons/$1"
      cp -R "$2"/. "$addons/$1/"           # copy = writable (NOT a store symlink)
      chmod -R u+w "$addons/$1"
      [ -f "$addons/$1/meta.json" ] || \   # write once; preserves UI config on rebuild
        echo '{"name":"'"$1"'","disabled":false}' > "$addons/$1/meta.json"
    }
    install_addon "2055492159" "${ankiconnect}"
  '';
}
```

- `[ -f meta.json ] ||` guard preserves config tweaked via the UI across rebuilds. To make config fully declarative instead, write the whole `meta.json` every activation and never edit config in the UI.
- Anki must be **closed** during the copy (it reads add-ons at startup); changes apply on next launch.

### Add-ons: packaged alternative

home-manager has an official `programs.anki` module (merged ~mid-2025): options incl. `addons`, `theme`, `uiScale`, `videoDriver`, `profiles.<name>.sync.keyFile`, etc. nixpkgs ships an `ankiAddons` set (`ankiAddons.anki-connect`, `review-heatmap`, …). Cleaner *if* the add-on is packaged — but it installs add-ons **read-only** (same UI-inert gotcha as `home.file`). For add-ons whose config we tweak, the copy-based activation script above is friendlier. Also weigh: is Anki itself installed via Nix (`anki`/`anki-bin`, both support darwin) or the official DMG? The activation-script approach works regardless of how Anki was installed.

### Note-type CSS: round-trip (separate from add-ons)

CSS is a string inside the notetype config in `collection.anki2` — not a file, and it **syncs via AnkiWeb automatically**. So:

- Do **not** keep CSS in `~/Documents/dev/german-anki/` (treated as a throwaway dir).
- Keep canonical CSS/templates as **git assets in the Claude skill**: `claude-config/skills/anki/assets/notetypes/<model>/{style.css,Card1.front.html,Card1.back.html}` + a `deploy.sh`. Co-located with the AnkiConnect tooling that applies it.
- Apply via a deploy command (NOT a `home.activation` hook — that would need Anki running + AnkiConnect listening during `darwin-rebuild`, fragile):

```sh
# git-tracked CSS -> running Anki (AnkiConnect) -> AnkiWeb sync -> all devices
curl -s localhost:8765 -d "$(jq -n --arg css "$(cat style.css)" \
  '{action:"updateModelStyling",version:6,params:{model:{name:"cloze",css:$css}}}')"
# templates: action "updateModelTemplates" with {name, templates:{"Card 1":{Front,Back}}}
```

Conditional template labels key off **tags** via `[data-tags~="..."]` against `data-tags="{{Tags}}"` (not decks).

### Known gotchas / facts

- Add-ons NOT synced (per-device → hm is the right home); CSS/media ARE synced (collection).
- Structural notetype changes (add/remove field or card template) force a one-way full sync with a conflict prompt; pure CSS/template-text edits merge normally.
- The `anki` skill's audit section no longer references `german-anki` (rule 3 removed 2026-06-18); this todo is the replacement plan for the CSS source of truth.

### Verified findings (2026-06-18) — researched + drafted, then reverted (user wanted plan archived, not applied)

All facts below verified against live Anki / GitHub / nixpkgs. Drop-in ready when revisited.

**Add-on pins** (got via `nix run nixpkgs#nix-prefetch-github`; hashes realize cleanly):

- **AnkiConnect** (`2055492159`): canonical repo is **FooSoft/anki-connect** (archived but current, HEAD 2025-11-04). The `amikey` mirror in the example above is **DEAD** (last touched 2018) — do NOT use it.
  - rev `4064fa142785975255457abd6a496015f5b71f38`
  - hash `sha256-VxQ1Qu6GSdStnL/SCkzZazC3WI29hJA3Fco4ix2pOLQ=`
  - loadable add-on is the `plugin/` **subdir** (pure Python, no build) → copy `${src}/plugin`.
- **Review Heatmap** (`1771074083`): glutanimate/review-heatmap, tag v1.0.1, rev `5ab7964ac5bbab33358ef9cd5dd4f31517f43e48`, hash `sha256-B2Qe7B0BlZaO0Ap7wRkAKeAAIAUPCAF87fyPrMzPbkY=`.
  - **GOTCHA:** runtime needs `web/anki-review-heatmap.js`, a **compiled** artifact (built from `src/web/main.ts`) that is **NOT in the git tree**, and there are no GitHub release assets. A raw `fetchFromGitHub` installs but the heatmap won't render. **Use `pkgs.ankiAddons.review-heatmap` (v1.0.1 in nixpkgs) as the copy source** — it ships the built JS at `share/anki/addons/review-heatmap/web/`.

Both `ankiAddons.anki-connect` (25.11.9.0) and `ankiAddons.review-heatmap` (1.0.1) exist in current nixpkgs.

**The drafted module** (`modules/apps/anki.nix`, imported in `home.nix` `tag == "mac"` list):

```nix
{ pkgs, lib, ... }: let
    ankiconnect = pkgs.fetchFromGitHub {
        owner = "FooSoft"; repo = "anki-connect";
        rev = "4064fa142785975255457abd6a496015f5b71f38";
        hash = "sha256-VxQ1Qu6GSdStnL/SCkzZazC3WI29hJA3Fco4ix2pOLQ=";
    };
    reviewHeatmap = "${pkgs.ankiAddons.review-heatmap}/share/anki/addons/review-heatmap";
in {
    home.activation.ankiAddons = lib.hm.dag.entryAfter ["writeBoundary"] ''
        addons="$HOME/Library/Application Support/Anki2/addons21"
        install_addon() {  # $1=id  $2=src  $3=display name
            run mkdir -p "$addons/$1"
            run cp -R "$2"/. "$addons/$1/"
            run chmod -R u+w "$addons/$1"
            if [ ! -f "$addons/$1/meta.json" ]; then
                run echo '{"name":"'"$3"'","disabled":false}' > "$addons/$1/meta.json"
            fi
        }
        install_addon "2055492159" "${ankiconnect}/plugin" "AnkiConnect"
        install_addon "1771074083" "${reviewHeatmap}" "Review Heatmap"
    '';
}
```

**Live collection facts** (read-only `modelNames`/`modelStyling`/`modelTemplates`):

- Models: `basic, cloze, sentence, type-in, vocab, vocab-en, work` — **all 7 share one byte-identical stylesheet**, equal to `german-anki/anki/styling.css` (only diff: a trailing newline). So `assets/notetypes/style.css` = one shared sheet applied to every model.
- `modelStyling`/`modelTemplates` take param `modelName` (NOT `model` — that errors).
- Card template names per model: basic→forward,reverse,type-in · cloze→Cloze · sentence→meaning,word,pronunciation,dictation · type-in→type · vocab→meaning,word,pronunciation,type-in,gender · vocab-en→meaning,pronunciation,type-in · work→title,maker,maker+.
- german-anki only has templates for **cloze** + **vocab** (cloze-front/back→`Cloze`; vocab meaning/word/pronunciation→same, type-front/back→`type-in`; no `gender` source). The other 5 models migrate CSS only.
- `deploy.sh` design: verify `version` → POST `updateModelStyling` (shared css to all models) + `updateModelTemplates` per model `{model:{name, templates:{"<Card>":{Front,Back}}}}`. Robust jq/curl checks, clear connection-refused message, `./deploy.sh <model...>` scoping. (WRITE actions — review diff before running.)

### Sources

- AnkiWeb sync / files: https://docs.ankiweb.net/syncing.html · https://docs.ankiweb.net/files.html
- Add-on folder layout: https://addon-docs.ankiweb.net/addon-folders.html
- home-manager `programs.anki` options; nixpkgs `ankiAddons`; HM issue #8250 (read-only add-on meta.json limitation)
- AnkiConnect API (`updateModelStyling`/`updateModelTemplates`): https://git.sr.ht/~foosoft/anki-connect

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
