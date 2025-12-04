{
  description = "Home Manager configuration of darrenlu";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, home-manager, ... } @ inputs:
    let
      #system = builtins.currentSystem;
      system = inputs.system or "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      #pkgs = import nixpkgs { inherit system; };
    in
    {
      homeConfigurations."darrenlu" = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        # Specify your home configuration modules here, for example,
        # the path to your home.nix.
        modules = [
          
       #     home.username = "darrenlu";
        #    home.homeDirectory =
         #     if system == "aarch64-darwin" then "/Users/darrenlu" else "/home/dlu";
         #   home.stateVersion = "25.11"; # home-manager version; for keeping stable default
         #   home.packages = with pkgs; [
         #     starship
         #     helix
         #     git
         #     neovim
         #   ];

         #   programs.home-manager.enable = true;
          ./home.nix
          
        ];

        # Optionally use extraSpecialArgs
        # to pass through arguments to home.nix
      };
    };
}
