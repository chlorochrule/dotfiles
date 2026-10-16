{
  description = "darwin config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # Only for packages a host overlays from unstable.
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    herdr-nix = {
      url = "github:herdrdev/herdr-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      herdr-nix,
      nix-darwin,
      home-manager,
      nix-index-database,
    }:
    let
      mkHost =
        hostPath:
        let
          host = import hostPath;
          # darwin.nix/home.nix are optional per host.
          optionalHostFile =
            name:
            let
              path = hostPath + "/${name}";
            in
            if builtins.pathExists path then [ path ] else [ ];
        in
        {
          name = host.hostname;
          value = nix-darwin.lib.darwinSystem {
            system = host.system;
            specialArgs = {
              username = host.username;
              inherit nixpkgs-unstable;
            };
            modules = [
              ./darwin.nix
            ]
            ++ optionalHostFile "darwin.nix"
            ++ [
              home-manager.darwinModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "backup";
                home-manager.sharedModules = [ nix-index-database.homeModules.default ];
                home-manager.extraSpecialArgs = {
                  username = host.username;
                  hostname = host.hostname;
                  herdr = herdr-nix.packages.${host.system}.default;
                };
                home-manager.users.${host.username} = {
                  imports = [ ./home ] ++ optionalHostFile "home.nix";
                };
              }
            ];
          };
        };

      hosts = [
        ./hosts/MacBookPro-minami
      ];
    in
    {
      darwinConfigurations = builtins.listToAttrs (map mkHost hosts);
    };
}
