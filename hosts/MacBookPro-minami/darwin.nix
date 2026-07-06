{ username, ... }: {
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
    "ollama-app"
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
