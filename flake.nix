{
  description = "Darren's Home Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    #darren-nix-pkgs.url = "github:darrenkuro/darren-nix-pkgs";
  };

  outputs =
    {
      nixpkgs,
      home-manager,
      #darren-nix-pkgs,
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
            #overlays = [ darren-nix-pkgs.overlays.default ];
          };
          extraSpecialArgs = { inherit tag system; };
          modules = [ ./home.nix ];
        };
    in
    {
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
