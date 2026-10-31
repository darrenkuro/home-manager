# TODO

- [ ] Suppress BTM "App Background Activity" notifications — `.mobileconfig` profile targeting `com.apple.btmnotificationagent` (only confirmed method; no `defaults write` exists)
- [ ] Dedup stale entries in Notification Settings — surgical dedup of `com.apple.ncprefs.plist` by `bundle-id` (keeps per-app prefs; `killall cfprefsd` after)
- [ ] Declare the remaining global keyboard shortcuts (see below)
- [ ] Telegram channel config in `claude.nix` activation — create `~/.claude/channels/telegram/`, seed `access.json` (pairing mode) + placeholder `.env` for the bot token. Open: secret management (placeholder vs agenix/sops-nix)
- [ ] Anki add-ons declaratively in hm + note-type CSS source of truth out of `german-anki` (see below)
- [ ] `tidy`: optional recursive `.DS_Store` sweep — `find "$DEV" "$DBOX" -name .DS_Store -type f -delete` (plain `find` is fine on local dirs; only the CloudStorage walk hung)

---

## Global keyboard shortcuts

Extend the `modules/system/tiling-hotkeys.nix` pattern (per-id `defaults write -dict-add`, never the whole `AppleSymbolicHotKeys` dict — that wipes undeclared ids). Fill + halves (237, 240–243) are done. Remaining state as of 2026-03-16:

- **Disabled:** 15–26 Mission Control / Spaces · 60 previous input source · 164 Notification Center · 176 Focus · 257–258 unknown
- **Enabled:** 61 next input source `[32,49,786432]` · 98 unknown Cmd+Ctrl+/ `[47,44,1179648]` · 233 unknown Cmd+M `[109,46,1048576]` · 238 `[39,39,786432]` · 239 `[114,15,786432]` · 244 `[117,32,786432]` · 245 `[105,34,786432]` · 246 `[106,38,786432]` · 247 `[107,40,786432]`
- Modifiers: `1048576` Cmd · `786432` Ctrl+Opt · `9175040` Fn+Ctrl+Opt · `1179648` Cmd+Ctrl · `262144` Ctrl
- Caveats: ids undocumented and may change across macOS versions; may need logout/login (or `/System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u`)
- Per-app menu shortcuts are a separate, safe mechanism: `system.defaults.CustomUserPreferences."<bundle id>".NSUserKeyEquivalents` (`@` Cmd, `^` Ctrl, `~` Opt, `$` Shift)

---

## Anki — declarative add-ons + CSS source of truth

Researched + drafted 2026-06-18, then reverted (archive the plan, don't apply). Facts verified against live Anki / GitHub / nixpkgs.

### Add-ons (per-device, NOT synced by AnkiWeb → hm is the right home)

- Folder `~/Library/Application Support/Anki2/addons21/<id>/`: `__init__.py` (entry) + `meta.json` (**activation switch** `{"name","disabled":false}`, **Anki writes it** for toggles/config) + `manifest.json` (AnkiWeb installs only). Numeric folder name = AnkiWeb id (convention).
- Installed on mac: `2055492159` AnkiConnect (manual install; required by the `anki` skill, `localhost:8765`), `1771074083` Review Heatmap.
- **COPY, don't symlink**: `home.file`/`xdg` and HM's `programs.anki` install read-only, so Anki can't write `meta.json` and the add-on UI goes inert (HM issue #8250). Use an activation script; Anki must be closed during the copy.
- Pins:
  - AnkiConnect: **FooSoft/anki-connect** (the `amikey` mirror is dead), rev `4064fa142785975255457abd6a496015f5b71f38`, hash `sha256-VxQ1Qu6GSdStnL/SCkzZazC3WI29hJA3Fco4ix2pOLQ=`; the add-on is the `plugin/` subdir.
  - Review Heatmap: raw GitHub source lacks the compiled `web/anki-review-heatmap.js` → copy from `pkgs.ankiAddons.review-heatmap` (`share/anki/addons/review-heatmap`).

Drafted `modules/apps/anki.nix` (import in `home.nix` mac list):

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
            if [ ! -f "$addons/$1/meta.json" ]; then  # write once; keeps UI config
                run echo '{"name":"'"$3"'","disabled":false}' > "$addons/$1/meta.json"
            fi
        }
        install_addon "2055492159" "${ankiconnect}/plugin" "AnkiConnect"
        install_addon "1771074083" "${reviewHeatmap}" "Review Heatmap"
    '';
}
```

### Note-type CSS (inside the synced `collection.anki2` → AnkiWeb propagates it)

- Canonical CSS/templates go in the skill: `claude-config/skills/anki/assets/notetypes/<model>/{style.css,Card1.front.html,…}` + `deploy.sh` — applied via AnkiConnect on demand, NOT a `home.activation` hook (needs Anki running).
- All 7 models (`basic, cloze, sentence, type-in, vocab, vocab-en, work`) share one byte-identical stylesheet = `german-anki/anki/styling.css`.
- `modelStyling`/`modelTemplates` take `modelName` (not `model`); `updateModelStyling` / `updateModelTemplates` take `{model:{name, css}}` / `{model:{name, templates:{"<Card>":{Front,Back}}}}`.
- Card templates: basic→forward,reverse,type-in · cloze→Cloze · sentence→meaning,word,pronunciation,dictation · type-in→type · vocab→meaning,word,pronunciation,type-in,gender · vocab-en→meaning,pronunciation,type-in · work→title,maker,maker+. german-anki only has cloze + vocab templates (no `gender`); the other 5 migrate CSS only.
- `deploy.sh` design: check `version` → styling to all models + templates per model; clear connection-refused message; `./deploy.sh <model...>` scoping. WRITE actions — review the diff before running.
- Conditional labels key off tags (`[data-tags~="..."]` vs `data-tags="{{Tags}}"`). Structural changes (add/remove field or card) force a one-way full sync; CSS/template-text edits merge normally.
