INSTALL_TAG=(MAC)
INSTALL_PROFILE=(PERSONAL)
REQUIRED_TOOLS=(swiftc)
_check_preamble || return 0

# dropbox-sync — the Dropbox counterpart of icloud-sync.sh: ask the Dropbox desktop app to make
# files online-only (free the disk, keep a 0-byte placeholder) or available offline (download
# and keep), and report their sync state, from the shell or a script.
#
#   dbx-status <path>...              one line per path:  <state><TAB><path>
#   dbx-cloud  [-w] [-t secs] <path>...   make online-only (Finder: "Make online-only")
#   dbx-local  [-w] [-t secs] <path>...   download again and keep (Finder: "Download now")
#
# dbx-cloud asks the Dropbox app, exactly like the Finder menu; -w waits until Dropbox reports the
# new state (up to -t seconds, default 600). dbx-local downloads synchronously (it reads the
# placeholder, which makes File Provider fetch it), so it returns when the file is back. Folders
# apply recursively. States: online-only, offline (downloaded and kept), local (downloaded),
# syncing, mixed, error, ignored, locked, none (not in Dropbox). Exit 0 done, 1 some path failed /
# not offered / timed out, 69 Dropbox app not running. Dropbox refuses to evict a file it is still
# uploading, so a fresh file reports "not offered (syncing)" until the upload finishes — wait and
# retry, or check dbx-status first. DBX_SYNC_DEBUG=1 dumps the raw menu Dropbox returns.
#
# How it works and what it relies on (an undocumented Dropbox protocol): see the header of
# functions/dropbox-sync.swift. Personal profile only: Dropbox is not installed on the work iMac.
#
# Build: the Swift source is compiled once into $XDG_CACHE_HOME/dropbox-sync/ and rebuilt when
# the source is newer than the binary. `swift file.swift` script mode would need no build step
# but costs ~3 s per call; the compiled binary answers in ~0.4 s. It needs the Xcode Command
# Line Tools' swiftc; a Nix derivation can't see Apple's frameworks, hence the lazy build.
#
# Example — compress a video, then free the disk once Dropbox has uploaded the result:
#   vcompress movie.mp4 && dbx-cloud -w movie.x265crf28.mp4

_dbx_sync() {
    local src="$HM/functions/dropbox-sync.swift"
    local dir="${XDG_CACHE_HOME:-$HOME/.cache}/dropbox-sync" bin
    bin="$dir/dbx-sync"
    if [[ ! -x "$bin" || "$src" -nt "$bin" ]]; then
        mkdir -p "$dir"
        if ! swiftc -O -o "$bin" "$src" 2> "$dir/build.log"; then
            echo "dropbox-sync: build failed, see $dir/build.log" >&2
            return 1
        fi
    fi
    "$bin" "$@"
}

dbx-status() { _dbx_sync status "$@"; }
dbx-cloud() { _dbx_sync online "$@"; }
dbx-local() { _dbx_sync offline "$@"; }
