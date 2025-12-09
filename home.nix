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
    nerd-fonts.hack
    cachix

    # inputs.darren-nix-pkgs.packages.${pkgs.system}.gloc
  ];

  programs.home-manager.enable = true;
  programs.zsh.enable = true;
  programs.bash.enable = true;

  fonts.fontconfig.enable = true;

  imports = [
    # Shared across all profiles
    ./modules/system/aliases.nix
    ./modules/system/env.nix

    ./modules/apps/starship.nix
    ./modules/apps/git.nix
    ./modules/apps/helix.nix
    # ./modules/apps/vscode.nix
    ./modules/apps/tmux.nix

    (if tag == "mac" then ./modules/system/macos.nix else ./modules/system/linux-ft.nix)
  ];
}
