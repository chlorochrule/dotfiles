{ pkgs, ... }: {
  home.stateVersion = "25.11";

  home.packages = [ pkgs.mise ];

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

  programs.zsh = {
    enable = true;
    initContent = ''
      eval "$(mise activate zsh)"
    '';
  };
}
