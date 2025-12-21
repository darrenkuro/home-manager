{
  pkgs,
  lib,
  config,
  ...
}:
{
  # home.file."Library/Fonts/NixNerdFonts".source = "${pkgs.nerd-fonts.fira-code}/share/fonts";

  home.packages = with pkgs; [

    rustc
    nodejs_latest
    typescript
    nodePackages.typescript-language-server

    nodePackages.prettier
    python311Packages.black
    python311Packages.flake8
    prettierd

    python311
    python311Packages.pip
    python311Packages.virtualenv

    vscode-extensions.esbenp.prettier-vscode
    vscode-extensions.ms-python.python
    vscode-extensions.ms-python.vscode-pylance

    darwin.trash
    taskwarrior3
    ghostty-bin

    ffmpeg

    tmux
    poppler-utils # pdf tools
    # Nix version locks so for frequently updated apps for which reproducibility is not most important
    # Shouldn't be managed here, and config files can still though
    # anki
    # the-unarchiver
    # brave
    # obsidian
    # discord
    # chatgpt
    # dropbox
    # steam
    # tor
    # firefox
    # google-chrome

    # Not in active use
    # pnpm
    # docker

    # imagemagick

    # Probably better to spawn it when needed
    # avidemux
    # handbrake
    # audacity
    # blackhole / loopback?

    # vlc-bin
  ];

  # Copy user setting, not symlink, to make it usable
  home.activation.vscodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/Library/Application Support/Code/User"
    envsubst < ${../../files/settings.json} > "$HOME/Library/Application Support/Code/User/settings.json"
    chmod u+w "$HOME/Library/Application Support/Code/User/settings.json"
  '';

  # # Symlink all extensions
  # home.activation.linkVscodeExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  #   for ext in "${config.home.profileDirectory}/share/vscode/extensions/"*; do
  #     target="${config.home.homeDirectory}/.vscode/extensions/$(basename "$ext")"
  #     ln -sfn "$ext" "$target"
  #    done
  # '';

  xdg.configFile."tmux/tmux.conf" = {
    source = ../../files/tmux.conf;
  };

  programs.zsh.shellAliases = {
    dbox = "cd $DBOX";

    cloc = "tokei";
    re = "home-manager switch --flake ~/.config/home-manager#mac && exec zsh";

    hide = "chflags hidden";
    unhide = "chflags nohidden";
    rm = "echo \"☠️$YELLOW DANGEROUS CMD: using trash instread!$RESET\" && trash";

    readme = "cat $HM/files/README.md | pbcopy";
    gig = "cat $HM/files/.gitignore | pbcopy";

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
