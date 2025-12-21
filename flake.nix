{
  description = "Darren's Home Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      ...
    }:
    let
      mkHome =
        {
          system,
          tag,
        }:
        home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          extraSpecialArgs = { inherit tag system; };
          modules = [ ./home.nix ];
        };
    in
    {
      nix.settings.use-xdg-base-directories = true;
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
