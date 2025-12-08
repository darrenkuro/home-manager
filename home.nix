{
  pkgs,
  tag,
  ...
}:
{
  home.username = if tag == "mac" then "darrenlu" else "dlu";
  home.homeDirectory = if tag == "mac" then "/Users/darrenlu" else "/user/dlu";
  home.stateVersion = "25.11"; # Version when started using

  programs.home-manager.enable = true;
  programs.zsh.enable = true;
  programs.bash.enable = true;

  # Font
  home.packages = [ pkgs.nerd-fonts.hack ];
  fonts.fontconfig.enable = true;

  imports = [
    ./modules/system/aliases.nix
    ./modules/system/env.nix

    ./modules/apps/starship.nix
    ./modules/apps/git.nix
    ./modules/apps/helix.nix
    ./modules/apps/vscode.nix
    # ./modules/apps/tmux.nix

    (if tag == "mac" then ./modules/system/macos.nix else ./modules/system/linux-ft.nix)
  ];
}
