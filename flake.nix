{
  description = "darwin config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # herdr isn't in nixpkgs; see .claude/rules/nix-hosts.md for why this input exists.
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
    # Prebuilt, weekly-updated nix-index database (for `,` and
    # command-not-found) instead of running nix-index locally.
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
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
          # darwin.nix/home.nix are optional per-host extras (see README);
          # include them only if present so a bare host still evaluates.
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
