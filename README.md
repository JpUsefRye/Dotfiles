# My Personal Dotfiles

Running on Arch Linux

**NOTE**: read the comments in the `.bashrc` carefully.
if you have any problem, submit an issue or pull requests.

# Screen Shot

you can find screen shots at [screenshots.md](Screenshots.md)


# what inside this repo
in this repo there is my personal vim configuration that i use to code ([.vimrc](.vimrc)).

there is my [.gdbinit](.gdbinit) file that i use in debugging and reverse engineering, user interface from [GDB-Dashboard](https://github.com/cyrus-and/gdb-dashboard) extension and the configurations is by me and some people.

in the past i used [.bashrc](.bashrc) for my shell but now i am [.zshrc](.zshrc) fan.

#### Required

- cowsay

- fortune

- figlet

### Installation

```shell
chmod +x install.sh

# to install the .vimrc run this command
(sleep 1; echo 1; cat;) | python install.py vim

# to install vim colorscheme
(sleep 1; echo 2; cat;) | python install.py vim

# to install .bashrc
(sleep 1; echo 1; cat;) | python install.py shell

# to install .zshrc (requires oh-my-zsh)
(sleep 1; echo 2; cat;) | python install.py shell

```

### Contribution
all pull requests & issues are welcomed :)

### LICENSE
the whole repo is released under GPL3

this repo containing code from gdb-dashboard licensed on MIT
