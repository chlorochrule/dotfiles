{
  description = "darwin config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin, home-manager }:
    let
      mkHost = hostPath:
        let host = import hostPath;
        in {
          name = host.hostname;
          value = nix-darwin.lib.darwinSystem {
            system = host.system;
            specialArgs = { username = host.username; };
            modules = [
              ./darwin.nix
              home-manager.darwinModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.extraSpecialArgs = { username = host.username; };
                home-manager.users.${host.username} = import ./home;
              }
            ];
          };
        };

      hosts = [
        ./hosts/MacBookPro-minami
      ];
    in {
      darwinConfigurations = builtins.listToAttrs (map mkHost hosts);
    };
}
