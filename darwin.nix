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
  # Scheduled rather than nix.settings.auto-optimise-store, which has known
  # store-corruption issues on macOS.
  nix.optimise.automatic = true;

  # Cachix binary cache for herdr's prebuilt binary (not in nixpkgs).
  nix.extraOptions = ''
    extra-substituters = https://herdr.cachix.org
    extra-trusted-public-keys = herdr.cachix.org-1:3nH7IStRsS0ASfdonA0DCRR2ZrSCeWitZ7Kwew0cR4I=
  '';

  # terraform is BSL 1.1 (unfree), so allow it explicitly.
  nixpkgs.config.allowUnfreePredicate =
    pkg:
    builtins.elem (lib.getName pkg) [
      "terraform"
    ];

  # Touch ID for sudo (falls back to a password on Macs without it).
  # reattach: needed for Touch ID to work inside herdr (a multiplexer).
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

  # CapsLock -> Left Control. Applied with hidutil (no --matching, so every
  # keyboard, not one per-device entry like System Settings' Modifier Keys),
  # both on rebuild and at boot via nix-darwin's activate-system daemon.
  system.keyboard = {
    enableKeyMapping = true;
    remapCapsLockToControl = true;
  };

  system.defaults = {
    NSGlobalDomain = {
      InitialKeyRepeat = 12;
      KeyRepeat = 1;
      # F1-F12 send function keys; media controls need fn.
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

    # The globe/fn key switches input source (ABC <-> Japanese) instead of
    # opening the emoji picker. Takes effect after a restart.
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
    };
  };

  homebrew = {
    enable = true;
    onActivation = {
      autoUpdate = true;
      upgrade = true;
      # Undeclared casks are auto-uninstalled via `brew bundle --zap --force-cleanup`.
      cleanup = "zap";
    };
    # casks are declared per-host (hosts/<hostname>/darwin.nix)
  };
}
