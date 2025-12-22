{
  pkgs,
  config,
  tag,
  lib,
  ...
}: {
  home.username =
    if tag == "mac"
    then "darrenlu"
    else "dlu";
  home.homeDirectory =
    if tag == "mac"
    then "/Users/darrenlu"
    else "/home/dlu";
  home.stateVersion = "25.11"; # Version when started using

  home.packages = with pkgs; [
    tokei
    eza
    fd
    jq
    fzf
    rename
    bat
    gettext # envsubst

    wakatime-cli

    clang-tools # C, CPP
    alejandra # Nix formatter
    nil # Nix LSP
    shfmt
    shellcheck
    cargo
    rust-analyzer
    rustfmt
    clippy
    asm-lsp
    asmfmt

    #nerd-fonts.hack
    # cachix
    # (pkgs.nerd-fonts.override {fonts = ["Hack"];})

    # inputs.darren-nix-pkgs.packages.${pkgs.system}.gloc
  ];

  # Ensure directories used exist
  home.activation.createStateDirs = ''
    mkdir -p \
      "$HOME/.local/state/zsh" \
      "$HOME/.local/state/bash" \
      "$HOME/.local/state/less" \
      "$HOME/.local/state/sessions" \
      "$HOME/.local/state/wakatime" \
      "$HOME/.cache/zsh"
  '';

  programs.home-manager.enable = true;
  programs.zsh = {
    enable = true;
    dotDir = "${config.home.homeDirectory}/.config";

    history = {
      path = "${config.home.homeDirectory}/.local/state/zsh/history";
      size = 100000;
      save = 100000;
      ignoreDups = true;
      ignoreAllDups = true;
      share = true;
      extended = true;
    };
  };

  fonts.fontconfig.enable = true;

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
    # Source scripts
       for f in $HM/functions/*.sh; do
         [ -r "$f" ] && source "$f"
       done

    # Move zcompdump from Home dir to cache dir
      autoload -Uz compinit
      compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
  '';

  imports =
    [
      # Shared across all profiles
      ./modules/system/aliases.nix
      ./modules/system/env.nix

      ./modules/apps/starship.nix
      ./modules/apps/git.nix
      ./modules/apps/helix.nix
    ]
    ++ lib.optionals (tag == "mac") [
      ./modules/system/macos.nix
    ]
    ++ lib.optionals (tag == "ft") [
      ./modules/system/linux-ft.nix
    ];
}
