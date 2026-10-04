INSTALL_TAG=(MAC LINUX)
INSTALL_PROFILE=(PERSONAL WORK)
REQUIRED_TOOLS=(git tokei)
_check_preamble || return 0

normalize_repo_url() {
    local input="$1"
    input="${input#"${input%%[![:space:]]*}"}" # trim leading space
    input="${input%"${input##*[![:space:]]}"}" # trim trailing space

    if [[ "$input" == https://github.com/* || "$input" == git@github.com:* ]]; then
        echo "$input"
    else
        input="${input#/}"    # trim leading slash
        input="${input%.git}" # trim .git suffix
        echo "https://github.com/$input"
    fi
}

gloc() {
    setopt localoptions nounset pipefail

    if [[ $# -lt 1 ]]; then
        echo "Usage: gloc <repo_url|user/repo>" >&2
        return 1
    fi

    local input="$1"
    local repo_url
    repo_url="$(normalize_repo_url "$input")"

    local tmp_dir
    tmp_dir="$(mktemp -d)"
    # zsh: function-local EXIT trap fires on function return, cleans up on early exits
    trap '/bin/rm -rf "$tmp_dir"' EXIT

    echo "📥 Cloning ${repo_url}..."
    if ! git clone --depth 1 "$repo_url" "$tmp_dir" > /dev/null 2>&1; then
        echo "❌ git clone failed for $repo_url" >&2
        return 1
    fi

    echo "📊 Running tokei..."
    if ! tokei "$tmp_dir"; then
        echo "❌ tokei failed" >&2
        return 1
    fi

    /bin/rm -rf "$tmp_dir"
    echo "🧹 Cleaned up $tmp_dir"
}
