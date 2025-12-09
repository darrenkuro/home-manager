{ ... }:
{
  imports = [
    ../dev/c-cpp.nix
    ../dev/nix.nix
    ../dev/rust.nix # Temp for project
    #../dev/js-ts.nix
  ];

  #   xsession.enable = true;
  #   xsession.initExtra = ''
  #     $${pkgs.xorg.xset}/bin/xset r rate 200 60
  #   '';

  programs.zsh.shellAliases = {
    re = "home-manager switch --flake ~/.config/home-manager#ft";
  };
}
