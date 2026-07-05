{ pkgs, ... }: {
  home.stateVersion = "25.11";

  home.packages = [ pkgs.mise ];

  programs.zsh = {
    enable = true;
    initContent = ''
      eval "$(mise activate zsh)"
    '';
  };
}
