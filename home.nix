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
    # fd
    jq
    fzf
    rename
    ripgrep
    bat

    clang-tools # C, CPP
    alejandra # Nix formatter
    nil # Nix LSP
    rust-analyzer
    rustfmt
    clippy

    vscode-extensions.pkief.material-icon-theme
    vscode-extensions.github.github-vscode-theme
    vscode-extensions.ms-vscode.cpptools
    vscode-extensions.jnoortheen.nix-ide
    vscode-extensions.rust-lang.rust-analyzer
    vscode-extensions.ms-vscode.makefile-tools
    vscode-extensions.mikestead.dotenv
    vscode-extensions.tamasfe.even-better-toml

    #nerd-fonts.hack
    # cachix
    # (pkgs.nerd-fonts.override {fonts = ["Hack"];})

    # inputs.darren-nix-pkgs.packages.${pkgs.system}.gloc
  ];

  programs.home-manager.enable = true;
  programs.zsh.enable = true;
  programs.bash.enable = true;

  fonts.fontconfig.enable = true;

  home.file.".local/share/functions/search.sh".source = ./functions/search.sh;

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

  xdg.configFile.".config/prettier/config.json".text = ''
    {
      "printWidth": 100,
      "tabWidth": 4,
      "useTabs": false,
      "semi": true,
      "singleQuote": true,
      "trailingComma": "es5",
      "bracketSpacing": true,
      "arrowParens": "avoid"
    }
  '';

  programs.zsh.initContent = ''
    for f in ~/.local/share/functions/*.sh; do
      [ -r "$f" ] && source "$f"
    done
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
