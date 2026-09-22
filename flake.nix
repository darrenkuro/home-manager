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
    netusage = {
      url = "github:darrenkuro/netusage";
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
    netusage,
    ...
  }: let
    hmExtraArgs = {
      inherit claude-plugins-official obsidian-skills claude-config netusage;
    };
    mkHome = {
      system,
      tag,
      profile ? "personal",
    }:
      home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
        extraSpecialArgs =
          hmExtraArgs
          // {
            inherit tag system profile;
          };
        modules = [./home.nix];
      };
  in {
    # nix-darwin (mac system-level + embedded HM)
    darwinConfigurations.mac = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        (import ./darwin.nix { profile = "personal"; })
        home-manager.darwinModules.home-manager
        {
          nixpkgs.config.allowUnfree = true;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs =
            hmExtraArgs
            // {
              tag = "mac";
              profile = "personal";
              system = "aarch64-darwin";
            };
          home-manager.users.darrenlu = import ./home.nix;
        }
      ];
    };

    # Lean work macOS profile.  It has its own Homebrew app list, Dock and
    # Home Manager package set; the existing `mac` target stays personal.
    darwinConfigurations.mac-work = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        (import ./darwin.nix { profile = "work"; })
        home-manager.darwinModules.home-manager
        {
          nixpkgs.config.allowUnfree = true;
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.extraSpecialArgs =
            hmExtraArgs
            // {
              tag = "mac";
              profile = "work";
              system = "aarch64-darwin";
            };
          home-manager.users.darrenlu = import ./home.nix;
        }
      ];
    };

    # Standalone HM — used by `re` for fast user-only rebuilds (no sudo,
    # no brew/system changes). `sure` uses darwinConfigurations.mac above.
    homeConfigurations = {
      mac = mkHome {
        system = "aarch64-darwin";
        tag = "mac";
      };
      mac-work = mkHome {
        system = "aarch64-darwin";
        tag = "mac";
        profile = "work";
      };
      ft = mkHome {
        system = "x86_64-linux";
        tag = "ft";
      };
    };
  };
}
