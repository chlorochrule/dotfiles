#!/bin/sh
has() {
    type "${1:?Missing argument}" &>/dev/null
}

export DOTHOME="${HOME}/.dotfiles"

[[ ! has "git" ]] && echo "`git` is not installed" >&2 && exit 1

git clone git@github.com:chlorochrule/dotfiles.git "${DOTHOME}"

mkdir -p "${HOME}/.config"
mkdir -p "${HOME}/bin"
mkdir -p "${HOME}/src"

xargs -I OBJ ln -sf "${DOTHOME}/OBJ" "${HOME}/OBJ" < "${DOTHOME}/init/links.txt"

# preparations
case ${OSTYPE} in
    darwin*)
        # mac
        sh "${DOTHOME}/init/mac"
        ;;
    linux*)
        # ubuntu
        sh "${DOTHOME}/init/ubuntu"
        ;;
esac

# brew install
xargs brew install < formulae.txt

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
ANACONDA = "$(pyenv install --list | grep anaconda | tail -n 1)"
pyenv install ${ANACONDA} | tr -d "\ "
pyenv rehash
ln -sf "${PYENV_ROOT}/versions/${ANACONDA}" "${PYENV_ROOT}/anaconda"
export PATH="${PYENV_ROOT}/anaconda/bin:$PATH"

pip install -r "${DOTHOME}/init/requrements.txt"

tic ${DOTHOME}/init/xterm-256color-italic.terminfo

has "nvim" && git config --global core.editor nvim && nvim
