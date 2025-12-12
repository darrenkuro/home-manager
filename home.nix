{
  pkgs,
  config,
  lib,
  tag,
  ...
}:

{
  home.username = if tag == "mac" then "darrenlu" else "dlu";
  home.homeDirectory = if tag == "mac" then "/Users/darrenlu" else "/home/dlu";
  home.stateVersion = "25.11"; # Version when started using

  home.packages = with pkgs; [

    tokei
    eza
    fd
    jq
    fzf
    rename
    ripgrep
    bat

    # prettierd
    clang-tools # C, CPP
    alejandra # Nix formatter
    nil # Nix LSP
    rust-analyzer
    rustfmt
    clippy
    nodePackages.prettier

    vscode-extensions.pkief.material-icon-theme
    vscode-extensions.github.github-vscode-theme
    vscode-extensions.ms-vscode.cpptools
    vscode-extensions.esbenp.prettier-vscode
    vscode-extensions.jnoortheen.nix-ide
    vscode-extensions.rust-lang.rust-analyzer
    #nerd-fonts.hack
    # cachix
    # (pkgs.nerd-fonts.override {fonts = ["Hack"];})

    # inputs.darren-nix-pkgs.packages.${pkgs.system}.gloc
  ];

  programs.home-manager.enable = true;
  programs.zsh.enable = true;
  programs.bash.enable = true;

  fonts.fontconfig.enable = true;

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

  # Format: C, CPP
  home.file.".clang-format".text = ''
    BasedOnStyle: LLVM
    IndentWidth: 4
    TabWidth: 4
    UseTab: Never
    ColumnLimit: 100
    AlwaysBreakTemplateDeclarations: true
    BreakBeforeBraces: Attach
    AllowShortFunctionsOnASingleLine: Inline
    SpaceBeforeParens: ControlStatements
  '';

  imports = [
    # Shared across all profiles
    ./modules/system/aliases.nix
    ./modules/system/env.nix

    ./modules/apps/starship.nix
    ./modules/apps/git.nix
    ./modules/apps/helix.nix

    (if tag == "mac" then ./modules/system/macos.nix else ./modules/system/linux-ft.nix)
  ];
}
