{ pkgs, username, ... }: {
  system.stateVersion = 6;
  system.primaryUser = username;

  users.users.${username}.home = "/Users/${username}";

  documentation.enable = false;

  nix.settings.experimental-features = "nix-command flakes";

  environment.systemPackages = [ pkgs.vim ];

  fonts.packages = [ pkgs.nerd-fonts.symbols-only pkgs.sarasa-gothic ];

  environment.systemPath = [ "/opt/homebrew/bin" "/opt/homebrew/sbin" ];

  system.defaults = {
    NSGlobalDomain = {
      InitialKeyRepeat = 12;
      KeyRepeat = 1;
      ApplePressAndHoldEnabled = false;
      NSAutomaticQuoteSubstitutionEnabled = false;
      NSAutomaticDashSubstitutionEnabled = false;
      NSAutomaticCapitalizationEnabled = false;
      NSAutomaticPeriodSubstitutionEnabled = false;
      NSAutomaticSpellingCorrectionEnabled = false;
      AppleShowAllExtensions = true;
      NSWindowResizeTime = 0.001;
    };

    finder = {
      AppleShowAllFiles = true;
      ShowPathbar = true;
      ShowStatusBar = true;
      _FXShowPosixPathInTitle = true;
      FXDefaultSearchScope = "SCcf";
      FXEnableExtensionChangeWarning = false;
    };

    dock = {
      autohide = true;
      autohide-delay = 0.0;
      autohide-time-modifier = 0.4;
      showhidden = true;
      expose-animation-duration = 0.12;
    };

    screencapture = {
      location = "/Users/${username}/Pictures/ss";
      type = "png";
      disable-shadow = true;
      include-date = false;
    };

    CustomUserPreferences = {
      "com.apple.desktopservices" = {
        DSDontWriteNetworkStores = true;
        DSDontWriteUSBStores = true;
      };
      "com.apple.screencapture" = {
        name = "ss";
      };
    };
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = false;
      upgrade = false;
      cleanup = "zap";  # casks棚卸し完了(2026-07-05)、noneからzapへ変更
    };
    # casksはホスト固有(hosts/<hostname>/darwin.nix)で宣言する
  };
}
