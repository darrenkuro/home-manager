{
  description = "Darren's Home Manager";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-darwin.url = "github:nix-darwin/nix-darwin";
    nix-darwin.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    claude-plugins-official = {
      url = "github:anthropics/claude-plugins-official";
      flake = false;
    };
    obsidian-skills = {
      url = "github:kepano/obsidian-skills";
      flake = false;
    };
    claude-config = {
      url = "git+ssh://git@github.com/darrenkuro/claude-config";
      flake = false;
    };
  };

  outputs = {
    nixpkgs,
    nix-darwin,
    home-manager,
    claude-plugins-official,
    obsidian-skills,
    claude-config,
    ...
  }: let
    hmExtraArgs = {
      inherit claude-plugins-official obsidian-skills claude-config;
    };
    mkHome = {
      system,
      tag,
    }:
      home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        extraSpecialArgs =
          hmExtraArgs
          // {
            inherit tag system;
          };
        modules = [./home.nix];
      };
  in {
    # nix-darwin (mac system-level + embedded HM)
    darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ./darwin.nix
        home-manager.darwinModules.home-manager
        {
          nixpkgs.config.allowUnfree = true;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs =
            hmExtraArgs
            // {
              tag = "mac";
              system = "aarch64-darwin";
            };
          home-manager.users.darrenlu = import ./home.nix;
        }
      ];
    };

    # Standalone HM (keep existing outputs during transition)
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
