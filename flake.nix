{
  description = "darwin config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    # herdrはnixpkgs未収録のため公式flakeから取得する。
    # herdr-nixはソースビルドせず、herdr本体のprebuiltバイナリ(cachix経由)を
    # ハッシュ検証込みで取得するラッパー(cachix設定はdarwin.nixのnix.extraOptions)。
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
  };

  outputs = { self, nixpkgs, herdr-nix, nix-darwin, home-manager }:
    let
      mkHost = hostPath:
        let host = import hostPath;
        in {
          name = host.hostname;
          value = nix-darwin.lib.darwinSystem {
            system = host.system;
            specialArgs = {
              username = host.username;
            };
            modules = [
              ./darwin.nix
              (hostPath + "/darwin.nix")
              home-manager.darwinModules.home-manager
              {
                home-manager.useGlobalPkgs = true;
                home-manager.useUserPackages = true;
                home-manager.backupFileExtension = "backup";
                home-manager.extraSpecialArgs = {
                  username = host.username;
                  hostname = host.hostname;
                  herdr = herdr-nix.packages.${host.system}.default;
                };
                home-manager.users.${host.username} = {
                  imports = [ ./home (hostPath + "/home.nix") ];
                };
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
