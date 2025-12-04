{
  description = "Home Manager config for Darren";

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
      forSystem = system:
        nixpkgs.legacyPackages.${system};
      #system = inputs.system or "aarch64-darwin";
      #pkgs = nixpkgs.legacyPackages.${system};
      #username =
      #  if pkgs.stdenv.isDarwin then "darrenlu"
      #  else "dlu";
      #homeDir =
      #  if pkgs.stdenv.isDarwin then "/Users/${username}"
      #  else "/home/${username}";
    in
    {
      homeConfigurations = {
        mac = home-manager.lib.homeManagerConfiguration {
          pkgs = forSystem "aarch64-darwin";
          modules = [
            {
              home.username = "darrenlu";
              home.homeDirectory = "/Users/darrenlu";
            }
            ./home/entry.nix ];
        };
        ft = home-manager.lib.homeManagerConfiguration {
          pkgs = forSystem "x86_64-linux";
          modules = [
            {
              home.username = "dlu";
              home.homeDirectory = "/home/dlu";
            }
            ./home/entry.nix ];
        };
      };
      
      #homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
      #  inherit pkgs;

#        modules = [
 #         {
  #          home.username = username;
   #         home.homeDirectory = homeDir;  
    #      }
     #     ./home/entry.nix ];

      #};
    };
}
