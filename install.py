#!/usr/env/python
import os
import sys
import subprocess
import platform

message = 'using {0} with python {1}'
version = int(platform.python_version()[0])

if version >= 3:
    version = 3
else:
    version = 2

if sys.platform == 'linux':
    print(message.format('linux', str(version)))
elif sys.platform == 'darwin':
    print(message.format('linux', str(version)))
else:
    print("Haha, this is not for windows")
    sys.exit(0)

def shell_theme():
    print('\n')
    print('What shell you use?')
    print('(1) bash')
    print('(2) zsh')

    try:
        shell = input('+=> ')
    except:
        print('doesnt seem to me that this is valid input')

    if int(shell) == 1:
        subprocess.call('cp .bashrc ~/.bashrc', shell=True)
        subprocess.call('source ~/.bashrc', shell=True)
    elif int(shell) == 2:
        subprocess.call('cp .zshrc ~/.zshrc', shell=True)
        subprocess.call('cp .Disassembler.zsh-theme ./.oh-my-zsh/theme/', shell=True)
        subprocess.call('source ~/.zshrc', shell=True)
    else:
        print('choose from the givin options')
        sys.exit(1)

def vim():
    print('\n')
    print('what do you want to install?')
    print('(1) .vimrc')
    print('(2) vim colorscheme')

    choice = input('+=> ')

    if int(choice) == 1:
        subprocess.call('cp .vimrc ~/.vimrc', shell=True)
    elif int(choice) == 2:
        subprocess.call('mkdir -p ~/.vim/colors && vim/colors/tender.vim ~/.vim/colors', shell=True)
    else:
        print('choose from the givin options')
        sys.exit(1)

if sys.argv[1] == 'vim':
    vim()
elif sys.argv[1] == 'shell':
    shell_theme()
else:
    print('usage {0} [argument]'.format(sys.argv[0]))
    print('arguments:')
    print('shell        install bash or zsh')
    print('vim          install vimrc or colorscheme')
    sys.exit(0)
