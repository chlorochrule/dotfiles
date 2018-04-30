#!/bin/sh
mkdir -p "${HOME}/.config"
mkdir -p "${HOME}/bin"
mkdir -p "${HOME}/src"

xargs -I OBJ ln -sf "${HOME}/.dotfiles/OBJ" "${HOME}/OBJ" < links.txt

# preparations
case ${OSTYPE} in
    darwin*)
        # mac
        sh ~/.dotfiles/init/mac
        ;;
    linux*)
        # ubuntu
        sh ~/.dotfiles/init/ubuntu
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
        sh ~/.dotfiles/init/ubuntu
        ;;
esac
