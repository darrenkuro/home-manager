{
  description = "Darren's Home Manager";

  inputs = {
    # Newest, Update daily
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, home-manager, ... }:
    let
      forSystem = system:
        nixpkgs.legacyPackages.${system};
    in
    {
      homeConfigurations = {
        mac = home-manager.lib.homeManagerConfiguration {
          pkgs = forSystem "aarch64-darwin";
          extraSpecialArgs = { tag = "mac"; };
          modules = [
            {
              home.username = "darrenlu";
              home.homeDirectory = "/Users/darrenlu";
            }
            ./src-nix/entry.nix ];
        };
        ft = home-manager.lib.homeManagerConfiguration {
          pkgs = forSystem "x86_64-linux";
          extraSpecialArgs = { tag = "ft"; };
          modules = [
            {
              home.username = "dlu";
              home.homeDirectory = "/home/dlu";
              
              xsession.enable = true;
              xsession.initExtra = ''
                $${pkgs.xorg.xset}/bin/xset r rate 200 60
              '';
            }
            ./src-nix/entry.nix ];
        };
      };
    };
}
