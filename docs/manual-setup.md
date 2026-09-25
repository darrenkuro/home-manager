# Manual Setup Checklist

Per-machine state that hm cannot (yet) fully manage. Run `doctor` (functions/doctor.sh)
anytime to verify the checkable items. Workflow: new manual step discovered → add it
here → add a `doctor` check if verifiable → automate it if possible and move it up.

## Status legend

- **automated** — hm applies it; nothing to do (listed for provenance)
- **checked** — `doctor` verifies it; the fix is manual
- **manual** — not machine-verifiable; do by hand on each new machine

## Items

| Item                                                | Scope        | Status                     | Notes                                                                                                                                                                                                             |
| --------------------------------------------------- | ------------ | -------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Window tiling: Fill + Halves (`⌃⌥\`, `⌃⌥←→↑↓`)      | mac          | automated                  | `modules/system/tiling-hotkeys.nix` (via `re`)                                                                                                                                                                    |
| sudo via Touch ID                                   | mac          | automated                  | `darwin.nix` pam (via `sure`)                                                                                                                                                                                     |
| Window tiling: Center, Return to Previous, Quarters | mac          | manual                     | candidate ids 238/239/244–247, see tiling-hotkeys.nix                                                                                                                                                             |
| Alfred Powerpack license                            | mac          | checked                    | Alfred → Powerpack tab → enter license                                                                                                                                                                            |
| Alfred prefs repo (`darrenkuro/alfred-workflows`)   | mac          | checked                    | private repo cloned to `~/Documents/Alfred.alfredpreferences`; Alfred → Advanced → Syncing points there; sync = manual git push/pull (doctor warns on drift)                                                      |
| Claude Code login                                   | mac          | checked                    | `claude` → `/login`                                                                                                                                                                                               |
| Claude Code plugins                                 | mac          | automated                  | `claudePlugins` activation auto-installs missing required plugins (warns on failure)                                                                                                                              |
| GitHub CLI auth                                     | all          | checked                    | `gh auth login`                                                                                                                                                                                                   |
| SSH key (one per machine, never copied)             | all          | checked                    | `~/.ssh/<sshKey>` per `flake.nix` `machines`; `ssh-keygen -t ed25519` (README). Register the .pub at: GitHub **Authentication** + **Signing** key; personal only: hetzner `deploy` authorized_keys, 42 intra (ft) |
| WakaTime API key                                    | all          | checked                    | secret, never in repo; `printf '[settings]\napi_key = <key>\n' > $WAKATIME_HOME/.wakatime.cfg` — key at <https://wakatime.com/api-key>                                                                            |
| Brave Sync chain + categories                       | mac          | manual                     | `brave://settings/braveSync/setup` → join chain, enable "Sync everything"; per browser profile                                                                                                                    |
| Touch ID enrollment                                 | mac          | manual                     | System Settings → Touch ID; fingerprints live in the Secure Enclave, never sync                                                                                                                                   |
| App logins (Slack, Notion, iCloud, Dropbox, …)      | per profile  | manual                     | per-site sessions never sync                                                                                                                                                                                      |
| App Management permission for terminal              | mac          | checked (activation warns) | System Settings → Privacy & Security                                                                                                                                                                              |
| Nix + nix-darwin bootstrap                          | all          | manual                     | first-install command in CLAUDE.md (`#mac` / `#mac-work`)                                                                                                                                                         |
| Homebrew install                                    | mac          | manual                     | <https://brew.sh> — required before first `sure`                                                                                                                                                                  |
| Apple Development cert in keychain                  | mac personal | manual                     | needed by BTM codesigning (`scripts/btm-patch-nix.sh`)                                                                                                                                                            |
