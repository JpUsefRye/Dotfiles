call plug#begin('~/.vim/plugged')

Plug 'jacoborus/tender.vim'

call plug#end()


if (has("termguicolors"))
 set termguicolors
endif


colorscheme tender
syntax enable

set incsearch

set autoindent
set tabstop=4
set shiftwidth=4

set expandtab
set smarttab

set backspace=2

set mouse=a
set nu
set ruler
