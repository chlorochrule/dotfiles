#!/bin/sh
has() {
    type "${1:?Missing argument}" &>/dev/null
}

mkdir -p "${HOME}/.config"
mkdir -p "${HOME}/.cache"
mkdir -p "${HOME}/.local/share"
mkdir -p "${HOME}/bin"
mkdir -p "${HOME}/src"

export XDG_CONFIG_HOME=${HOME}/.config
export XDG_CACHE_HOME=${HOME}/.cache
export XDG_DATA_HOME=${HOME}/.local/share
export DOTHOME="${HOME}/.dotfiles"

! has "git" && echo "`git` is not installed" >&2 && exit 1

git clone https://github.com/chlorochrule/dotfiles "${DOTHOME}"

xargs -I OBJ ln -sf "${DOTHOME}/OBJ" "${HOME}/OBJ" < "${DOTHOME}/init/links.txt"

# preparations
case ${OSTYPE} in
    darwin*)
        # mac
        # xcode
        xcode-select --install
        # brew
        ruby -e "$(curl -fsSL https://raw.github.com/Homebrew/homebrew/go/install)"
        ;;
    linux*)
        # ubuntu
        # linuxbrew
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/Linuxbrew/install/master/install.sh)"
        test -d ~/.linuxbrew && PATH="$HOME/.linuxbrew/bin:$HOME/.linuxbrew/sbin:$PATH"
        test -d /home/linuxbrew/.linuxbrew && PATH="/home/linuxbrew/.linuxbrew/bin:/home/linuxbrew/.linuxbrew/sbin:$PATH"
        test -r ~/.bash_profile && echo "export PATH='$(brew --prefix)/bin:$(brew --prefix)/sbin'":'"$PATH"' >>~/.bash_profile
        echo "export PATH='$(brew --prefix)/bin:$(brew --prefix)/sbin'":'"$PATH"' >>~/.profile
        export PATH="$(brew --prefix)/bin:$(brew --prefix)/sbin:$PATH"
        ;;
esac

# brew install
xargs brew install < "${DOTHOME}/init/formulae.txt"

# brew hook
case ${OSTYPE} in
    darwin*)
        # mac
        :
        ;;
    linux*)
        # ubuntu
        export ZPLUG_HOME="$(brew --prefix)/opt/zplug"
        source ${ZPLUG_HOME}/init.zsh
        ;;
esac

# anaconda init
export PYENV_ROOT="${HOME}/.pyenv"
export PATH="${PYENV_ROOT}/bin:${PATH}"
eval "$(pyenv init -)"
ANACONDA=$(pyenv install --list | grep anaconda | tail -n 1 | tr -d "\ ")
pyenv install ${ANACONDA}
pyenv rehash
ln -sf "${PYENV_ROOT}/versions/${ANACONDA}" "${PYENV_ROOT}/anaconda"
export PATH="${PYENV_ROOT}/anaconda/bin:$PATH"

pip install -r "${DOTHOME}/init/requirements.txt"

# apt
case ${OSTYPE} in
    linux*)
        # ubuntu
        sudo apt install xsel xdotool build-essential
        ;;
esac

has "nvim" && git config --global core.editor nvim && nvim
