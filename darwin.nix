{
  pkgs,
  lib,
  username,
  ...
}:
{
  system.stateVersion = 6;
  system.primaryUser = username;

  users.users.${username}.home = "/Users/${username}";

  documentation.enable = false;

  nix.settings.experimental-features = "nix-command flakes";

  nix.gc = {
    automatic = true;
    # Sundays 03:00
    interval = {
      Weekday = 0;
      Hour = 3;
      Minute = 0;
    };
    options = "--delete-older-than 30d";
  };
  # Not auto-optimise-store: it can corrupt the store on macOS.
  nix.optimise.automatic = true;

  # herdr's prebuilt binary.
  nix.extraOptions = ''
    extra-substituters = https://herdr.cachix.org
    extra-trusted-public-keys = herdr.cachix.org-1:3nH7IStRsS0ASfdonA0DCRR2ZrSCeWitZ7Kwew0cR4I=
  '';

  # BSL 1.1
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "terraform"
    ];

  # reattach: needed inside herdr.
  security.pam.services.sudo_local = {
    touchIdAuth = true;
    reattach = true;
  };

  environment.systemPackages = [ pkgs.vim ];

  fonts.packages = [
    pkgs.nerd-fonts.symbols-only
    pkgs.sarasa-gothic
  ];

  environment.systemPath = [
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
  ];

  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  system.defaults = {
    NSGlobalDomain = {
      InitialKeyRepeat = 12;
      KeyRepeat = 1;
      "com.apple.keyboard.fnState" = true;
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

    # Takes effect after a restart.
    hitoolbox.AppleFnUsageType = "Change Input Source";

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
      wvous-br-corner = 14; # bottom-right hot corner: Quick Note
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
      # Written as one dict: hotkeys set only in System Settings revert.
      "com.apple.symbolichotkeys".AppleSymbolicHotKeys = {
        # Next window of the same app: Option+Tab (65535 none, 48 Tab, 524288 Option).
        "27" = {
          enabled = true;
          value = {
            type = "standard";
            parameters = [
              65535
              48
              524288
            ];
          };
        };
      };
    };
  };

  # Apply symbolichotkeys changes without logging out.
  system.activationScripts.postActivation.text = ''
    launchctl asuser "$(id -u -- ${username})" sudo --user=${username} -- \
      /System/Library/PrivateFrameworks/SystemAdministration.framework/Resources/activateSettings -u
  '';

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      cleanup = "zap";
    };
    greedyCasks = true;
    # casks are declared per-host (hosts/<hostname>/darwin.nix)
  };
}
