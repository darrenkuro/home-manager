{ pkgs, ... }:
{
  # Noise Shell App?

  # home.file."Library/Fonts/NixNerdFonts".source = "${pkgs.nerd-fonts.fira-code}/share/fonts";

  home.packages = with pkgs; [

    rustc
    nodejs_latest
    typescript
    nodePackages.typescript-language-server

    python311
    python311Packages.pip
    python311Packages.virtualenv

    darwin.trash
    taskwarrior3
    ghostty-bin

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

    # ffmpeg
    # imagemagick

    # Probably better to spawn it when needed
    # avidemux
    # handbrake
    # audacity
    # blackhole / loopback?

    # vlc-bin
  ];

  programs.zsh.shellAliases = {
    dbox = "cd $DBOX";

    cloc = "tokei";
    re = "home-manager switch --flake ~/.config/home-manager#mac";

    hide = "chflags hidden";
    unhide = "chflags nohidden";
    rm = "echo \"☠️$YELLOW DANGEROUS CMD: using trash instread!$RESET\" && trash";
  };
}
