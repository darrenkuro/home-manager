# macOS ships a working man (FreeBSD's man.sh + mandoc, index via makewhatis)
# that already finds nix manpages through PATH. GNU man-db from nixpkgs breaks
# apropos/whatis on darwin and can't see the Apple SDK pages, so don't install
# it there. enable stays on: it still installs the "man" outputs of packages.
# Upstream default since home-manager#8723, but only for stateVersion >= 26.05.
{ tag, lib, ... }: lib.mkIf ( tag == "mac" ) { programs.man.package = null; }
