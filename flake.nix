{
  description = "Darren's Home Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    git-init.url = "github:darrenkuro/git-init";
  };

  outputs = {
    self,
    nixpkgs,
    home-manager,
    git-init,
    ...
  }: let
    # paths = {
    # 	apps = ./modules/apps;
    # 	sys = ./modules/system;
    # 	dev = ./modules/dev;
    # };
    mkHome = {
      system,
      tag,
    }:
      home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        extraSpecialArgs = {inherit tag system git-init;};
        modules = [./home.nix];
      };
  in {
    homeConfigurations = {
      mac = mkHome {
        system = "aarch64-darwin";
        tag = "mac";
      };
      ft = mkHome {
        system = "x86_64-linux";
        tag = "ft";
      };
    };
  };
}
