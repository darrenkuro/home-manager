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
      system = inputs.system or "aarch64-darwin";
      pkgs = nixpkgs.legacyPackages.${system};
      username =
        if pkgs.stdenv.isDarwin then "darrenlu"
        else "dlu";
      homeDir =
        if pkgs.stdenv.isDarwin then "/Users/${username}"
        else "/home/${username}";
    in
    {
      homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
        inherit pkgs;

        modules = [
          {
            home.username = username;
            home.homeDirectory = homeDir;  
          }
          ./home/entry.nix ];

      };
    };
}
