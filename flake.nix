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
    lib = nixpkgs.lib;
    hmExtraArgs = {
      inherit claude-plugins-official obsidian-skills claude-config netusage;
    };

    # Machine identity — the single source of truth. Every target below and
    # every module arg (user, homeDir, tag, profile) derives from this map.
    machines = {
      mac = { system = "aarch64-darwin"; tag = "mac"; profile = "personal"; user = "darrenlu"; };
      mac-work = { system = "aarch64-darwin"; tag = "mac"; profile = "work"; user = "darrenlu"; };
      ft = { system = "x86_64-linux"; tag = "ft"; profile = "personal"; user = "dlu"; };
    };

    isDarwin = m: lib.hasSuffix "darwin" m.system;
    specialArgsFor = m:
      hmExtraArgs
      // {
        inherit (m) system tag profile user;
        homeDir = if isDarwin m then "/Users/${m.user}" else "/home/${m.user}";
      };

    # nix-darwin system + embedded HM (used by `sure`)
    mkDarwin = m:
      nix-darwin.lib.darwinSystem {
        inherit (m) system;
        specialArgs = specialArgsFor m;
        modules = [
          ./darwin.nix
          home-manager.darwinModules.home-manager
          {
            nixpkgs.config.allowUnfree = true;
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.extraSpecialArgs = specialArgsFor m;
            home-manager.users.${m.user} = import ./home.nix;
          }
        ];
      };

    # Standalone HM — used by `re` for fast user-only rebuilds (no sudo,
    # no brew/system changes).
    mkHome = m:
      home-manager.lib.homeManagerConfiguration {
        pkgs = import nixpkgs {
          inherit (m) system;
          config.allowUnfree = true;
        };
        extraSpecialArgs = specialArgsFor m;
        modules = [./home.nix];
      };
  in {
    darwinConfigurations = lib.mapAttrs (_: mkDarwin) (lib.filterAttrs (_: isDarwin) machines);
    homeConfigurations = lib.mapAttrs (_: mkHome) machines;
  };
}
