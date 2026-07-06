{ config, pkgs, lib, ... }:
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

  xdg.configFile."nvim".source = linkDotfile ".config/nvim";

  home.file.".claude/CLAUDE.md".source = linkDotfile "home/claude/CLAUDE.md";

  home.file."Pictures/ss/.keep".text = "";

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
    gitleaks
    nodejs
    nil
    terraform
    direnv
    pandoc
    editorconfig-checker
    gh
    wget
    gnumake
  ];

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    globalConfig.tools = {
      uv = "latest";
      deno = "latest";
    };
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      # user.name/emailはホスト固有(hosts/<hostname>/home.nix)で宣言する
      ghq.root = "~/src";
      core.editor = "nvim";
      rebase.autostash = true;
      pull.rebase = false;
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      alias.get = "!ghq get";
    };
    hooks.pre-commit = pkgs.writeShellScript "gitleaks-pre-commit" ''
      set -eu
      ${pkgs.gitleaks}/bin/gitleaks protect --staged --redact -v
    '';
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [ "--layout=reverse" ];
  };

  programs.eza = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.ghostty = {
    enable = true;
    package = null; # Homebrew caskのghosttyアプリを使う。設定ファイルのみNix管理
    settings = {
      macos-option-as-alt = true;

      font-family = [ "Menlo" "Sarasa Mono J" "Symbols Nerd Font Mono" ];
      font-size = 14;

      cursor-style-blink = false;

      bell-features = "audio,attention,title,border";

      selection-word-chars = "/-+\\\\~_.";

      scrollback-limit = 1000000000; # 1GB、遅延確保なので実用上ほぼ無制限

      unfocused-split-opacity = 0.6;

      link-url = true; # cmd+クリックでURLをシステムのデフォルトアプリで開く(Ghosttyのデフォルト値だが明示)

      keybind = [
        "global:ctrl+i=toggle_visibility"
      ];
    };
  };

  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;
      format = "$username$hostname$directory$character";
      right_format = "$git_branch$git_state$git_status";

      username = {
        style_user = "cyan";
        style_root = "bold underline cyan";
        format = "[$user]($style)";
        show_always = true;
      };

      hostname = {
        ssh_only = true;
        format = "[$hostname]($style) ";
        style = "white";
      };

      directory = {
        style = "cyan";
        format = "[\\[$path\\]]($style) ";
        truncation_length = 1;
        truncation_symbol = "";
      };

      character = {
        success_symbol = "";
        error_symbol = "";
        vicmd_symbol = "";
      };

      git_branch = {
        format = "[($branch)]($style)";
        style = "green";
      };

      git_state = {
        format = "[|$state]($style)";
        style = "red";
      };

      git_status.disabled = true;
    };
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

    initContent = lib.mkMerge [
      ''
      # Rancher Desktop
      export PATH="$HOME/.rd/bin:$PATH"

      export GPG_TTY=$TTY

      # zshのデフォルトはkill-whole-line(カーソル位置に関わらず行全体を削除)。
      # bash/readline風にカーソルより前だけ削除する挙動に上書きする
      bindkey '^U' backward-kill-line

      # tmux ignore keys
      bindkey -r '\C-g'

      # ghq fuzzy cd (MRU-first, like the old peco-src)
      ghq-fzf-cd() {
        local ghq_root mru_dir mru_file mru_list selected
        ghq_root="$(git config ghq.root)"
        mru_dir="$XDG_CACHE_HOME/ghq-fzf"
        mru_file="$mru_dir/mru.txt"
        mkdir -p "$mru_dir"
        [ -f "$mru_file" ] || touch "$mru_file"

        mru_list=$(cat "$mru_file")
        : > "$mru_file"
        echo "$mru_list" | xargs -I DIR sh -c "test -d $(ghq root)/DIR && echo DIR >> $mru_file"

        selected="$({ cat "$mru_file"; ghq list; } | awk '!a[$0]++' | fzf)"

        if [ -n "$selected" ]; then
          BUFFER="builtin cd $ghq_root/$selected"
          zle accept-line
          echo "$(echo "$selected" | cat - "$mru_file" | awk '!a[$0]++')" > "$mru_file"
        fi
        zle reset-prompt
      }
      zle -N ghq-fzf-cd
      bindkey '^L' ghq-fzf-cd

      # word separator
      autoload -Uz select-word-style
      select-word-style default
      zstyle ':zle:*' word-chars " /=;@:{},.&'\"|"
      zstyle ':zle:*' word-style unspecified

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
      ''
      (lib.mkOrder 1500 ''
        # uv(miseがactivateされた後に実行する必要があるため優先度を上げている)
        eval "$(uv generate-shell-completion zsh)"
        eval "$(uvx --generate-shell-completion zsh)"
      '')
    ];
  };
}
