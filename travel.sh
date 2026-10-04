# travel.sh — portable shell kit for machines that aren't mine.
#
#   source <(curl -fsSL https://raw.githubusercontent.com/darrenkuro/home-manager/main/travel.sh)
#
# Works in bash and zsh. Aliases and functions degrade gracefully when a
# tool is missing; run `travel-install` once to drop static builds of
# starship/eza/fd/bat/fzf/jq into ~/.local/bin (Linux only).

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

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

# ── travel-install: static binaries into ~/.local/bin (no root, Linux)
travel-install() {
    [ "$(uname -s)" = "Linux" ] || {
        echo "travel-install: Linux only" >&2
        return 1
    }
    local arch bin="$HOME/.local/bin" tmp
    arch=$(uname -m) # x86_64 | aarch64
    mkdir -p "$bin"
    tmp=$(mktemp -d)

    # starship + jq publish version-less assets; grab them directly
    curl -fsSL "https://github.com/starship/starship/releases/latest/download/starship-$arch-unknown-linux-musl.tar.gz" |
        tar -xzf - -C "$bin" starship && echo "installed: starship"
    curl -fsSL -o "$bin/jq" \
        "https://github.com/jqlang/jq/releases/latest/download/jq-linux-$([ "$arch" = x86_64 ] && echo amd64 || echo arm64)" &&
        chmod +x "$bin/jq" && echo "installed: jq"

    # the rest embed versions in asset names; resolve via the GitHub API
    local spec repo pattern name url
    for spec in \
        "eza-community/eza|${arch}-unknown-linux-musl.tar.gz|eza" \
        "sharkdp/fd|${arch}-unknown-linux-musl.tar.gz|fd" \
        "sharkdp/bat|${arch}-unknown-linux-musl.tar.gz|bat" \
        "junegunn/fzf|linux_$([ "$arch" = x86_64 ] && echo amd64 || echo arm64).tar.gz|fzf"; do
        repo=${spec%%|*}
        pattern=$(printf '%s' "$spec" | cut -d'|' -f2)
        name=${spec##*|}
        url=$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest" |
            grep -o "https://[^\"]*$pattern" | head -1)
        if [ -z "$url" ]; then
            echo "skip: $name (no asset matching $pattern)" >&2
            continue
        fi
        curl -fsSL "$url" | tar -xzf - -C "$tmp" &&
            find "$tmp" -type f -name "$name" -exec mv {} "$bin/$name" \; &&
            chmod +x "$bin/$name" && echo "installed: $name"
    done
    /bin/rm -rf "$tmp"
}

# ── Prompt
if command -v starship > /dev/null 2>&1; then
    if [ -n "${ZSH_VERSION-}" ]; then
        eval "$(starship init zsh)"
    elif [ -n "${BASH_VERSION-}" ]; then
        eval "$(starship init bash)"
    fi
fi
