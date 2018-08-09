" Maintainer: Youssef Hesham
" DESCRIPTION: My own vim configuration.

set nocompatible                " i don't know what is that doing but it works well
set encoding=utf-8              " Set default encoding to UTF-8

try
    colorscheme jellybeans
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
set fileformats=unix,dos,mac   " support all three, in this order
set cursorline

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

if has("gui_running")
    " setup for gui
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

noremap <C-F> <C-D>
noremap <C-B> <C-U>

" Open new line below and above current line
nnoremap <leader>o o<esc>
nnoremap <leader>O O<esc>

" Save
inoremap <C-s>     <C-O>:update<cr>
nnoremap <C-s>     :update<cr>
nnoremap <leader>s :update<cr>
nnoremap <leader>w :update<cr>

" Disable CTRL-A on tmux or on screen
if $TERM =~ 'screen'
  nnoremap <C-a> <nop>
  nnoremap <Leader><C-a> <C-a>
endif

" Quit
inoremap <C-Q>     <esc>:q<cr>
nnoremap <C-Q>     :q<cr>
vnoremap <C-Q>     <esc>
nnoremap <Leader>q :q<cr>
nnoremap <Leader>Q :qa!<cr>

" Tags
nnoremap <C-]> g<C-]>
nnoremap g[ :pop<cr>

" Jump list (to newer position)
nnoremap <C-p> <C-i>

" <F10> | NERD Tree
nnoremap <F10> :NERDTreeToggle<cr>

" Movement in insert mode
inoremap <C-h> <C-o>h
inoremap <C-l> <C-o>a
inoremap <C-j> <C-o>j
inoremap <C-k> <C-o>k
inoremap <C-^> <C-o><C-^>


" Replace all is aliased to S.
nnoremap S :%s//g<Left><Left>

" Spell-check set to F6:
map <F6> :setlocal spell! spelllang=en_us,es<CR>

" Use urlview to choose and open a url:
noremap <leader>u :w<Home>silent <End> !urlview<CR>

" Automatically deletes all tralling whitespace on save.
autocmd BufWritePre * %s/\s\+$//e

" Clear highlighting on escape in normal mode
nnoremap <esc> :noh<return><esc>
nnoremap <esc>^[ <esc>^[

" Ctrl+H opens hex edit mode
nnoremap <c-h> :%!xxd<cr>

" Zoom
function! s:zoom()
  if winnr('$') > 1
    tab split
  elseif len(filter(map(range(tabpagenr('$')), 'tabpagebuflist(v:val + 1)'),
                  \ 'index(v:val, '.bufnr('').') >= 0')) > 1
    tabclose
  endif
endfunction
nnoremap <silent> <leader>z :call <sid>zoom()<cr>

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

function! s:todo() abort
  let entries = []
  for cmd in ['git grep -niI -e TODO -e FIXME -e XXX 2> /dev/null',
            \ 'grep -rniI -e TODO -e FIXME -e XXX * 2> /dev/null']
    let lines = split(system(cmd), '\n')
    if v:shell_error != 0 | continue | endif
    for line in lines
      let [fname, lno, text] = matchlist(line, '^\([^:]*\):\([^:]*\):\(.*\)')[1:3]
      call add(entries, { 'filename': fname, 'lnum': lno, 'text': text })
    endfor
    break
  endfor

  if !empty(entries)
    call setqflist(entries)
    copen
  endif
endfunction
command! Todo call s:todo()

function! s:autosave(enable)
  augroup autosave
    autocmd!
    if a:enable
      autocmd TextChanged,InsertLeave <buffer>
            \  if empty(&buftype) && !empty(bufname(''))
            \|   silent! update
            \| endif
    endif
  augroup END
endfunction

function! Repeat()
    let times = input("Count: ")
    let char  = input("Char: ")
    exe ":normal a" . repeat(char, times)
endfunction

imap <C-u> <C-o>:call Repeat()<cr>

command! -bang AutoSave call s:autosave(<bang>1)

" Moving lines
nnoremap <silent> <C-k> :move-2<cr>
nnoremap <silent> <C-j> :move+<cr>
nnoremap <silent> <C-h> <<
nnoremap <silent> <C-l> >>
xnoremap <silent> <C-k> :move-2<cr>gv
xnoremap <silent> <C-j> :move'>+<cr>gv
xnoremap <silent> <C-h> <gv
xnoremap <silent> <C-l> >gv
xnoremap < <gv
xnoremap > >gv

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


""""""""""""""""""""""""""""""
" => JavaScript section
"""""""""""""""""""""""""""""""
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


""""""""""""""""""""""""""""""
" => CoffeeScript section
"""""""""""""""""""""""""""""""
function! CoffeeScriptFold()
    setl foldmethod=indent
    setl foldlevelstart=1
endfunction
au FileType coffee call CoffeeScriptFold()

au FileType gitcommit call setpos('.', [0, 1, 1, 0])

" Sadly i will start using plugins

call plug#begin('~/.vim/plugged')

Plug 'https://github.com/terryma/vim-multiple-cursors'
Plug 'https://github.com/w0rp/ale.git'
Plug 'https://github.com/RRethy/vim-illuminate'
Plug 'https://github.com/scrooloose/nerdtree'
Plug 'mhinz/vim-startify'
Plug 'Xuyuanp/nerdtree-git-plugin'

let g:multi_cursor_use_default_mapping=0

" Default mapping for multi cursor plugin
let g:multi_cursor_start_word_key      = '<C-n>'
let g:multi_cursor_select_all_word_key = '<A-n>'
let g:multi_cursor_start_key           = 'g<C-n>'
let g:multi_cursor_select_all_key      = 'g<A-n>'
let g:multi_cursor_next_key            = '<C-n>'
let g:multi_cursor_prev_key            = '<C-p>'
let g:multi_cursor_skip_key            = '<C-x>'
let g:multi_cursor_quit_key            = '<Esc>'

" ale plugin
let g:ale_echo_msg_error_str = 'Error'
let g:ale_echo_msg_warning_str = 'Warning'
let g:ale_echo_msg_format = '[%linter%] %s [%severity%]'

let g:ale_sign_error = '->'
let g:ale_sign_warning = '!!'
let g:ale_enabled = 0

let g:Illuminate_delay = 250

call plug#end()
