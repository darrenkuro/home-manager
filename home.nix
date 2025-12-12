{
  pkgs,
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

    clang-tools
    alejandra
    nil
    rust-analyzer
    rustfmt
    prettier

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

  home.file.".config/Code/User/settings.json".source = ./ext/settings.json;
  # home.file.".config/Code/User/keybindings.json".source = ./vscode/keybindings.json;

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
