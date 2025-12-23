{
  pkgs,
  config,
  tag,
  lib,
  ...
}:
# let
#   wakatimeKey = builtins.getEnv "WAKATIME_API_KEY";
# in
# assert wakatimeKey != "";
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
      taskwarrior3

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

      darwin.trash # Replace rm (safer)
      ghostty-bin
      ffmpeg
      tmux
      poppler-utils # PDF tools
    ]
    ++ lib.optionals (tag == "ft") [
      ghostty
      xorg.xeyes
      gtk4
      foot
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
      ignoreDups = true; # Ignore when same cmd twice in a row
      share = true; # Share across terminal
      extended = true;
    };
    envExtra = builtins.readFile ./scripts/load-nix.sh;
    profileExtra = builtins.readFile ./scripts/nix-prepend-path.sh;
    initContent = lib.concatStringsSep "\n" ([
        (builtins.readFile ./scripts/source-functions.sh)
        (builtins.readFile ./scripts/hygiene.sh)
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
  xdg.configFile."task/taskrc".source = ./configs/taskrc;

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
    ]
    ++ lib.optionals (tag == "mac") [
      ./modules/system/macos.nix
    ]
    ++ lib.optionals (tag == "ft") [
      ./modules/system/linux-ft.nix
    ];
}
