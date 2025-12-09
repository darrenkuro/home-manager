{ pkgs, ... }:
{
  imports = [
    ../apps/tmux.nix

    ../apps/vscode.nix
    ../dev/c-cpp.nix
    ../dev/rust.nix
    ../dev/js-ts.nix
    ../dev/python.nix
    ../dev/nix.nix
  ];

  # home.file."Library/Fonts/NixNerdFonts".source = "${pkgs.nerd-fonts.fira-code}/share/fonts";

  home.packages = with pkgs; [
    darwin.trash
    tokei
    eza
    fd
    jq
    fzf
    rename
    ripgrep
    bat

    taskwarrior3

    anki
    brave
    the-unarchiver
    obsidian
    discord
    ghostty-bin
    chatgpt

    # Not in active use
    # pnpm
    # docker

    # ffmpeg
    # imagemagick

    # The following apps can be managed in theory with nix but will be migrated later
    # dropbox
    # steam

    # Probably better to spawn it when needed
    # avidemux
    # handbrake
    # audacity
    # blackhole / loopback?

    # tor
    # firefox
    # google-chrome

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
