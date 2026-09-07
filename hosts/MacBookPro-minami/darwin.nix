{ username, pkgs-unstable, ... }: {
  # nixpkgs-25.11-darwinのollamaは0.21.1で止まっており(アップストリームの
  # バックポートが追いついていない)、新しいモデル(Qwen3.6, Qwen3-Coder-Next等)の
  # マニフェストが要求するバージョンを満たせずpullが失敗する。
  # 最新版が必要なのでnixpkgs-unstable(flake.nixのinput)のollamaに差し替える。
  nixpkgs.overlays = [
    (final: prev: { ollama = pkgs-unstable.ollama; })
  ];

  homebrew.casks = [
    "claude"
    "claude-code@latest"
    "discord"
    "ghostty"
    "google-chrome"
    "intellij-idea-ce"
    "jetbrains-toolbox"
    "menumeters"
    "nordvpn"
    "postman-agent"
    "rancher"
    "raycast"
    "slack"
    "spotify"
    "visual-studio-code"
    "wireshark-app"
    "zoom"
  ];

  # Dockの常駐アプリ(並び順どおり)。casks同様ホスト固有
  system.defaults.dock.persistent-apps = [
    "/Applications/Ghostty.app"
    "/Applications/Slack.app"
    "/Applications/Google Chrome.app"
    "/Applications/Visual Studio Code.app"
    "/Applications/IntelliJ IDEA CE.app"
    "/Applications/Spotify.app"
    "/Applications/Postman Agent.app"
    "/Applications/NordVPN.app"
    "/Applications/Wireshark.app"
    "/Applications/zoom.us.app"
    "/System/Applications/System Settings.app"
    "/System/Applications/App Store.app"
    "/System/Applications/Phone.app"
    "/System/Applications/Messages.app"
    "/System/Applications/Photos.app"
    "/System/Applications/iPhone Mirroring.app"
  ];

  system.defaults.dock.persistent-others = [
    "/Users/${username}/Downloads"
  ];

  # macOSホスト本体(CPU/メモリ/ディスク等)のメトリクスをterraform/local/の
  # Prometheus(Docker)へ提供するnode_exporter。DockerコンテナからではOSの
  # 真のホストメトリクスが取れないため、nix-darwinのlaunchd daemonとして
  # ホストに直接インストールする(home-managerのservices.*には
  # node_exporter用のdarwin対応launchdモジュールが存在しないため)。
  # 127.0.0.1限定でlistenし、外部・他コンテナからは直接到達できないようにする
  # (Prometheus側はhost.docker.internal経由でアクセスする)。
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
  };

  system.defaults.CustomUserPreferences = {
    # Spotlightの⌘Space(symbolic hotkey 64)を無効化し、Raycastに割り当てる
    "com.apple.symbolichotkeys" = {
      AppleSymbolicHotKeys = {
        "64" = {
          enabled = false;
        };
      };
    };
    "com.raycast.macos" = {
      raycastGlobalHotkey = "Command-49";  # 49 = Spaceのkeycode
    };
  };
}
