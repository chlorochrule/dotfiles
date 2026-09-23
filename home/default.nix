{
  config,
  pkgs,
  lib,
  herdr,
  hostname,
  ...
}:
let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  linkDotfile = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";

  # Merges home/claude/<name>/ (all machines) with
  # hosts/<hostname>/claude/<name>/ (this machine only, if present) into
  # ~/.claude/<name>/ at the file level. See .claude/rules/nix-hosts.md.
  claudeDirNames = [
    "commands"
    "skills"
    "agents"
    "hooks"
  ];

  readDirIfExists = path: if builtins.pathExists path then builtins.readDir path else { };

  claudeMergedEntriesFor =
    name:
    let
      commonPath = ./claude + "/${name}";
      hostPath = ../hosts/${hostname}/claude + "/${name}";
      commonRel = "home/claude/${name}";
      hostRel = "hosts/${hostname}/claude/${name}";
      toEntries =
        relDir: files:
        lib.mapAttrs' (
          fname: _:
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
    ".claude/statusline.sh".source = linkDotfile "home/claude/statusline.sh";

    "Pictures/ss/.keep".text = "";
  };

  xdg.configFile."nvim".source = linkDotfile ".config/nvim";
  xdg.configFile."herdr/config.toml".source = linkDotfile ".config/herdr/config.toml";

  home.packages =
    with pkgs;
    [
      tig
      ghq
      cloc
      tree
      # Picked up by fzf-lua (grep/files/preview).
      ripgrep
      fd
      bat
      neovim
      # Required by nvim-treesitter's `main` branch — see .claude/rules/nvim.md.
      tree-sitter
      jq
      yq
      awscli2
      # nixpkgs disables gcloud's own component manager, so extra components
      # are declared here instead of `gcloud components install`.
      # gke-gcloud-auth-plugin: required by kubectl to authenticate to GKE.
      (google-cloud-sdk.withExtraComponents [
        google-cloud-sdk.components.gke-gcloud-auth-plugin
      ])
      gnupg
      gitleaks
      nodejs
      nil
      # Format-on-save via conform.nvim (terraform below doubles as one).
      nixfmt
      stylua
      terraform
      pandoc
      editorconfig-checker
      # Also picked up by bashls (nvim) for diagnostics.
      shellcheck
      gh
      wget
      gnumake
      # Syntax-aware search/rewrite (`ast-grep run -p 'foo($A)' -r 'bar($A)'`),
      # for refactors where a regex would also hit strings and comments.
      ast-grep
    ]
    ++ [
      herdr
      # herdr-nix's package ships no zsh completion; generate it at build
      # time rather than `eval`ing `herdr completion zsh` on every shell start.
      (pkgs.runCommand "herdr-zsh-completion" { } ''
        mkdir -p $out/share/zsh/site-functions
        ${herdr}/bin/herdr completion zsh > $out/share/zsh/site-functions/_herdr
      '')
    ];

  programs.mise = {
    enable = true;
    enableZshIntegration = true;
    globalConfig.tools = {
      uv = "latest";
      deno = "latest";
    };
  };

  # `nh darwin switch` wraps darwin-rebuild with a build tree
  # (nix-output-monitor) and a diff of what changes. clean isn't enabled:
  # darwin.nix's nix.gc already does the periodic GC.
  programs.nh = {
    enable = true;
    darwinFlake = dotfiles;
  };

  # command-not-found suggests which nixpkgs package provides a missing
  # command; `, <cmd>` runs it once without installing. Both read the
  # prebuilt database from the nix-index-database flake input.
  programs.nix-index = {
    enable = true;
    enableZshIntegration = true;
  };
  programs.nix-index-database.comma.enable = true;

  # Used by services/langfuse/.envrc etc. to auto-load per-directory .env files.
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    # Cached, GC-rooted `use flake` for per-project flake devShells.
    nix-direnv.enable = true;
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      # user.name/email are declared per-host (hosts/<hostname>/home.nix)
      ghq.root = "~/src";
      core.editor = "nvim";
      rebase.autostash = true;
      pull.rebase = false;
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
      fetch.prune = true;
      diff.algorithm = "histogram";
      merge.conflictStyle = "zdiff3";
      # From "How Core Git Developers Configure Git" (GitButler blog), minus
      # the ones that delete data (fetch.pruneTags) or change pull behavior.
      column.ui = "auto";
      branch.sort = "-committerdate";
      tag.sort = "version:refname";
      diff.colorMoved = "plain"; # delta renders moved lines distinctly
      push.followTags = true;
      help.autocorrect = "prompt";
      commit.verbose = true;
      rebase.autoSquash = true;
      rebase.updateRefs = true;
      alias.get = "!ghq get";
      # Structural diffs via difftastic, alongside (not instead of) delta:
      # diff.external is only set per-invocation, so plain `git diff` keeps
      # going through delta. log/show ignore diff.external without --ext-diff.
      alias.dft = "-c diff.external=difft diff";
      alias.dlog = "-c diff.external=difft log -p --ext-diff";
      alias.dshow = "-c diff.external=difft show --ext-diff";
      # Distributed via init.templateDir, not programs.git.hooks — see
      # .claude/rules/nix-hosts.md for why.
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

  # Installs difft for the git dft/dlog/dshow aliases above. git.enable is
  # left off: it would set diff.external globally and replace delta.
  programs.difftastic.enable = true;

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true; # n/N jumps between files
      line-numbers = true;
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
    package = null; # Uses the Homebrew cask app; Nix manages only the config file
    settings = {
      macos-option-as-alt = true;

      font-family = [
        "Menlo"
        "Sarasa Mono J"
        "Symbols Nerd Font Mono"
      ];
      font-size = 14;

      cursor-style-blink = false;

      bell-features = "audio,attention,title,border";

      selection-word-chars = "/-+\\\\~_.";

      scrollback-limit = 1000000000; # 1GB, lazily allocated — effectively unlimited in practice

      unfocused-split-opacity = 0.6;

      link-url = true; # cmd+click opens URLs in the system default app (Ghostty's default; set explicitly)

      # Over ssh, send TERM=xterm-256color (remotes lack xterm-ghostty's
      # terminfo). ssh-terminfo is left off: it installs that terminfo into
      # the remote's ~/.terminfo, i.e. writes files on hosts that may not be
      # mine. Unlisted features (cursor, title, path, ...) keep their defaults.
      shell-integration-features = "ssh-env";

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
    dotDir = "${config.xdg.configHome}/zsh";
    enableCompletion = true;
    syntaxHighlighting.enable = true;
    autosuggestion.enable = true;
    historySubstringSearch.enable = true;

    history = {
      # Kept at the pre-XDG-migration path so existing history isn't orphaned.
      path = "${config.home.homeDirectory}/.zsh_history";
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
      # Add Homebrew completions (for packages with `brew completions link`) to fpath
      if command -v brew &> /dev/null; then
        fpath=("$(brew --prefix)/share/zsh/site-functions" $fpath)
      fi

      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
      zstyle ':completion:*' ignore-parents parent pwd ..
      zstyle ':completion:*:processes' command 'ps x -o pid,s,args'

      autoload -Uz compinit
      for dump in ''${ZDOTDIR:-$HOME}/.zcompdump(N.mh+24); do
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

        # zsh's default kills the whole line regardless of cursor position;
        # override to bash/readline-style (only before the cursor).
        bindkey '^U' backward-kill-line

        # herdr ignore keys (keep the 'C-g prefix free of zsh's own zle binding)
        bindkey -r '\C-g'

        # ghq fuzzy cd (MRU-first, like the old peco-src)
        ghq-fzf-cd() {
          local ghq_root mru_file selected d
          local -a mru
          ghq_root="$(ghq root)"
          mru_file="$XDG_CACHE_HOME/ghq-fzf/mru.txt"
          mkdir -p "$XDG_CACHE_HOME/ghq-fzf"

          # Drop deleted repos from the MRU list
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

        # exec herdr (bare `herdr` auto-attaches/creates the default session)
        if ! command -v herdr &> /dev/null; then
            echo "herdr not found" 1>&2
        else
            if [[ "$TERM_PROGRAM" == "ghostty" && -z "$HERDR_ENV" && -n "$PS1" ]]; then
                exec herdr
            fi
        fi
      ''
      (lib.mkOrder 1500 ''
        # uv (ordered after mise activates). Guarded because uv/uvx aren't
        # on PATH yet before first provisioning, which prints "command not
        # found" on every shell start otherwise.
        command -v uv >/dev/null 2>&1 && eval "$(uv generate-shell-completion zsh)"
        command -v uvx >/dev/null 2>&1 && eval "$(uvx --generate-shell-completion zsh)"
      '')
    ];
  };

  # Reload a running herdr server's config after a rebuild changes it
  # (no-op if no server is running).
  home.activation.herdrReloadConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${herdr}/bin/herdr server reload-config >/dev/null 2>&1 || true
  '';
}
