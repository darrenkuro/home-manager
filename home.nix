{
  pkgs,
  config,
  tag,
  lib,
  ...
}:
{
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
      nodePackages.prettier

      # Ensure Consistency
      openssl # Apple ships LibreSSL
      gnused  # Apple ships BSD-sed
      cmake
      #nerd-fonts.hack
      # cachix
      # (pkgs.nerd-fonts.override {fonts = ["Hack"];})
    ]
    ++ lib.optionals (tag == "mac") [
      rustc
      nodejs_22 # LTS; nodejs_latest (v25) fails to build, nodejs_24 not cached for aarch64-darwin
      typescript
      nodePackages.typescript-language-server

      python313Packages.black
      python313Packages.flake8
      prettierd

      python313
      python313Packages.pip
      python313Packages.virtualenv

      darwin.trash # Replace rm (safer)
      ghostty-bin
      ffmpeg
      tmux
      poppler-utils # PDF tools
      yt-dlp # Youtube download

      (postgresql_17.withPackages (ps: [ ps.pgvector ]))

      pnpm
      bun

      # Docker (via Colima)
      colima # Docker replacement
      docker-client
      docker-compose
      docker-buildx

      pandoc
      # typst
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
      "$HOME/.cache/zsh" \
      "$HOME/.local/state/postgresql"
  '';

  programs.home-manager.enable = true;
  programs.bash = {
    enable = true;
    historyFile = "${config.home.homeDirectory}/.local/state/bash/history";
    historySize = 100000;
    historyFileSize = 100000;
  };
  programs.zsh = {
    enable = true;
    dotDir = "${config.home.homeDirectory}/.config";
    history = {
      path = "${config.home.homeDirectory}/.local/state/zsh/history";
      size = 100000;
      save = 100000;
      ignoreDups = true; # Ignore when same cmd twice in a row
      share = true; # Share across terminal
      extended = true;
    };
    envExtra = builtins.readFile ./scripts/load-nix.sh;
    profileExtra = builtins.readFile ./scripts/nix-prepend-path.sh;
    initContent = lib.concatStringsSep "\n" ([
        (builtins.readFile ./scripts/source.sh)
        (builtins.readFile ./scripts/hygiene.sh)
      ]
      ++ lib.optionals (tag == "mac") [
        (builtins.readFile ./scripts/ssh-keychain.sh)
      ]
      ++ lib.optionals (tag == "ft") [
        (builtins.readFile ./scripts/repeat-rate.sh)
      ]);
  };
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  fonts.fontconfig.enable = true;

  xdg.configFile."clang-format".source = ./configs/clang-format.yml;
  xdg.configFile."prettier.json".source = ./configs/prettier-config.json;

  home.activation.configCopy =
    lib.hm.dag.entryAfter ["writeBoundary"]
    (lib.concatStringsSep "\n"
      [(builtins.readFile ./scripts/copy-files.sh)]);

  imports =
    [
      ./modules/system/aliases.nix
      ./modules/system/env.nix

      ./modules/apps/starship.nix
      ./modules/apps/git.nix
      ./modules/apps/helix.nix
      ./modules/apps/claude.nix
      ./modules/apps/ssh.nix
    ]
    ++ lib.optionals (tag == "mac") [
      ./modules/system/macos.nix
      ./modules/services/btm.nix
      ./modules/services/claude-agent.nix
      ./modules/services/polymarket-monitor.nix
      ./modules/services/postgresql.nix
    ]
    ++ lib.optionals (tag == "ft") [
      ./modules/system/linux-ft.nix
    ];
}
