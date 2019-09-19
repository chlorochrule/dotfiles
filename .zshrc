autoload -Uz terminfo

has() {
    type "${1:?Missing argument}" &>/dev/null
}

# zplug
has "brew" && export ZPLUG_HOME="$(brew --prefix)/opt/zplug"
[ -z "${ZPLUG_HOME}" ] && export ZPLUG_HOME="${HOME}/.zplug"
source $ZPLUG_HOME/init.zsh

zplug 'zsh-users/zsh-completions'
zplug 'zsh-users/zaw'
zplug 'zsh-users/zsh-syntax-highlighting'
zplug check || zplug install

zplug load


# env
export XDG_CONFIG_HOME="${HOME}/.config"
export XDG_CACHE_HOME="${HOME}/.cache"
export XDG_DATA_HOME="${HOME}/.local/share"
export DLHOME="${HOME}/Download"
# export TERM="xterm-256color"
export GITHUB_USER="$(git config user.name | tr -d '\n')"
export WORDCHARS='*?_.[]~-=&;!#$%^(){}<>' 

fpath=("${XDG_CONFIG_HOME}/zsh/completions" $fpath)

# mac or linux
case ${OSTYPE} in
    darwin*)
        # mac
        export CLICOLOR=1
        alias ls='ls -G -F'
        alias tac='tail -r'
        ;;
    linux*)
        # linux
        alias ls='ls -F --color=auto'
        ;;
esac

alias peco='peco --selection-prefix=\*'


# function
peco-src() {
    local repos_root
    local ghq_root
    local ghq_list
    local mru_list
    ghq_root="$(git config ghq.root)"
    ghq_list="$(ghq list)"
    local peco_src_dir="$XDG_CACHE_HOME/peco-src"
    mkdir -p $peco_src_dir
    if [ ! -f "$peco_src_dir/mru_src.txt" ]; then
        touch "$peco_src_dir/mru_src.txt"
    fi
    repos_root="$({cat $peco_src_dir/mru_src.txt ; ghq list ; } | awk '!a[$0]++' | peco)"
    if [ -n "$repos_root" ]; then
        BUFFER="builtin cd $ghq_root/$repos_root"
        zle accept-line
        echo "`echo "$repos_root" | cat - ${peco_src_dir}/mru_src.txt | awk '!a[$0]++'`" > $peco_src_dir/mru_src.txt
    fi
    zle reset-prompt
}

function peco-history-selection() {
    BUFFER=`history -n 1 | tac | awk '!a[$0]++' | peco`
    CURSOR=$#BUFFER
    zle reset-prompt
}

zle -N peco-history-selection
zle -N peco-src

# chlorochrule's original keybind
bindkey -v
bindkey "jj" vi-cmd-mode
bindkey -M viins '^?' backward-delete-char
bindkey -M viins '^A' beginning-of-line
bindkey -M viins '^D' delete-char-or-list
bindkey -M viins '^E' end-of-line
bindkey -M viins '^N' down-line-or-history
bindkey -M viins '^P' up-line-or-history
bindkey -M viins '^U' backward-kill-line
bindkey -M viins '^W' backward-kill-word
bindkey -M viins '^H'  backward-delete-char
bindkey -M viins '^Y' yank
bindkey -M viins '^[b'  forward-word
bindkey -M viins '^[f'  backward-word

bindkey '\C-r' peco-history-selection
bindkey '\C-l' peco-src
# bindkey -M viins '^J' peco-src-next
# bindkey -M viins '^K' peco-src-previous

# tmux ignore keys
bindkey -r '\C-g'
bindkey -r '\C-t'

# history
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000


# prompt style
autoload -Uz colors; colors
tmp_prompt="%{${fg[cyan]}%}%n[%c] %{${reset_color}%}"
# if root user
[ ${UID} -eq 0 ] && tmp_prompt="%B%U${tmp_prompt}%u%b"
PROMPT=$tmp_prompt
# if ssh
[ -n "${REMOTEHOST}${SSH_CONNECTION}" ] && PROMPT="%{${fg[white]}%}${HOST%%.*} ${PROMPT}"


# word separator
autoload -Uz select-word-style
select-word-style default
zstyle ':zle:*' word-chars " /=;@:{},|"
zstyle ':zle:*' word-style unspecified


# complement
autoload -Uz compinit && compinit -u

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' ignore-parents parent pwd ..
zstyle ':completion:*:sudo:*' command-path /usr/local/sbin /usr/local/bin \
                   /usr/sbin /usr/bin /sbin /bin /usr/X11R6/bin
zstyle ':completion:*:processes' command 'ps x -o pid,s,args'
bindkey "^[[Z" reverse-menu-complete


# vcs
autoload -Uz vcs_info
autoload -Uz add-zsh-hook

zstyle ':vcs_info:*' formats '%F{green}(%s)-[%b]%f'
zstyle ':vcs_info:*' actionformats '%F{red}(%s)-[%b|%a]%f'

function _update_vcs_info_msg() {
    LANG=en_US.UTF-8 vcs_info
    RPROMPT="${vcs_info_msg_0_}"
}
add-zsh-hook precmd _update_vcs_info_msg

# option
## general
setopt print_eight_bit
setopt no_beep
setopt no_flow_control
setopt ignore_eof
setopt interactive_comments
setopt auto_cd
setopt auto_pushd
setopt pushd_ignore_dups
setopt correct

## complement
setopt magic_equal_subst
setopt auto_list
setopt auto_menu
setopt list_packed
setopt list_types

## history
setopt share_history
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_reduce_blanks

## glob
setopt extended_glob
unsetopt caseglob


# alias
alias la='ls -a'
alias ll='ls -la'

alias cp='cp -i'
alias mv='mv -i'

alias mkdir='mkdir -p'

alias p='pwd'
alias gip='curl ipcheck.ieserver.net'

alias ...='../..'
alias ....='../../..'
alias .....='../../../..'

alias -g view='nvim -R'
alias -g V='| view'
alias -g G='| grep'

if which pbcopy >/dev/null 2>&1 ; then
    # mac
    alias -g clipboard='pbcopy'
elif which xsel >/dev/null 2>&1 ; then
    # linux
    alias -g clipboard='xsel --clipboard --input'
fi

has "nvim" && alias -g vi=nvim
has "hub" && alias -g git=hub


# pyenv and anaconda3
export PYENV_ROOT="$HOME/.pyenv"
export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init -)"
export PATH="$PYENV_ROOT/anaconda/bin:$PATH"

# golang
export PATH="${PATH}:/usr/local/go/bin"
export GOPATH="${HOME}"

# exec tmux
if ! has "tmux"; then
    echo "tmux not found" 1>&2
else
    if [[ -z "${TMUX}" && ! -z "${PS1}" ]]; then
        if tmux has-session &> /dev/null && [[ -n "$(tmux ls | grep -v attached)" ]]; then
            exec tmux a
        else
            exec tmux
        fi
    fi
fi

# pip zsh completion start
function _pip_completion {
  local words cword
  read -Ac words
  read -cn cword
  reply=( $( COMP_WORDS="$words[*]" \
             COMP_CWORD=$(( cword-1 )) \
             PIP_AUTO_COMPLETE=1 $words[1] ) )
}
compctl -K _pip_completion pip
# pip zsh completion end

