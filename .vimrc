set nocompatible                " i don't know what is that doing but it works well
set encoding=utf-8              " Set default encoding to UTF-8

try
    colorscheme ron
catch
endtry

syntax on                       " Enable syntax
filetype plugin indent on       " Enable indenting
filetype plugin on


set background=dark
set number                      " Numbering the lines
set textwidth=80                " Set text width to 80
set numberwidth=4               " Set number width to 4
" set relativenumber

set incsearch                   " Find the next match as we type the search
set hlsearch                    " Highlight searches by default
set ignorecase                  " Ignore case when searching...
set smartcase                   " ...unless we type a capital
set softtabstop=4
silent! set cryptmethod=blowfish2
set formatoptions+=1

set autoindent
set smartindent
set tabstop=4
set shiftwidth=4
set copyindent                  " copy the previous indentation on auto indenting

set hidden
set nowrap
set fileformats=unix,dos,mac   " support all three, in this order
" set cursorline

set foldmethod=syntax
set foldlevel=7
set tags=tags;
set clipboard=unnamedplus

set expandtab
set smarttab
set backspace=indent,eol,start

if has('mouse')
  set mouse=a
endif

set nu
set ruler                       " show the cursor position all the time
set title

set showcmd                     " display incomplete commands
set autowrite                   " Automatically :w before running commands
set showmode                    " show current mode down the bottom
set autoread

" Enable autocompletion:
" set wildmode
set wildmode=longest,list,full
" I DON'T UNDERSTAND VIM SCRIPT

if $COLORTERM == 'gnome-terminal'
    set t_Co=256
endif

if $COLORTERM == 'truecolor'
    set t_Co=256
endif

" ctrl+t create a new tab
" ctrl+w close current tab
" ctrl+arrows navigate tabs
map <C-t> :tabnew<cr>
map <C-w> :tabclose<cr>
map <C-left> :tabp<cr>
map <C-right> :tabn<cr>
" ctrl+d open a shell.
nmap <silent> <C-D> :shell<CR>
" ctrl+a selects all.
noremap <C-a> ggVG<CR>
" By pressing ctrl+r in the visual mode you will be prompted to enter text to replace with.
" Press enter and then confirm each change you agree with 'y' or decline with 'n'.
" This command will override your register 'h' so you can choose other one
" ( by changing 'h' in the command above to other lower case letter ) that you don't use.
vnoremap <C-r> "hy:%s/<C-r>h//g<left><left>
inoremap <tab> <c-r>=Smart_TabComplete()<CR>

" Automatically deletes all tralling whitespace on save.
autocmd BufWritePre * %s/\s\+$//e

" Clear highlighting on escape in normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc>^[

" Auto completion function
function! Smart_TabComplete()
  let line = getline('.')                         " current line

  let substr = strpart(line, -1, col('.'))        " from the start of the current
                                                  " line to one character on
                                                  " the cursor
  let substr = matchstr(substr, "[^ \t]*$")       " word till cursor
  if (strlen(substr)==0)                          " nothing to match on empty string
    return "\<tab>"
  endif
  let has_period = match(substr, '\.') != -1      " position of period, if any
  let has_slash = match(substr, '\/') != -1       " position of slash, if any
  if (!has_period && !has_slash)
    return "\<C-X>\<C-P>"                         " existing text matching
  elseif ( has_slash )
    return "\<C-X>\<C-F>"                         " file matching
  else
    return "\<C-X>\<C-O>"                         " plugin matching
  endif
endfunction

function! Repeat()
    let times = input("Count: ")
    let char  = input("Char: ")
    exe ":normal a" . repeat(char, times)
endfunction

imap <C-u> <C-o>:call Repeat()<cr>

set magic                       " Does some magic ;-) Newline characters...
set spell                       " Spell checking is on by default.
set number                      " Enable line numbering
set ttyfast                     " The current terminal is a fast terminal so
set laststatus=2

filetype on                     " Enable file type detection
filetype indent on              " Enable file type-specific indenting
filetype plugin on              " Enable file type-specific plugins

set history=50		            " keep 50 lines of command line history
set undofile                    " Save undo(s) after file closes
set undodir=$HOME/.vim/undo     " where to save undo histories
set undolevels=1000             " How many undo(s)
set undoreload=10000            " number of lines to save for undo
set directory=~/.vim/swap/
set nospell
set ttymouse=xterm2

set wildignore=*.o,*~,*.pyc,*.so " ignore compiled files
set noerrorbells		         " No annoying sound on errors
set novisualbell

set splitright                  " Puts new vertical split windows to the right of the current
set splitbelow                  " Puts new split windows to the bottom of the current

let python_highlight_all = 1

au FileType python syn keyword pythonDecorator True None False self
au BufNewFile,BufRead *.jinja set syntax=htmljinja
au BufNewFile,BufRead *.mako set ft=mako
au FileType python map <buffer> F :set foldmethod=indent<cr>
au FileType python inoremap <buffer> $r return
au FileType python inoremap <buffer> $i import
au FileType python inoremap <buffer> $p print
au FileType python inoremap <buffer> $f # --- <esc>a
au FileType python map <buffer> <leader>1 /class
au FileType python map <buffer> <leader>2 /def
au FileType python map <buffer> <leader>C ?class
au FileType python map <buffer> <leader>D ?def
au FileType python set cindent
au FileType python set cinkeys-=0#
au FileType python set indentkeys-=0#
au FileType javascript call JavaScriptFold()
au FileType javascript setl fen
au FileType javascript setl nocindent
au FileType javascript imap <c-t> $log();<esc>hi
au FileType javascript imap <c-a> alert();<esc>hi
au FileType javascript inoremap <buffer> $r return
au FileType javascript inoremap <buffer> $f // --- PH<esc>FP2xi

function! JavaScriptFold()
    setl foldmethod=syntax
    setl foldlevelstart=1
    syn region foldBraces start=/{/ end=/}/ transparent fold keepend extend

    function! FoldText()
        return substitute(getline(v:foldstart), '{.*', '{...}', '')
    endfunction
    setl foldtext=FoldText()
endfunction

call plug#begin('~/.vim/plugged')

Plug 'https://github.com/terryma/vim-multiple-cursors'
Plug 'https://github.com/RRethy/vim-illuminate'
Plug 'https://github.com/scrooloose/nerdtree'
Plug 'mhinz/vim-startify'
Plug 'Xuyuanp/nerdtree-git-plugin'

let g:airline#extensions#tabline#enabled = 1
" Show just the filename
let g:airline#extensions#tabline#fnamemod = ':t'

call plug#end()


highlight pythonSpaceError ctermfg=0
highlight Normal ctermfg=white

" set noshowmode
" set noruler
" set laststatus=0

