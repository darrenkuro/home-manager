{
  pkgs,
  config,
  # lib,
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
    bat

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

    # let vscode manage its own settings
    # vscode-extensions.pkief.material-icon-theme
    # vscode-extensions.github.github-vscode-theme
    # vscode-extensions.ms-vscode.cpptools
    # vscode-extensions.jnoortheen.nix-ide
    # vscode-extensions.rust-lang.rust-analyzer
    # vscode-extensions.ms-vscode.makefile-tools
    # vscode-extensions.mikestead.dotenv
    # vscode-extensions.tamasfe.even-better-toml
    # vscode-extensions.foxundermoon.shell-format
    # vscode-extensions.wakatime.vscode-wakatime
    # 13
    # xforever.asm-code-lens

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

    # envExtra = ''
    #   if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    #     . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    #   fi
    #   export PATH="/nix/var/nix/profiles/default/bin:$HOME/.nix-profile/bin:$PATH"
    # '';
  };

  # programs.bash = {
  #   enable = true;

  #   historyFile = "${config.home.homeDirectory}/.local/state/bash/history";
  #   historySize = 100000;
  #   historyFileSize = 100000;
  # };

  fonts.fontconfig.enable = true;

  # # Symlink all extensions
  # home.activation.linkVscodeExtensions = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
  #   for ext in "${config.home.profileDirectory}/share/vscode/extensions/"*; do
  #     target="${config.home.homeDirectory}/.vscode/extensions/$(basename "$ext")"
  #     ln -sfn "$ext" "$target"
  #    done
  # '';

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
    # Source Nix (/etc/zshrc breaks after system updates)
    [[ ! $(command -v nix) && -e '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh' ]] && source '/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh'

    # Source scripts
    for f in $HM/functions/*.sh; do
      [ -r "$f" ] && source "$f"
    done

    # Move zcompdump from Home dir to cache dir
    autoload -Uz compinit
    compinit -d "$XDG_CACHE_HOME/zsh/zcompdump"
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
