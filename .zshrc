export ZSH=/home/jpusefrye/.oh-my-zsh

ZSH_THEME="Disassembler"

LANG=en_US.UTF-8
MYNAME=JpUsefRye

# If not running interactively, don't do anything
[[ $- != *i* ]] && return


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


# MODIFIED COMMANDS
alias df='df -h'
alias du='du -c -h'
alias free='free -m'                # show sizes in MB
alias grep='grep --color=auto'
alias mkdir='mkdir -p -v'
alias nano='nano -w'
alias ping='ping -c 5'
# END MODIFIED COMMANDS

# OTHER
alias hello="echo 'Not you again'"
alias vi="vim"
alias open="xdg-open"
alias grep="grep --color=auto"
# END Other

# Terminal Interface
figlet "$MYNAME"
fortune | cowsay -f moose
echo -ne "Today is:\t\t" `date`; echo ""<<< Today
echo -e "Kernel Information: \t" `uname -smr`
# END Terminal Interface

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


plugins=(
  git
)


if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='mvim'
fi

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

# Some PATH Variables and exports
PATH="$(ruby -e 'print Gem.user_dir')/bin:$PATH"
PATH="$HOME/.node_modules/bin:$PATH"
export QT_X11_NO_MITSHM=1 # fixes the issue when opening qt app with sudo
export PATH="$PATH:$HOME/go/bin"
export npm_config_prefix=~/.node_modules
export GEM_HOME=$HOME/.gem
export PATH=/usr/lib/jvm/java-8-openjdk/jre/bin/:$PATH
export ARCHFLAGS="-arch x86_64"
export PROMPT
