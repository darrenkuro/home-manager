{ pkgs, ... }:
{
  imports = [
    ../dev/c-cpp.nix
    ../dev/rust.nix
    ../dev/js-ts.nix
    ../dev/nix.nix
  ];

  #home.file."Library/Fonts/NixNerdFonts".source = "${pkgs.nerd-fonts.fira-code}/share/fonts";

  home.packages = with pkgs; [
    pnpm
    docker

    tokei
    eza
    fd
    jq
    fzf

    ffmpeg
    imagemagick
    rename
    ripgrep

    darwin.trash

    anki
    brave
    the-unarchiver
    #avidemux
    google-chrome
    obsidian
    #ghostty-bin

    taskwarrior3
  ];

  programs.zsh.shellAliases = {
    dbox = "cd $DBOX";

    re = "home-manager switch --flake ~/.config/home-manager#mac";

    hide = "chflags hidden";
    unhide = "chflags nohidden";
    rm = "echo \"☠️ $YELLOW DANGEROUS CMD: using trash instread!$RESET\" && trash";
  };
}
