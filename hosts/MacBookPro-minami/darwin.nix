{ lib, username, ... }: {
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

  # Dock pinned apps, in display order. Host-specific, like casks above.
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

  # Provides host (CPU/memory/disk) metrics to terraform/local/'s
  # Prometheus. Installed as a nix-darwin launchd daemon rather than in a
  # container, since a container can't see true host metrics and
  # home-manager has no darwin launchd module for node_exporter. Listens on
  # 127.0.0.1 only; Prometheus reaches it via host.docker.internal.
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
  };

  # Works around a home path string mismatch — see .claude/rules/nix-hosts.md.
  users.users._prometheus-node-exporter.home = lib.mkForce "/private/var/lib/prometheus-node-exporter";

  system.defaults.CustomUserPreferences = {
    # Disable Spotlight's Cmd+Space (symbolic hotkey 64) and give it to Raycast.
    "com.apple.symbolichotkeys" = {
      AppleSymbolicHotKeys = {
        "64" = {
          enabled = false;
        };
      };
    };
    "com.raycast.macos" = {
      raycastGlobalHotkey = "Command-49"; # 49 = Space's keycode
    };
  };
}
