{ pkgs, lib, username, ... }: {
  system.stateVersion = 6;
  system.primaryUser = username;

  users.users.${username}.home = "/Users/${username}";

  documentation.enable = false;

  nix.settings.experimental-features = "nix-command flakes";

  # herdr(nixpkgs未収録)のprebuiltバイナリをソースビルドせず取得するためのcachix設定
  nix.extraOptions = ''
    extra-substituters = https://herdr.cachix.org
    extra-trusted-public-keys = herdr.cachix.org-1:3nH7IStRsS0ASfdonA0DCRR2ZrSCeWitZ7Kwew0cR4I=
  '';

  # terraformはBSL1.1(unfree)なので個別に許可する
  nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "terraform"
  ];

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
      AppleInterfaceStyle = "Dark";
    };

    trackpad = {
      Clicking = true;
      Dragging = true;
      TrackpadRightClick = true;
    };

    universalaccess = {
      reduceMotion = true;
    };

    menuExtraClock = {
      ShowDayOfWeek = true;
      ShowAMPM = true;
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
      wvous-br-corner = 14;  # 右下ホットコーナー: クイックメモ
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
      autoUpdate = true;
      upgrade = true;
      # Homebrew 6.0.22で`--cleanup`フラグが廃止され、nix-darwin-25.11ブランチ側の
      # 対応(`brew bundle cleanup`への切り替え)がまだ未リリースのため一時的にnoneへ退避。
      # 修正が25.11に取り込まれ次第zapへ戻す。
      cleanup = "none";
    };
    # casksはホスト固有(hosts/<hostname>/darwin.nix)で宣言する
  };
}
