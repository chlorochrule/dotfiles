{ config, pkgs, lib, herdr, hostname, ... }:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  linkDotfile = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";

  # ~/.claude/<name>/ を「全マシン共通(home/claude/<name>) + このホスト固有
  # (hosts/<hostname>/claude/<name>、存在すれば)」をファイル単位でマージして構成する。
  # 同名ファイルがあればホスト固有側が優先される。
  # 新規ファイル追加時は(ディレクトリ単位のシンボリックリンクと違い)rebuildが必要。
  # ホスト名を引数(hostname)で受け取るこの関数自体はホストを問わず共通なので、
  # 新規ホストを追加する際にこのロジックをコピーする必要はない
  # (hosts/<hostname>/home.nixにはホスト固有の設定だけを書けばよい)。
  claudeDirNames = [ "commands" "skills" "agents" "hooks" ];

  readDirIfExists = path: if builtins.pathExists path then builtins.readDir path else { };

  claudeMergedEntriesFor = name:
    let
      commonPath = ./claude + "/${name}";
      hostPath = ../hosts/${hostname}/claude + "/${name}";
      commonRel = "home/claude/${name}";
      hostRel = "hosts/${hostname}/claude/${name}";
      toEntries = relDir: files:
        lib.mapAttrs' (fname: _:
          lib.nameValuePair ".claude/${name}/${fname}" { source = linkDotfile "${relDir}/${fname}"; }
        ) files;
    in
    (toEntries commonRel (readDirIfExists commonPath))
    // (toEntries hostRel (readDirIfExists hostPath));
in
{
  home.stateVersion = "25.11";
  xdg.enable = true;

  home.file = lib.foldl' (acc: name: acc // (claudeMergedEntriesFor name)) { } claudeDirNames // {
    ".tigrc".source = linkDotfile ".tigrc";
    ".editorconfig".source = linkDotfile ".editorconfig";

    "bin/license".source = linkDotfile "bin/license";

    ".claude/CLAUDE.md".source = linkDotfile "home/claude/CLAUDE.md";

    "Pictures/ss/.keep".text = "";
  };

  xdg.configFile."nvim".source = linkDotfile ".config/nvim";
  xdg.configFile."herdr/config.toml".source = linkDotfile ".config/herdr/config.toml";

  home.packages = with pkgs; [
    tig
    ghq
    cloc
    tree
    neovim
    # nvim-treesitter(mainブランチ、.config/nvim/lua/plugins/treesitter.lua)が
    # パーサーのビルドに要求する。masterブランチと違い内部コンパイルではなく
    # 外部の`tree-sitter`コマンドを呼ぶため、PATHに無いとビルドが失敗する
    tree-sitter
    jq
    yq
    awscli2
    gnupg
    gitleaks
    nodejs
    nil
    terraform
    pandoc
    editorconfig-checker
    gh
    wget
    gnumake
  ] ++ [
    herdr
  ];

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    globalConfig.tools = {
      uv = "latest";
      deno = "latest";
    };
  };

  # langfuse/.envrc等、ディレクトリ単位で.envを自動生成・読み込みするために使う
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
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
      # programs.git.hooksはグローバルなcore.hooksPathを設定し、全リポジトリの
      # .git/hooks(pre-commit framework等)を無効化してしまうため、templateDirで
      # clone/init時に各リポジトリへフックを複製する方式にしている。
      # テンプレート内のシンボリックリンクはリンクのまま複製されGCで壊れるため、
      # storeのディレクトリを直接指し、gitleaksもstoreパスでなくPATHから呼ぶ。
      init.templateDir = "${pkgs.writeTextFile {
        name = "git-template";
        destination = "/hooks/pre-commit";
        executable = true;
        text = ''
          #!/bin/sh
          set -eu
          if ! command -v gitleaks >/dev/null 2>&1; then
            echo "pre-commit: gitleaks not found in PATH" >&2
            exit 1
          fi
          exec gitleaks git --pre-commit --staged --redact -v
        '';
      }}";
    };
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
    # home-manager 26.05以降、既定値がXDGディレクトリ(~/.config/zsh)へ変わる予定。
    # XDG移行は別途まとめて対応する(TODO)ため、ここでは明示的に現状(homeDirectory)を固定する。
    dotDir = config.home.homeDirectory;
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
      # Homebrewの補完(brew completions link済みのパッケージ)をfpathに追加
      if command -v brew &> /dev/null; then
        fpath=("$(brew --prefix)/share/zsh/site-functions" $fpath)
      fi

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

      # herdr ignore keys(prefix('C-g')をzshのzleバインドと衝突させない)
      bindkey -r '\C-g'

      # ghq fuzzy cd (MRU-first, like the old peco-src)
      ghq-fzf-cd() {
        local ghq_root mru_file selected d
        local -a mru
        ghq_root="$(ghq root)"
        mru_file="$XDG_CACHE_HOME/ghq-fzf/mru.txt"
        mkdir -p "$XDG_CACHE_HOME/ghq-fzf"

        # 削除済みリポジトリをMRUから除く
        if [[ -f $mru_file ]]; then
          for d in "''${(@f)$(<$mru_file)}"; do
            [[ -n $d && -d $ghq_root/$d ]] && mru+=("$d")
          done
        fi

        selected="$({ (( $#mru )) && print -rl -- $mru; ghq list; } | awk '!a[$0]++' | fzf)"

        if [[ -n $selected ]]; then
          print -rl -- "$selected" $mru | awk '!a[$0]++' > "$mru_file"
          BUFFER="builtin cd -- ''${(q)ghq_root}/''${(q)selected}"
          zle accept-line
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

      # exec herdr(引数なしの`herdr`はデフォルトセッションへの
      # アタッチ/新規作成を自動判定するため、tmux版と違いhas-session相当の
      # 分岐が不要)
      if ! command -v herdr &> /dev/null; then
          echo "herdr not found" 1>&2
      else
          if [[ "$TERM_PROGRAM" == "ghostty" && -z "$HERDR_ENV" && -n "$PS1" ]]; then
              exec herdr
          fi
      fi
      ''
      (lib.mkOrder 1500 ''
        # uv(miseがactivateされた後に実行する必要があるため優先度を上げている)。
        # mise未インストール状態(初回provisioning前等)ではuv/uvxがPATHに無く、
        # command not foundがシェル起動ごとに出ることを実際に確認したためガードする
        command -v uv >/dev/null 2>&1 && eval "$(uv generate-shell-completion zsh)"
        command -v uvx >/dev/null 2>&1 && eval "$(uvx --generate-shell-completion zsh)"
      '')
    ];
  };

  # rebuildで.config/herdr/config.tomlが変わった場合、実行中のherdrサーバーに
  # 即時反映する(サーバーが起動していない場合は何もせず無視する)
  home.activation.herdrReloadConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${herdr}/bin/herdr server reload-config >/dev/null 2>&1 || true
  '';
}
