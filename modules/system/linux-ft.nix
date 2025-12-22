{lib, ...}: {
  programs.zsh.initContent = builtins.readFile ../../scripts/repeat-rate.sh;

  # Copy user setting, not symlink, to make it usable outside of nix env
  home.activation.configCopy =
    lib.hm.dag.entryAfter [
      "writeBoundary"
    ]
    builtins.readFile
    ../../scripts/ft-copy-files.sh;

  programs.zsh.shellAliases = {
    re = "home-manager switch --flake ~/.config/home-manager#ft && exec zsh";
  };
}
