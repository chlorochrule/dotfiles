{ config, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  linkDotfile = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  programs.git.settings.user = {
    name = "Naoto Minami";
    email = "minami.polly@gmail.com";
  };

  home.file.".claude/settings.json".source =
    linkDotfile "hosts/MacBookPro-minami/claude-settings.json";
}
