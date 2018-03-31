" Maintainer: Youssef Hesham
" DESCRIPTION: My own vim configuration.

set nocompatible                " i don't know what is that doing but it works well
set encoding=utf-8              " Set default encoding to UTF-8

try                             " You Must Have Tender Color Scheme.
    colorscheme tender          " Set color scheme to tender
catch
endtry

syntax on                       " Enable syntax
filetype plugin indent on       " Enable indenting
filetype plugin on

set background=dark
set number                      " Numbering the lines
set textwidth=80                " Set text width to 80
set numberwidth=4               " Set number width to 4

set incsearch                   " Find the next match as we type the search
set hlsearch                    " Highlight searches by default
set ignorecase                  " Ignore case when searching...
set smartcase                   " ...unless we type a capital
set softtabstop=4

set autoindent
set smartindent
set tabstop=4
set shiftwidth=4
set copyindent                  " copy the previous indentation on auto indenting

set hidden
set cursorline
set numberwidth=5
set fileformats=unix,dos,mac   " support all three, in this order

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
set wildmode=longest,list,full
set wildmenu

" I DON'T UNDERSTAND VIM SCRIPT

if $COLORTERM == 'gnome-terminal'
    set t_Co=256
endif

if $COLORTERM == 'truecolor'
    set t_Co=256
endif

if has("gui_running")
i    " setup for gui
    set guioptions-=r  " no scrollbar on the right
    set guioptions-=l  " no scrollbar on the left
    set guioptions-=m  " no menu
    set guioptions-=T  " no toolbar
    set guioptions-=L
endif

if $TERM_PROGRAM =~ "iTerm"
    set termguicolors
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

" Shortcutting split navigation, saving a keypress:
map <C-h> <C-w>h
map <C-j> <C-w>j
map <C-k> <C-w>k
map <C-l> <C-w>l

" Replace all is aliased to S.
nnoremap S :%s//g<Left><Left>

" Spell-check set to F6:
map <F6> :setlocal spell! spelllang=en_us,es<CR>

" Use urlview to choose and open a url:
noremap <leader>u :w<Home>silent <End> !urlview<CR>

" Automatically deletes all tralling whitespace on save.
autocmd BufWritePre * %s/\s\+$//e


" Navigating with guides
inoremap <Space><Tab> <Esc>/<++><Enter>"_c4l
noremap <Space><Tab> <Esc>/<++><Enter>"_c4l
map <Space><Tab> <Esc>/<++><Enter>"_c4l
inoremap ;gui <++>

augroup checktime
    au!
    if !has("gui_running")
        "silent! necessary otherwise throws errors when using command
        "line window.
        autocmd BufEnter        * silent! checktime
        autocmd CursorHold      * silent! checktime
        autocmd CursorHoldI     * silent! checktime
        "these two _may_ slow things down. Remove if they do.
        autocmd CursorMoved     * silent! checktime
        autocmd CursorMovedI    * silent! checktime
    endif
augroup END


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

set splitright                  " Puts new vertical split windows to the right of the current
set splitbelow                  " Puts new split windows to the bottom of the current

