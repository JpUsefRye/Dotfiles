export ZSH=$HOME/.oh-my-zsh

# this zsh theme is found in my github repo [https://github.com/M1cR0xft/Dotfiles]
ZSH_THEME="elfasheekh"

LANG=en_US.UTF-8
MYNAME=${USER}                  # replace this with your name
RESOLUTION=1366x768             # replace this with your display size (for ffmpeg)

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# TMUX shit here
if command -v tmux &> /dev/null && [ -n "$PROMPT" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
    exec tmux
fi

alias dir='dir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias ls="ls --color=auto"
alias vi="vim"
alias open="xdg-open"
alias fuckmylife=":(){ :|: & };:" # do not fuck your life

alias nse="ls /usr/share/nmap/scripts/|grep "
alias glog="git log --color --all --date-order --decorate --dirstat=lines,cumulative --stat|less -R"

# Vim every where
function :q() {
    exit 0
}

function q() {
    exit 0
}

function :q!() {
    exit 1
}

# in terminal calculator
function calc() {
    echo "${@}" | bc -l
}

# creates ignore files for git
function gi() {
    curl -L -s https://www.gitignore.io/api/${@}
}

# FFmpeg Stuff
function scrncast(){
    # record screen with audio
    # arguments:
    #   - output.format
    ffmpeg -f x11grab -video_size ${RESOLUTION} -framerate 30 -i :0.0 \
    -f pulse -i default -preset ultrafast -crf 18 -pix_fmt yuv420p ${1}
}

function scrnshot(){
    # take a screen shot
    # arguments
    #   - output.format
    ffmpeg -f x11grab -video_size ${RESOLUTION} -i ${DISPLAY} -vframes 1 ${1}
}

function webcam(){
    # record webcam with audio
    # arguments
    #   - output.format
    WEBCAM_RESOLUTION=640x480
    ffmpeg -f v4l2 -video_size ${WEBCAM_RESOLUTION} -i /dev/video0 -f pulse \
    -i default -c:v libx264 -preset ultrafast -c:a aac ${1}
}

function audiorec(){
    # record audio (microphone)
    # arguments
    #   - output.format
    ffmpeg -f pulse -i default ${1}
}

function gifconverter(){
    # convert video to gif
    # arguments
    #   - frames folder
    #   - target video
    #   - output file output.gif
    FOLDER=${1}
    INPUT=${2}
    OUTPUT=${3}

    mkdir ${FOLDER}
    ffmpeg -i ${INPUT} -vf scale=320:-1:flags=lanczos,fps=10 \
    ${FOLDER}/ffout%03d.png

    convert -loop 0 ${FOLDER}/ffout*.png ${OUTPUT}
}


#--- Terminal Interface ---#
# figlet -f ~/.fonts/Modular.flf "${MYNAME}\n"
# fortune | cowsay -f moose
# IFS='=' OS_NAME_COLOR__=($(cat /etc/os-release|grep ANSI_COLOR))
# IFS='=' OS_NAME__=($(cat /etc/os-release|grep PRETTY_NAME))

# echo -ne "Running on:\t\t \033[$(python -c "print('`echo $OS_NAME_COLOR__[2]`'.replace('\"', ''))")m$(python -c "print('`echo $OS_NAME__[2]`'.replace('\"', ''))")\033[0m\n" # fuck bash fuck zsh
# echo -ne "Today is:\t\t" `date`; echo ""<<< Today
# echo -e "Kernel Information: \t" `uname -smr`

#--- END Terminal Interface ---#

# Sometimes i use this or not?...
#Black='\033[0;30m'        # Black
#Red='\033[0;31m'          # Red
#Green='\033[0;32m'        # Green
#Yellow='\033[0;33m'       # Yellow
#Blue='\033[0;34m'         # Blue
#Purple='\033[0;35m'       # Purple
#Cyan='\033[0;36m'         # Cyan
#White='\033[0;37m'        # White

## Bold
#BBlack='\033[1;30m'       # Black
#BRed='\033[1;31m'         # Red
#BGreen='\033[1;32m'       # Green
#BYellow='\033[1;33m'      # Yellow
#BBlue='\033[1;34m'        # Blue
#BPurple='\033[1;35m'      # Purple
#BCyan='\033[1;36m'        # Cyan
#BWhite='\033[1;37m'       # White

## Background
#On_Black='\033[40m'       # Black
#On_Red='\033[41m'         # Red
#On_Green='\033[42m'       # Green
#On_Yellow='\033[43m'      # Yellow

#NC="\033[m"               # Color Reset
#CR="$(echo -ne '\r')"
#LF="$(echo -ne '\n')"
#TAB="$(echo -ne '\t')"
#ESC="$(echo -ne '\033')"

# XDG stuff
XDG_DESKTOP_DIR="$HOME/Desktop"
XDG_DOCUMENTS_DIR="$HOME/Documents"
XDG_DOWNLOAD_DIR="$HOME/Downloads"
XDG_MUSIC_DIR="$HOME/Music"
XDG_PICTURES_DIR="$HOME/Pictures"
XDG_PUBLICSHARE_DIR="$HOME/Public"
XDG_VIDEOS_DIR="$HOME/Videos"

plugins=(
  git
)

# ===== Auto correction
setopt always_to_end # When completing from the middle of a word, move the cursor to the end of the word
setopt auto_menu # show completion menu on successive tab press. needs unsetop menu_complete to work
setopt auto_name_dirs # any parameter that is set to the absolute name of a directory immediately becomes a name for that directory
setopt complete_in_word # Allow completion from within a word/phrase

unsetopt menu_complete # do not autoselect the first completion entry

# ===== Correction
unsetopt correct_all # spelling correction for arguments
setopt correct # spelling correction for commands

# Sources
source $ZSH/oh-my-zsh.sh
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source /etc/profile.d/jre.sh

ZSH_HIGHLIGHT_HIGHLIGHTERS=(main)

# ZSH highlight style.
ZSH_HIGHLIGHT_STYLES[unknown-token]='none,none'
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=none,none'
ZSH_HIGHLIGHT_STYLES[suffix-alias]='underline'
ZSH_HIGHLIGHT_STYLES[precommand]='underline'
ZSH_HIGHLIGHT_STYLES[globbing]='none'
ZSH_HIGHLIGHT_STYLES[history-expansion]='none'
ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]='none'
ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]='none'
ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]='none'
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='none'
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='none'
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='none'
ZSH_HIGHLIGHT_STYLES[rc-quote]='none'
ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]='none'
ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]='none'
ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]='none'
ZSH_HIGHLIGHT_STYLES[assign]='none'
ZSH_HIGHLIGHT_STYLES[redirection]='none'
ZSH_HIGHLIGHT_STYLES[comment]='fg=black,bold'
ZSH_HIGHLIGHT_STYLES[named-fd]='none'
ZSH_HIGHLIGHT_STYLES[arg0]='none'

