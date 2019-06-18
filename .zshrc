export ZSH=$HOME/.oh-my-zsh

ZSH_THEME="Disassembler"

LANG=en_US.UTF-8
MYNAME=${USER}                  # replace this with your name
RESOLUTION=1366x768             # replace this with your display size (for ffmpeg)

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# TMUX shit here
if command -v tmux &> /dev/null && [ -n "$PROMPT" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
    exec tmux
fi

# zsh insulter
function print_message () {

    local messages
    local message

    messages=(
        "Boooo!"
        "Don't you know anything?"
        "RTFM!"
        "Haha, n00b!"
        "Wow! That was impressively wrong!"
        "Pathetic"
        "The worst one today!"
        "n00b alert!"
        "Your application for reduced salary has been sent!"
        "lol"
        "u suk"
        "lol... plz"
        "plz uninstall"
        "And the Darwin Award goes to.... ${USER}!"
        "ERROR_INCOMPETENT_USER"
        "Incompetence is also a form of competence"
        "Bad."
        "Fake it till you make it!"
        "What is this...? Amateur hour!?"
        "Come on! You can do it!"
        "Nice try."
        "What if... you type an actual command the next time!"
        "What if I told you... it is possible to type valid commands."
        "Y u no speak computer???"
        "This is not Windows"
        "Perhaps you should leave the command line alone..."
        "Please step away from the keyboard!"
        "error code: 1D10T"
        "ACHTUNG! ALLES TURISTEN UND NONTEKNISCHEN LOOKENPEEPERS! DAS KOMPUTERMASCHINE IST NICHT FÜR DER GEFINGERPOKEN UND MITTENGRABEN! ODERWISE IST EASY TO SCHNAPPEN DER SPRINGENWERK, BLOWENFUSEN UND POPPENCORKEN MIT SPITZENSPARKEN. IST NICHT FÜR GEWERKEN BEI DUMMKOPFEN. DER RUBBERNECKEN SIGHTSEEREN KEEPEN DAS COTTONPICKEN HÄNDER IN DAS POCKETS MUSS. ZO RELAXEN UND WATSCHEN DER BLINKENLICHTEN."
        "Pro tip: type a valid command!"
        "Go outside."
        "This is not a search engine."
        "(╯°□°）╯︵ ┻━┻"
        "¯\_(ツ)_/¯"
        "So, I'm just going to go ahead and run rm -rf / for you."
        "Why are you so stupid?!"
        "Perhaps computers is not for you..."
        "Why are you doing this to me?!"
        "Don't you have anything better to do?!"
        "I am _seriously_ considering 'rm -rf /'-ing myself..."
        "This is why you get to see your children only once a month."
        "This is why nobody likes you."
        "Are you even trying?!"
        "Try using your brain the next time!"
        "My keyboard is not a touch screen!"
        "Commands, random gibberish, who cares!"
        "Typing incorrect commands, eh?"
        "Are you always this stupid or are you making a special effort today?!"
        "Dropped on your head as a baby, eh?"
        "Brains aren't everything. In your case they're nothing."
        "I don't know what makes you so stupid, but it really works."
        "You are not as bad as people say, you are much, much worse."
        "Two wrongs don't make a right, take your parents as an example."
        "You must have been born on a highway because that's where most accidents happen."
        "If what you don't know can't hurt you, you're invulnerable."
        "If ignorance is bliss, you must be the happiest person on earth."
        "You're proof that god has a sense of humor."
        "Keep trying, someday you'll do something intelligent!"
        "If shit was music, you'd be an orchestra."
        "How many times do I have to flush before you go away?"
    )

    # If CMD_NOT_FOUND_MSGS array is populated use those messages instead of the defaults
    [[ -n ${CMD_NOT_FOUND_MSGS} ]] && messages=( "${CMD_NOT_FOUND_MSGS[@]}" )

    # If CMD_NOT_FOUND_MSGS_APPEND array is populated append those to the existing messages
    [[ -n ${CMD_NOT_FOUND_MSGS_APPEND} ]] && messages+=( "${CMD_NOT_FOUND_MSGS_APPEND[@]}" )

    # Seed RANDOM with an integer of some length
    RANDOM=$(od -vAn -N4 -tu < /dev/urandom)

    # Print a randomly selected message, but only about half the time to annoy the user a
    # little bit less.
    if [[ $((${RANDOM} % 2)) -lt 1 ]]; then
        message=${messages[${RANDOM} % ${#messages[@]}]}
        printf "\n  $(tput bold)$(tput setaf 1)${message}$(tput sgr0)\n\n"
    fi
}

function function_exists () {
    # Zsh returns 0 even on non existing functions with -F so use -f
    declare -f $1 > /dev/null
    return $?
}

if function_exists command_not_found_handler; then
    if ! function_exists orig_command_not_found_handler; then
        eval "orig_$(declare -f command_not_found_handler)"
    fi
else
    orig_command_not_found_handler () {
        echo "zsh: command not found: $1"
        return 127
    }
fi

function command_not_found_handler () {
    print_message
    orig_command_not_found_handler "$@"
}


# Aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
fi

##########################################################
# Comment PACMAN ALIASES if you are not using arch linux #
##########################################################

# PACMAN ALIASES
alias pacupg='pacman -Syu' # Synchronize with repositories and then upgrade packages that are out of date
alias pacupd='pacman -Sy'  # Refresh of all package lists after updating /etc/pacman.d/mirrorlist
alias pacin='pacman -S'    # Install specific package(s) from the repositories
alias pacinu='pacman -U'   # Install specific local package(s)
alias pacre='pacman -R'    # Remove the specified package(s), retaining its configuration(s) and required dependencies
alias pacun='pacman -Rcsn' # Remove the specified package(s), its configuration(s) and unneeded dependencies
alias pacinfo='pacman -Si' # Display information about a given package in the repositories
alias pacse='pacman -Ss'   # Search for package(s) in the repositories

alias pacupa='pacman -Sy && sudo abs' # Update and refresh the local package and ABS databases against repositories
alias pacind='pacman -S --asdeps'     # Install given package(s) as dependencies of another package
alias pacclean="pacman -Sc"           # Delete all not currently installed package files
alias pacmake="makepkg -fcsi"         # Make package from PKGBUILD file in current directory
# END PACMAN ALIASES

# CD ALIASES
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
# END CD ALIASES

# PACMAN HELPER FUNCTIONS

function paclist() {
  # Source: https://bbs.archlinux.org/viewtopic.php?id=93683
  LC_ALL=C pacman -Qei $(pacman -Qu | cut -d " " -f 1) | \
    awk 'BEGIN {FS=":"} /^Name/{printf("\033[1;36m%s\033[1;37m", $2)} /^Description/{print $2}'
}

function pacdisowned() {
  emulate -L zsh

  tmp=${TMPDIR-/tmp}/pacman-disowned-$UID-$$
  db=$tmp/db
  fs=$tmp/fs

  mkdir "$tmp"
  trap  'rm -rf "$tmp"' EXIT

  pacman -Qlq | sort -u > "$db"

  find /bin /etc /lib /sbin /usr ! -name lost+found \
    \( -type d -printf '%p/\n' -o -print \) | sort > "$fs"

  comm -23 "$fs" "$db"
}

function pacmanallkeys() {
  emulate -L zsh
  curl -s https://www.archlinux.org/people/{developers,trustedusers}/ | \
    awk -F\" '(/pgp.mit.edu/) { sub(/.*search=0x/,""); print $1}' | \
    xargs sudo pacman-key --recv-keys
}

function pacmansignkeys() {
  emulate -L zsh
  for key in $*; do
    sudo pacman-key --recv-keys $key
    sudo pacman-key --lsign-key $key
    printf 'trust\n3\n' | sudo gpg --homedir /etc/pacman.d/gnupg \
      --no-permission-warning --command-fd 0 --edit-key $key
  done
}

if (( $+commands[xdg-open] )); then
  function pacweb() {
    pkg="$1"
    infos="$(pacman -Si "$pkg")"
    if [[ -z "$infos" ]]; then
      return
    fi
    repo="$(grep '^Repo' <<< "$infos" | grep -oP '[^ ]+$')"
    arch="$(grep '^Arch' <<< "$infos" | grep -oP '[^ ]+$')"
    xdg-open "https://www.archlinux.org/packages/$repo/$arch/$pkg/" &>/dev/null
  }
fi

# END PACMAN HELPER FUNCTIONS

# Some usefull aliases for sysadmin stuff
alias nse="ls /usr/share/nmap/scripts/|grep "
alias glog="git log --color --all --date-order --decorate --dirstat=lines,cumulative --stat|less -R"

# AUTOCOLOR
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
# END AUTOCOLOR

# LS STUFF
alias ls="ls --color=auto"
alias ll="ls -l"
alias lr='ls -R'
alias la='ll -A'
alias lm='la | less'       # la but in 'less'
alias lx='ls -lXB'         # Sort by extension
alias lk='ls -lSr'         # Sort by size, biggest last
alias lc='ls -ltcr'        # Sort by and show change time, most recent last
alias lu='ls -ltur'        # Sort by and show access time, most recent last
alias lt='ls -ltr'         # Sort by date, most recent last
# END LS STUFF

# LOL
alias dmesg="dmesg --color=always"
alias wtf='dmesg'
alias onoz='cat /var/log/errors.log'
alias rtfm='man'

alias :3='echo'
alias visible='echo'
alias invisible='cat'
alias moar='more'
alias tldr='less'
alias alwayz='tail -f'

alias icanhas='mkdir'
alias gimmeh='touch'
alias donotwant='rm'
alias dowant='cp'
alias gtfo='mv'
alias nowai='chmod'

alias hai='cd'
alias iz='ls'
alias plz='pwd'
alias ihasbucket='df -h'

alias inur='locate'
alias iminurbase='finger'

alias btw='nice'
alias obtw='nohup'

alias nomz='ps aux'
alias nomnom='killall'

alias byes='exit'
alias cya='reboot'
alias kthxbai='halt'

alias pwned='ssh'

alias hackzor='git init'
alias rulz='git push'
alias bringz='git pull'
alias chicken='git add'
alias oanward='git commit -m'
alias ooanward='git commit -am'
alias yolo='git commit -m "small fix or refactoring"'
alias letcat='git checkout'
alias violenz='git rebase'
# END LOL

# MODIFIED COMMANDS
alias df='df -h'
alias du='du -c -h'
alias free='free -m'                # show sizes in MB
alias grep='grep --color=auto'
alias mkdir='mkdir -p -v'
alias nano='nano -w'
# END MODIFIED COMMANDS

# OTHER
alias hello="echo 'Not you again'"
alias vi="vim"
alias open="xdg-open"
alias less="less -R"
alias fuckmylife=":(){ :|: & };:" # do not fuck your life
# END Other

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

# FUCK ISPs
function start-tor-service(){
    sudo chroot --userspec=tor:tor /opt/torchroot /usr/bin/tor
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

# Misc

function ngrokserve(){
     ngrok http 127.0.0.1:${1} -host-header="127.0.0.1:${1}"
}

function shrainbow(){
    (seq 231 -1 16) | while read i; do
        printf "\x1b[48;5;${i}m\n";
        sleep .02;
    done;
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
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

# Bold
BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

# Background
On_Black='\033[40m'       # Black
On_Red='\033[41m'         # Red
On_Green='\033[42m'       # Green
On_Yellow='\033[43m'      # Yellow

NC="\033[m"               # Color Reset
CR="$(echo -ne '\r')"
LF="$(echo -ne '\n')"
TAB="$(echo -ne '\t')"
ESC="$(echo -ne '\033')"

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

if [ -f ~/.zcompdump-$HOST-5.6.2 ]; then
    rm ~/.zcompdump-$HOST-5.6.2
fi

if [ -f ~/.zcompdump ]; then
    rm ~/.zcompdump
fi

# Some PATH Variables and exports
PATH="$(ruby -e 'print Gem.user_dir')/bin:$PATH"
PATH="$HOME/.node_modules/bin:$PATH"
PATH="$HOME/perl5/bin${PATH:+:${PATH}}"; export PATH;
PERL5LIB="$HOME/perl5/lib/perl5${PERL5LIB:+:${PERL5LIB}}"; export PERL5LIB;
PERL_LOCAL_LIB_ROOT="$HOME/perl5${PERL_LOCAL_LIB_ROOT:+:${PERL_LOCAL_LIB_ROOT}}"; export PERL_LOCAL_LIB_ROOT;
PERL_MB_OPT="--install_base \"$HOME/perl5\""; export PERL_MB_OPT;
PERL_MM_OPT="INSTALL_BASE=$HOME/perl5"; export PERL_MM_OPT;
ZSH_DISABLE_COMPINIT=true
export ZSH_DISABLE_COMPINIT
export TERM=tmux-256color
export TERMINAL=terminator
export EDITOR="vim"
export GOPATH=$HOME/go
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
export PATH=/usr/lib/jvm/java-8-openjdk/jre/bin/:$PATH
export ARCHFLAGS="-arch x86_64"
export PROMPT
