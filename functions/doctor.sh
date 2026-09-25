INSTALL_TAG=(MAC)
REQUIRED_TOOLS=(jq)
_check_preamble || return 0

# doctor — verify per-machine state that hm can't fully manage.
# Companion checklist: docs/manual-setup.md (add new items there first,
# then a check here, then automate where possible).
doctor() {
    local _issues=0

    _header "hm doctor ($HM_PROFILE)"

    # --- Window tiling shortcuts (managed by modules/system/tiling-hotkeys.nix)
    local _pair _id _want _cur _bad=""
    for _pair in \
        "237 [92,42,786432]" \
        "240 [65535,123,9175040]" \
        "241 [65535,124,9175040]" \
        "242 [65535,126,9175040]" \
        "243 [65535,125,9175040]"; do
        _id=${_pair%% *}
        _want=${_pair#* }
        _cur=$(defaults export com.apple.symbolichotkeys - 2> /dev/null |
            plutil -extract "AppleSymbolicHotKeys.$_id.value.parameters" json -o - - 2> /dev/null)
        [ "$_cur" = "$_want" ] || _bad="$_bad $_id"
    done
    if [ -z "$_bad" ]; then
        _done "window tiling shortcuts (Fill + Halves)"
    else
        _skip "window tiling shortcuts (ids:$_bad)"
        _item "fix: git -C \$HM pull && re"
        _issues=$((_issues + 1))
    fi

    # --- Alfred: Powerpack license
    if [ -n "$(find "$HOME/Library/Application Support/Alfred" -maxdepth 1 -name 'powerpack.*.dat' 2> /dev/null | head -1)" ]; then
        _done "Alfred Powerpack license"
    else
        _skip "Alfred Powerpack license"
        _item "Alfred → Powerpack tab → enter license (in password manager)"
        _issues=$((_issues + 1))
    fi

    # --- Alfred: prefs folder on iCloud Documents (syncs workflows/settings)
    local _alfred_prefs
    _alfred_prefs=$(jq -r '.current // empty' "$HOME/Library/Application Support/Alfred/prefs.json" 2> /dev/null)
    if [ "$_alfred_prefs" = "$HOME/Documents/Alfred.alfredpreferences" ]; then
        _done "Alfred prefs folder → ~/Documents (iCloud-synced)"
    else
        _skip "Alfred prefs folder (${_alfred_prefs:-unset})"
        _item "Alfred → Advanced → Syncing → Set preferences folder → ~/Documents"
        _issues=$((_issues + 1))
    fi

    # --- Claude Code: installed + logged in (creds live in the keychain)
    if ! command -v claude > /dev/null 2>&1; then
        _skip "Claude Code binary"
        _item "fix: re (activation installs it)"
        _issues=$((_issues + 1))
    elif security dump-keychain 2> /dev/null | grep -q "Claude Code-credentials"; then
        _done "Claude Code installed + logged in"
    else
        _skip "Claude Code login"
        _item "run: claude → /login"
        _issues=$((_issues + 1))
    fi

    # --- GitHub CLI auth
    if gh auth status > /dev/null 2>&1; then
        _done "gh authenticated"
    else
        _skip "gh authentication"
        _item "run: gh auth login"
        _issues=$((_issues + 1))
    fi

    # --- Not machine-checkable — verify by hand (docs/manual-setup.md)
    _header "manual (not checkable)"
    _item "Brave Sync: brave://settings/braveSync/setup — join chain + enable 'Sync everything'"
    _item "Touch ID enrollment: System Settings → Touch ID (per-machine, Secure Enclave)"
    _item "App logins: Slack, Notion, iCloud, Dropbox, ..."

    printf '\n'
    if [ "$_issues" -eq 0 ]; then
        _done "all checks passed"
    else
        _skip "$_issues issue(s) need attention"
    fi
}
