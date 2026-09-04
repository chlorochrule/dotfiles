{
  description = "darwin config";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-25.11-darwin";
    # 一部パッケージ(ollama等、リリースブランチへのバックポートが追いつかず
    # 実用上unstable版が必要なもの)をホスト側でoverlay経由で個別に差し替えるために使う。
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    # herdrはnixpkgs未収録のため公式flakeから取得する。
    # herdr-nixはソースビルドせず、herdr本体のprebuiltバイナリ(cachix経由)を
    # ハッシュ検証込みで取得するラッパー(cachix設定はdarwin.nixのnix.extraOptions)。
    herdr-nix.url = "github:herdrdev/herdr-nix";
    nix-darwin = {
      url = "github:nix-darwin/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixpkgs-unstable, herdr-nix, nix-darwin, home-manager }:
    let
      mkHost = hostPath:
        let host = import hostPath;
        in {
          name = host.hostname;
          value = nix-darwin.lib.darwinSystem {
            system = host.system;
            specialArgs = {
              username = host.username;
              pkgs-unstable = import nixpkgs-unstable { system = host.system; };
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
