{
  pkgs,
  lib,
  config,
  ...
}:
{
  # Noise Shell App?

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

  # Copy user setting, not symlink, to make it usable
  home.activation.vscodeSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    mkdir -p "$HOME/Library/Application Support/Code/User"
    envsubst < ${./ext/settings.json} > "$HOME/Library/Application Support/Code/User/settings.json"
    chmod u+w "$HOME/Library/Application Support/Code/User/settings.json"
  '';

  # Symlink all extensions
  home.activation.linkVscodeExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    for ext in "${config.home.profileDirectory}/share/vscode/extensions/"*; do
      target="${config.home.homeDirectory}/.vscode/extensions/$(basename "$ext")"
      ln -sfn "$ext" "$target"
     done
  '';

  programs.zsh.shellAliases = {
    dbox = "cd $DBOX";

    cloc = "tokei";
    re = "home-manager switch --flake ~/.config/home-manager#mac";

    hide = "chflags hidden";
    unhide = "chflags nohidden";
    rm = "echo \"☠️$YELLOW DANGEROUS CMD: using trash instread!$RESET\" && trash";
  };
}