if [ -f ~/.zcompdump-$HOST-* ]; then
    rm ~/.zcompdump-$HOST-*
fi

if [ -f ~/.zcompdump ]; then
    rm ~/.zcompdump
fi

# Some PATH Variables and exports
PATH="$(ruby -e 'print Gem.user_dir')/bin:$PATH"
PATH="$HOME/.node_modules/bin:$PATH"
PATH="$HOME/.local/bin:$PATH"
PATH="$HOME/.scripts/bspwm_resize:$PATH"
PATH="$HOME/perl5/bin${PATH:+:${PATH}}"; export PATH;

PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"$HOME/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"; export PERL_MM_OPT;

ZSH_DISABLE_COMPINIT=true

export ZSH_DISABLE_COMPINIT
export TERM=xterm-256color
export TERMINAL=alacritty
export EDITOR="vim"
export GOPATH=$HOME/go/
export BROWSER="firefox"
export CC=gcc
export AS=as
export AR=ar
export CXX=g++
export LD=ld
export TAR=tar
export LIBGL_ALWAYS_SOFTWARE=on
export XDG_CURRENT_DESKTOP='X-Generic'
export QT_X11_NO_MITSHM=1 # fixes the issue when opening qt app with sudo
export PATH="$PATH:$HOME/go/bin"
export npm_config_prefix=~/.node_modules
export GEM_HOME=$HOME/.gem
export PROMPT
