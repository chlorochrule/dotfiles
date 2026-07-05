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
  home.file.".claude/commands".source =
    linkDotfile "hosts/MacBookPro-minami/claude/commands";
  home.file.".claude/skills".source =
    linkDotfile "hosts/MacBookPro-minami/claude/skills";
  home.file.".claude/agents".source =
    linkDotfile "hosts/MacBookPro-minami/claude/agents";
  home.file.".claude/hooks".source =
    linkDotfile "hosts/MacBookPro-minami/claude/hooks";
  home.file.".claude/CLAUDE.md".source =
    linkDotfile "hosts/MacBookPro-minami/claude/CLAUDE.md";
}
