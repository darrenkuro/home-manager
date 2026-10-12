INSTALL_TAG=(MAC)
REQUIRED_TOOLS=(docker)
_check_preamble || return 0

# lman [section] <page>
# Linux man pages as the 42 piscine machines see them (Fedora 44), on the Mac
# whose own `man` shows the BSD versions. Runs man in a small Fedora 44 image,
# built on first use (Fedora images strip docs by default, hence the rebuild).
#
# Examples:
#   lman write        # write(2), the Linux one
#   lman 3 printf
#   lman -k strcpy    # search the index
lman() {
    if [ $# -eq 0 ]; then
        echo "usage: lman [section] <page>   (lman -k <word> to search)" >&2
        return 1
    fi
    local image=fedora44-man
    if ! docker image inspect "$image" > /dev/null 2>&1; then
        echo "lman: building $image (first run)…" >&2
        docker build -q -t "$image" - > /dev/null << 'DOCKERFILE' || return 1
FROM fedora:44
RUN sed -i '/tsflags=nodocs/d' /etc/dnf/dnf.conf \
 && dnf -y install man-db man-pages util-linux less && dnf clean all && mandb -q
DOCKERFILE
    fi
    local tty=()
    [ -t 0 ] && [ -t 1 ] && tty=(-it) # pager when interactive, plain text in a pipe
    docker run --rm "${tty[@]}" -e MANWIDTH="${COLUMNS:-80}" -e LANG=C.UTF-8 "$image" man "$@"
}
