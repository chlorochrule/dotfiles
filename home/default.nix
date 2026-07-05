{ config, pkgs, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  linkDotfile = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  home.stateVersion = "25.11";
  xdg.enable = true;

  home.file.".tigrc".source = linkDotfile ".tigrc";
  home.file.".editorconfig".source = linkDotfile ".editorconfig";
  home.file.".tmux.conf".source = linkDotfile ".tmux.conf";

  home.file."bin/tmux-kill-pane".source = linkDotfile "bin/tmux-kill-pane";
  home.file."bin/tmux-kill-session".source = linkDotfile "bin/tmux-kill-session";
  home.file."bin/tmux-renumber-sessions".source = linkDotfile "bin/tmux-renumber-sessions";
  home.file."bin/license".source = linkDotfile "bin/license";

  xdg.configFile."nvim/init.vim".source = linkDotfile ".config/nvim/init.vim";

  home.packages = with pkgs; [
    tig
    ghq
    tmux
    cloc
    tree
    neovim
    jq
    yq
    awscli2
    gnupg
  ];

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    globalConfig.tools.uv = "latest";
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

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    historySubstringSearch.enable = true;

    history = {
      size = 1000000;
      save = 1000000;
      share = true;
      ignoreAllDups = true;
      ignoreSpace = true;
    };

    shellAliases = {
      "..." = "../..";
      "...." = "../../..";
      "....." = "../../../..";
      vi = "nvim";
    };

    plugins = [
      {
        name = "zsh-completions";
        src = pkgs.fetchFromGitHub {
          owner = "zsh-users";
          repo = "zsh-completions";
          rev = "03bae0bf3f9c4ab894f1f11a31ffe7a1e1029879";
          sha256 = "0d4adb5m9j5klh79nxkslf81yxfiic9j3liqvdp62kldfrgnc54m";
        };
      }
    ];

    completionInit = ''
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
      zstyle ':completion:*' ignore-parents parent pwd ..
      zstyle ':completion:*:processes' command 'ps x -o pid,s,args'

      autoload -Uz compinit
      for dump in ~/.zcompdump(N.mh+24); do
        compinit -u
      done
      compinit -u -C

      bindkey "^[[Z" reverse-menu-complete
    '';

    initContent = ''
      # Rancher Desktop
      export PATH="$HOME/.rd/bin:$PATH"

      # uv
      eval "$(uv generate-shell-completion zsh)"
      eval "$(uvx --generate-shell-completion zsh)"

      export GPG_TTY=$TTY

      # tmux ignore keys
      bindkey -r '\C-g'

      # prompt style
      autoload -Uz colors; colors
      tmp_prompt="%{$fg[cyan]%}%n[%c] %{$reset_color%}"
      [ $UID -eq 0 ] && tmp_prompt="%B%U$tmp_prompt%u%b"
      PROMPT=$tmp_prompt
      [ -n "$REMOTEHOST$SSH_CONNECTION" ] && PROMPT="%{$fg[white]%}''${HOST%%.*} $PROMPT"

      # word separator
      autoload -Uz select-word-style
      select-word-style default
      zstyle ':zle:*' word-chars " /=;@:{},.&'\"|"
      zstyle ':zle:*' word-style unspecified

      # vcs
      autoload -Uz vcs_info
      autoload -Uz add-zsh-hook
      zstyle ':vcs_info:*' formats '%F{green}(%s)-[%b]%f'
      zstyle ':vcs_info:*' actionformats '%F{red}(%s)-[%b|%a]%f'
      function _update_vcs_info_msg() {
          LANG=en_US.UTF-8 vcs_info
          RPROMPT=$vcs_info_msg_0_
      }
      add-zsh-hook precmd _update_vcs_info_msg

      # option
      setopt print_eight_bit no_beep no_flow_control ignore_eof interactive_comments
      setopt auto_cd auto_pushd pushd_ignore_dups correct
      setopt magic_equal_subst auto_list auto_menu list_packed list_types
      setopt hist_reduce_blanks
      setopt extended_glob
      unsetopt caseglob

      ## aws
      source ${pkgs.awscli2}/bin/aws_zsh_completer.sh

      # exec tmux
      if ! command -v tmux &> /dev/null; then
          echo "tmux not found" 1>&2
      else
          if [[ "$TERM_PROGRAM" == "ghostty" && -z "$TMUX" && -n "$PS1" ]]; then
              if tmux has-session &> /dev/null && [[ -n "$(tmux ls | grep -v attached)" ]]; then
                  exec tmux a
              else
                  exec tmux
              fi
          fi
      fi
    '';
  };
}
