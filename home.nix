{
  pkgs,
  config,
  tag,
  lib,
  ...
}: {
  # ----------- Base Settings
  home.username =
    if tag == "mac"
    then "darrenlu"
    else if tag == "ft"
    then "dlu"
    else throw "Unknown tag: ${tag}";
  home.homeDirectory =
    if tag == "mac"
    then "/Users/darrenlu"
    else if tag == "ft"
    then "/home/dlu"
    else throw "Unknown tag: ${tag}";
  home.stateVersion = "25.11"; # Version when started using

  home.packages = with pkgs;
    [
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
    ]
    ++ lib.optionals (tag == "mac") [
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
    ]
    ++ lib.optionals (tag == "ft") [
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

    profileExtra = builtins.readFile ./scripts/nix-prepend-path.sh;

    initContent = ''
      for f in $HM/functions/*.sh; do
         [ -r "$f" ] && source "$f"
      done

      autoload -Uz compinit
      compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
    ''; # zshrc
  };

  fonts.fontconfig.enable = true;

  xdg.configFile."clang-format".source = ./configs/clang-format.yml;
  xdg.configFile."prettier.json".source = ./configs/prettier-config.json;

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
