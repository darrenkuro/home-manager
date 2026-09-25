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

    # --- Alfred: prefs folder = the private alfred-workflows git repo
    local _alfred_dir="$HOME/Documents/Alfred.alfredpreferences"
    local _alfred_prefs
    _alfred_prefs=$(jq -r '.current // empty' "$HOME/Library/Application Support/Alfred/prefs.json" 2> /dev/null)
    if [ ! -d "$_alfred_dir/.git" ]; then
        _skip "Alfred prefs repo missing"
        _item "run: git clone git@github.com:darrenkuro/alfred-workflows.git '$_alfred_dir'"
        _issues=$((_issues + 1))
    elif [ "$_alfred_prefs" != "$_alfred_dir" ]; then
        _skip "Alfred prefs folder (${_alfred_prefs:-unset})"
        _item "Alfred → Advanced → Syncing → Set preferences folder → ~/Documents/Alfred.alfredpreferences"
        _issues=$((_issues + 1))
    elif [ -n "$(git -C "$_alfred_dir" status --porcelain 2> /dev/null | head -1)" ] ||
        [ -n "$(git -C "$_alfred_dir" log --oneline @{upstream}.. 2> /dev/null | head -1)" ]; then
        _skip "Alfred prefs repo has unsynced changes"
        _item "commit/push in ~/Documents/Alfred.alfredpreferences (and pull on the other Mac)"
        _issues=$((_issues + 1))
    else
        _done "Alfred prefs repo (git-synced, clean)"
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

    # --- SSH key: per machine (flake.nix `machines.<m>.sshKey`), used for GitHub
    # auth + commit signing and the hetzner deploy user. Read the effective path
    # from git so this check can't drift from git.nix.
    local _key
    _key=$(git config --get user.signingKey)
    _key=${_key/#\~/$HOME}
    if [ -f "$_key" ]; then
        _done "ssh key present (${_key/#$HOME/~})"
    else
        _skip "ssh key (${_key/#$HOME/~} missing)"
        _item "run: ssh-keygen -t ed25519 -f ${_key%.pub} (README) — or fix sshKey for this machine in flake.nix"
        _issues=$((_issues + 1))
    fi
    if ssh -o BatchMode=yes -o ConnectTimeout=5 -T git@github.com 2>&1 | grep -q "successfully authenticated"; then
        _done "GitHub SSH auth"
    else
        _skip "GitHub SSH auth"
        _item "GitHub → Settings → SSH and GPG keys → New SSH key → Authentication Key (pbcopy < $_key)"
        _issues=$((_issues + 1))
    fi
    # Signing-key registration is what makes commits show "Verified"; needs the
    # read:ssh_signing_key scope on the gh token.
    if gh api user/ssh_signing_keys --jq '.[].key' 2> /dev/null | grep -qF "$(cut -d' ' -f1,2 "$_key" 2> /dev/null)"; then
        _done "GitHub signing key registered"
    else
        _skip "GitHub signing key registration"
        _item "GitHub → Settings → SSH and GPG keys → New SSH key → Signing Key (pbcopy < $_key)"
        _item "if already added: gh auth refresh -s read:ssh_signing_key (lets doctor verify it)"
        _issues=$((_issues + 1))
    fi
    # Personal server — the work profile never needs it
    if [ "$HM_PROFILE" = PERSONAL ]; then
        if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new hetzner true 2> /dev/null; then
            _done "hetzner ssh (deploy)"
        else
            _skip "hetzner ssh (deploy)"
            _item "append $_key to deploy's ~/.ssh/authorized_keys on hetzner (from an already-authorized machine)"
            _issues=$((_issues + 1))
        fi
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
