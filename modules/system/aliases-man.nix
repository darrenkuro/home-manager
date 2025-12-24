/*
  Since nix-profile are prepended to the very beginning of path,
  man is replaced as well, and nix does not know SDK env that apple
  append at runtime; the system ones /usr/bin/man can find any manual
  in nix env though, so this setup should be ideal.
  Decided not to switch the order in PATH since we could change cmd that is
  in /usr/bin for consistency across system in the future such as grep.
*/
{ ... }:
{
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
