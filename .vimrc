set encoding=utf-8              " Set default encoding to UTF-8
colorscheme tender              " Set color scheme to tender
syntax enable                   " Enable syntax
filetype plugin indent on       " Enable indenting

set number                      " Numbering the lines
set textwidth=80                " Set text width to 80
set numberwidth=4               " Set number width to 4

set incsearch                   " Find the next match as we type the search
set hlsearch                    " Highlight searches by default
set ignorecase                  " Ignore case when searching...
set smartcase                   " ...unless we type a capital

set autoindent
set smartindent
set tabstop=4
set shiftwidth=4

set expandtab
set smarttab
set backspace=2

if has('mouse')
  set mouse=a
endif

set nu
set ruler                       " show the cursor position all the time

set showcmd                     " display incomplete commands
set autowrite                   " Automatically :w before running commands
set showmode                    " show current mode down the bottom
set autoread

set t_Co=256                    " Enable 256 color in vim.
set magic                       " Does some magic ;-) Newline characters...
set spell                       " Spell checking is on by default.
set number                      " Enable line numbering
set ttyfast                     " The current terminal is a fast terminal so

set undofile                    " Save undo(s) after file closes
set undodir=$HOME/.vim/undo     " where to save undo histories
set undolevels=1000             " How many undo(s)
set undoreload=10000            " number of lines to save for undo

