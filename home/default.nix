{ config, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  linkDotfile = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  home.stateVersion = "25.11";

  home.file.".tigrc".source = linkDotfile ".tigrc";
  home.file.".editorconfig".source = linkDotfile ".editorconfig";
  home.file.".tmux.conf".source = linkDotfile ".tmux.conf";

  home.file."bin/tmux-kill-pane".source = linkDotfile "bin/tmux-kill-pane";
  home.file."bin/tmux-kill-session".source = linkDotfile "bin/tmux-kill-session";
  home.file."bin/tmux-renumber-sessions".source = linkDotfile "bin/tmux-renumber-sessions";
  home.file."bin/license".source = linkDotfile "bin/license";

  xdg.configFile."nvim/init.vim".source = linkDotfile ".config/nvim/init.vim";

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      user = {
        name = "Naoto Minami";
        email = "minami.polly@gmail.com";
      };
      ghq.root = "~/src";
      core.editor = "nvim";
      rebase.autostash = true;
      pull.rebase = false;
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };

  programs.zsh.enable = true;
}
