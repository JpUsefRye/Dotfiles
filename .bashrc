#!/usr/bin/env bash
# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package 

# Setting up the locale
LANG=en_US.UTF-8
MYNAME=JpUsefRye

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# ┌─[bl4ckvghost@jpusefrye]─[~]
# └──╼ λ 

PS1="\[\033[0;31m\]\342\224\214\342\224\200\$([[ \$? != 0 ]] && echo \"[\[\033[0;31m\]\342\234\227\[\033[0;37m\]]\342\224\200\")[$(if [[ ${EUID} == 0 ]]; then echo '\[\033[01;31m\]root\[\033[01;33m\]@\[\033[01;96m\]\h'; else echo '\[\033[0;39m\]\u\[\033[01;33m\]@\[\033[01;96m\]\h'; fi)\[\033[0;31m\]]\342\224\200[\[\033[0;32m\]\w\[\033[0;31m\]]\n\[\033[0;31m\]\342\224\224\342\224\200\342\224\200\342\225\274 \[\033[0m\]\[\e[01;33m\]λ\[\e[0m\] "

unset color_prompt force_color_prompt


# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

# Bash Insulter
if [ -f /opt/bash-insulter/src/bash.command-not-found ]; then
    source /opt/bash-insulter/src/bash.command-not-found
fi

# Aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
fi

alias hello="echo 'Not you again'"
alias vi="vim" # Fix vi issue
alias mapscii="telnet mapscii.me"
alias open="xdg-open"
alias ll="ls -l"
alias grep="grep --color=auto"

# Terminal Interface
figlet "$MYNAME"
fortune | cowsay -f moose
echo -ne "Today is:\t\t" `date`; echo ""<<< Today
echo -e "Kernel Information: \t" `uname -smr`

# Some PATH Variables and exports
PATH="$(ruby -e 'print Gem.user_dir')/bin:$PATH"
PATH="$HOME/.node_modules/bin:$PATH"
export PATH="$PATH:$HOME/go/bin"
export npm_config_prefix=~/.node_modules
export GEM_HOME=$HOME/.gem
export PATH=/usr/lib/jvm/java-8-openjdk/jre/bin/:$PATH
