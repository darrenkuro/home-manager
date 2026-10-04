# travel.sh — portable shell kit for machines that aren't mine.
#
#   source <(curl -fsSL https://raw.githubusercontent.com/darrenkuro/home-manager/main/travel.sh)
#
# One command = aliases + functions + starship with my real config.
# Missing tools are fetched as static builds into a per-user /tmp cache
# (survives shells, gone on reboot, nothing written to $HOME). Run
# `travel-install` to persist cache + config to ~/.local/bin instead.
# Works in bash and zsh; binary fetch is Linux x86_64/aarch64 only.

_DK_RAW=https://raw.githubusercontent.com/darrenkuro/home-manager/main
_DK_DIR="/tmp/dktravel-$(id -u)"
mkdir -p "$_DK_DIR/bin"

case ":$PATH:" in
    *":$_DK_DIR/bin:"*) ;;
    *) export PATH="$_DK_DIR/bin:$HOME/.local/bin:$PATH" ;;
esac

# ── Fetch static binaries into $1, skipping tools already reachable
_dk_fetch() {
    [ "$(uname -s)" = "Linux" ] || {
        echo "dk: binary fetch is Linux-only" >&2
        return 1
    }
    local dest=$1 arch tmp spec repo pattern name url
    arch=$(uname -m) # x86_64 | aarch64
    mkdir -p "$dest"
    tmp=$(mktemp -d)

    # starship + jq publish version-less assets; grab them directly
    if ! command -v starship > /dev/null 2>&1; then
        curl -fsSL "https://github.com/starship/starship/releases/latest/download/starship-$arch-unknown-linux-musl.tar.gz" |
            tar -xzf - -C "$dest" starship && echo "dk: starship → $dest"
    fi
    if ! command -v jq > /dev/null 2>&1; then
        curl -fsSL -o "$dest/jq" \
            "https://github.com/jqlang/jq/releases/latest/download/jq-linux-$([ "$arch" = x86_64 ] && echo amd64 || echo arm64)" &&
            chmod +x "$dest/jq" && echo "dk: jq → $dest"
    fi

    # the rest embed versions in asset names; resolve via the GitHub API
    for spec in \
        "eza-community/eza|${arch}-unknown-linux-musl.tar.gz|eza" \
        "sharkdp/fd|${arch}-unknown-linux-musl.tar.gz|fd" \
        "sharkdp/bat|${arch}-unknown-linux-musl.tar.gz|bat" \
        "junegunn/fzf|linux_$([ "$arch" = x86_64 ] && echo amd64 || echo arm64).tar.gz|fzf"; do
        repo=${spec%%|*}
        pattern=$(printf '%s' "$spec" | cut -d'|' -f2)
        name=${spec##*|}
        command -v "$name" > /dev/null 2>&1 && continue
        url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" |
            grep -o "https://[^\"]*$pattern" | head -1)
        if [ -z "$url" ]; then
            echo "dk: skip $name (no asset matching $pattern)" >&2
            continue
        fi
        curl -fsSL "$url" | tar -xzf - -C "$tmp" &&
            find "$tmp" -type f -name "$name" -exec mv {} "$dest/$name" \; &&
            chmod +x "$dest/$name" && echo "dk: $name → $dest"
    done
    /bin/rm -rf "$tmp"
}

# ── Auto-provision the /tmp cache: fetch whatever this box is missing
if [ "$(uname -s)" = "Linux" ]; then
    for _dk_t in starship eza fd bat fzf jq; do
        if ! command -v "$_dk_t" > /dev/null 2>&1; then
            _dk_fetch "$_DK_DIR/bin"
            break
        fi
    done
    unset _dk_t
fi

# ── My starship config (same file my machines use via starship.nix)
if [ ! -s "$_DK_DIR/starship.toml" ]; then
    curl -fsSL "$_DK_RAW/configs/starship.toml" -o "$_DK_DIR/starship.toml" 2> /dev/null
fi
[ -s "$_DK_DIR/starship.toml" ] && export STARSHIP_CONFIG="$_DK_DIR/starship.toml"
export STARSHIP_CACHE="$_DK_DIR/cache" # keep starship's session logs out of $HOME

# ── travel-install: persist the kit to ~/.local/bin + ~/.config
travel-install() {
    mkdir -p "$HOME/.local/bin"
    find "$_DK_DIR/bin" -maxdepth 1 -type f -exec cp -f {} "$HOME/.local/bin/" \;
    _dk_fetch "$HOME/.local/bin"
    if [ -s "$_DK_DIR/starship.toml" ]; then
        mkdir -p "$HOME/.config"
        cp -f "$_DK_DIR/starship.toml" "$HOME/.config/starship.toml"
    fi
    echo "dk: persisted to ~/.local/bin (add it to PATH in your rc if keeping)"
}

# ── Aliases (subset of modules/system/aliases.nix that makes sense anywhere)
if command -v eza > /dev/null 2>&1; then
    alias ls='eza --icons'
else
    alias ls='ls --color=auto'
fi
alias objdump='objdump --disassembler-options=intel'

# ── Functions (portable subset of functions/*.sh, preamble inlined away)
pull() {
    git clone "git@github.com:darrenkuro/$1.git" "${2:-$1}" && cd "${2:-$1}" || return
}

run() {
    if ! command -v cc > /dev/null 2>&1; then
        echo "run: no C compiler on this box" >&2
        return 1
    fi
    if [ $# -eq 0 ]; then
        cc -Wall -Wextra -Werror -x c <(grep -hv "////" ./*.c)
    else
        cc -Wall -Wextra -Werror -x c <(grep -v "////" "$1")
    fi
    ./a.out "${@:2}"
    local ret=$?
    /bin/rm a.out
    return $ret
}

clean() {
    /bin/rm -rf "$HOME/.cache" "$HOME/.npm" "$HOME/.lesshst"
    /bin/rm -f "$HOME/.DS_Store"
    echo "clean: done (minimal scrub)"
}

# ── Prompt
if command -v starship > /dev/null 2>&1; then
    if [ -n "${ZSH_VERSION-}" ]; then
        eval "$(starship init zsh)"
    elif [ -n "${BASH_VERSION-}" ]; then
        eval "$(starship init bash)"
    fi
fi
