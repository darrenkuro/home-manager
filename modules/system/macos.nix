{ lib, ... }: {
  # home.file."Library/Fonts/NixNerdFonts".source = "${pkgs.nerd-fonts.fira-code}/share/fonts";

  # Copy user setting, not symlink, to make it usable
  home.activation.configCopy =
    lib.hm.dag.entryAfter [ "writeBoundary" ]
      (lib.concatStringsSep "\n"
      [
        (builtins.readFile ../../scripts/copy-files.sh)
        (builtins.readFile ../../scripts/unset-env.sh)
      ]);

  xdg.configFile."tmux/tmux.conf" = {
    source = ../../configs/tmux.conf;
  };

  programs.zsh.shellAliases = {
    dbox = "cd $DBOX";

    cloc = "tokei";
    re = "home-manager switch --flake ~/.config/home-manager#mac && exec zsh";

    hide = "chflags hidden";
    unhide = "chflags nohidden";
    rm = "echo \"☠️$YELLOW DANGEROUS CMD: using trash instread!$RESET\" && trash";

    readme = "cat $HM/templates/README.md | pbcopy";
    gig = "cat $HM/templates/.gitignore | pbcopy";

    ijs = "echo '![JavaScript](https://img.shields.io/badge/-JavaScript-f7df1e?style=flat-square&logo=JavaScript&logoColor=black)' | pbcopy";
    its = "echo '![TypeScript](https://img.shields.io/badge/-TypeScript-3178c6?style=flat-square&logo=TypeScript&logoColor=white)' | pbcopy";
    ic = "echo '![C](https://img.shields.io/badge/-C-A8B9CC?style=flat-square&logo=C&logoColor=black)' | pbcopy";
    icpp = "echo '![C++](https://img.shields.io/badge/-C++-00599C?style=flat-square&logo=C%2B%2B&logoColor=white)' | pbcopy";
    irust = "echo '![Rust](https://img.shields.io/badge/-Rust-000000?style=flat-square&logo=rust&logoColor=white)' | pbcopy";
    ipython = "echo '![Python](https://img.shields.io/badge/-Python-3776AB?style=flat-square&logo=Python&logoColor=white)' | pbcopy";
    inix = "echo '![Nix](https://img.shields.io/badge/-Nix-3f3f3f?style=flat-square&logo=nixos&logoColor=white)' | pbcopy";
    itailwind = "echo '![TailwindCSS](https://img.shields.io/badge/-TailwindCSS-06B6D4?style=flat-square&logo=tailwindcss&logoColor=white)' | pbcopy";
    idocker = "echo '![Docker](https://img.shields.io/badge/-Docker-2496ED?style=flat-square&logo=Docker&logoColor=white)' | pbcopy";
    iesbuild = "echo '![esbuild](https://img.shields.io/badge/-esbuild-FFCF00?style=flat-square&logo=esbuild&logoColor=black)' | pbcopy";
    izod = "echo '![Zod](https://img.shields.io/badge/-Zod-3C2A4D?style=flat-square&logo=zod&logoColor=white)' | pbcopy";
    imake = "echo '![Make](https://img.shields.io/badge/-Make-000000?style=flat-square&logo=gnu&logoColor=white)' | pbcopy";
  };
}
