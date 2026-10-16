{
  lib,
  username,
  nixpkgs-unstable,
  ...
}:
{
  # The release branch lags far behind upstream.
  nixpkgs.overlays = [
    (
      final: prev:
      let
        unstable = nixpkgs-unstable.legacyPackages.${prev.stdenv.hostPlatform.system};
      in
      {
        inherit (unstable) pi-coding-agent;
      }
    )
  ];

  # For cmd-eikana; the homebrew-cask one is disabled.
  homebrew.taps = [ "dominion525/tap" ];

  homebrew.casks = [
    "adobe-acrobat-reader"
    "claude"
    "claude-code@latest"
    # Models and custom nodes are set up by hand (see README).
    "comfy"
    "discord"
    # ⌘英かな
    "dominion525/tap/cmd-eikana"
    "ghostty"
    "google-chrome"
    "google-drive"
    "intellij-idea"
    "menumeters"
    "nordvpn"
    # Not nixpkgs' ollama: only the official build ships the MLX runtime.
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

  system.defaults.dock.persistent-apps = [
    "/Applications/Ghostty.app"
    "/Applications/Slack.app"
    "/Applications/Google Chrome.app"
    "/Applications/Visual Studio Code.app"
    "/Applications/IntelliJ IDEA.app"
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

  # Host metrics for terraform/local/'s Prometheus.
  services.prometheus.exporters.node = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9100;
  };

  # Matches the home recorded in dscl; nix-darwin can't change it.
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
