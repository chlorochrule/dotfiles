defaults write -g InitialKeyRepeat -int 12
defaults write -g KeyRepeat -int 1

defaults write -g ApplePressAndHoldEnabled -bool false

defaults write -g NSAutomaticQuoteSubstitutionEnabled -bool false
defaults write -g NSAutomaticDashSubstitutionEnabled -bool false
defaults write -g NSAutomaticCapitalizationEnabled -bool false
defaults write -g NSAutomaticPeriodSubstitutionEnabled -bool false
defaults write -g NSAutomaticSpellingCorrectionEnabled -bool false

defaults write -g AppleShowAllExtensions -bool true

defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true

defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.4
defaults write com.apple.dock showhidden -bool true

defaults write com.apple.dock expose-animation-duration -float 0.12
defaults write -g NSWindowResizeTime -float 0.001

mkdir -p ~/Pictures/ss
defaults write com.apple.screencapture location ~/Pictures/ss
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true
defaults write com.apple.screencapture name "ss"
defaults write com.apple.screencapture include-date -bool false

killall Finder Dock SystemUIServer