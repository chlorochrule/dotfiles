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
        let
          host = import hostPath;
          # darwin.nix/home.nixはホスト固有の追加設定なので任意(README「セットアップ手順」
          # 参照)。無いホストでも評価が壊れないよう、存在する場合だけmodules/importsに含める。
          optionalHostFile = name:
            let path = hostPath + "/${name}";
            in if builtins.pathExists path then [ path ] else [ ];
        in {
          name = host.hostname;
          value = nix-darwin.lib.darwinSystem {
            system = host.system;
            specialArgs = {
              username = host.username;
            };
            modules = [
              ./darwin.nix
            ] ++ optionalHostFile "darwin.nix" ++ [
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
                  imports = [ ./home ] ++ optionalHostFile "home.nix";
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
