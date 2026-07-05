{ pkgs, username, ... }: {
  system.stateVersion = 6;
  system.primaryUser = username;

  users.users.${username}.home = "/Users/${username}";

  documentation.enable = false;

  nix.settings.experimental-features = "nix-command flakes";

  environment.systemPackages = [ pkgs.vim ];

  environment.systemPath = [ "/opt/homebrew/bin" "/opt/homebrew/sbin" ];

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";  # casks棚卸し完了(2026-07-05)、noneからzapへ変更
    };
    casks = [
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
      "slack"
      "spotify"
      "visual-studio-code"
      "wireshark-app"
      "zoom"
    ];
  };
}
