# Since nix-profile paths are prepended to PATH, nix's man replaces the
# system one — but nix's man can't find Apple SDK manpages that macOS
# appends at runtime. The system /usr/bin/man can find manuals in both
# nix and system paths, so we alias it back on macOS.
{tag, lib, ...}:
lib.mkIf (tag == "mac") {
  programs.zsh.shellAliases = {
    "man" = "/usr/bin/man";
    "mandb" = "/usr/bin/mandb";
    "manpath" = "/usr/bin/manpath";
    "catman" = "/usr/bin/catman";
    "apropos" = "/usr/bin/apropos";
    "lexgrog" = "/usr/bin/lexgrog";
    "whatis" = "/usr/bin/whatis";
  };
}
