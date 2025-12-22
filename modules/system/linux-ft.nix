{ lib, ... }:
{
  programs.zsh.initContent = builtins.readFile ../../scripts/repeat-rate.sh;

  home.activation.configCopy =
    lib.hm.dag.entryAfter [ "writeBoundary" ]
      lib.concatStringsSep "\n"
      [
        (builtins.readFile ../../scripts/copy-files.sh)
        (builtins.readFile ../../scripts/unset-env.sh)
      ];

  programs.zsh.shellAliases = {
    re = "home-manager switch --flake ~/.config/home-manager#ft && exec zsh";
  };
}
