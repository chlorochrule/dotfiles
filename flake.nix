{
  description = "darwin config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nix-darwin }:
    let
      mkHost = hostPath:
        let host = import hostPath;
        in {
          name = host.hostname;
          value = nix-darwin.lib.darwinSystem {
            system = host.system;
            specialArgs = { username = host.username; };
            modules = [ ./darwin.nix ];
          };
        };

      hosts = [
        ./hosts/MacBookPro-minami
      ];
    in {
      darwinConfigurations = builtins.listToAttrs (map mkHost hosts);
    };
}
