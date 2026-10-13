# Since nix-profile paths are prepended to PATH, nix's man replaces the
# system one — but nix's man can't find Apple SDK manpages that macOS
# appends at runtime. The system /usr/bin/man can find manuals in both
# nix and system paths, so we alias it back on macOS. Only commands macOS
# ships are aliased: its man is FreeBSD's (index via makewhatis), so man-db's
# mandb/catman/lexgrog have no /usr/bin counterpart and stay nix's.
{ tag, lib, ... }:
lib.mkIf ( tag == "mac" ) {
    programs.zsh.shellAliases = {
        "man" = "/usr/bin/man";
        "manpath" = "/usr/bin/manpath";
        "apropos" = "/usr/bin/apropos";
        "whatis" = "/usr/bin/whatis";
    };
}
