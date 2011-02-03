filetype off
call pathogen#helptags()
call pathogen#runtime_append_all_bundles()
filetype plugin indent on       " thanks nvie

" Syntax highlighting.
syntax on

" Make backspace/del work like they should.
set backspace=2

" Source .vimrc when you change it.
autocmd! bufwritepost .vimrc source %

" Show line numbers.
set number

" Autoindent new lines.
set autoindent

" Number of spaces that a tab is equivalent to.
set tabstop=4

" Number of spaces to (auto)indent.
set shiftwidth=4

" Shift a multiple of shiftwidth.
set shiftround

" Open a vertical split window *below* the current one.
set splitbelow

" Open a horizontal split window to the *right* of the current one.
set splitright

" Don't break in the middle of words.
set lbr

" Search with case insensitivity.
set ic

" No toolbar for gvim
set guioptions-=T

" cd to the buffer's working directory.
set autochdir

" For commands that autocomplete filenames, ignore these files.
set wildignore=*.class

" Lower the priority of swap files when doing tab completion. Don't want to
" ignore them in case I need to actually open them.
set suffixes=.swp

" Search incrementally.
set incsearch

" Highlight search results.
set hlsearch

" What is vi again?
set nocompatible

if has("gui_running")
" Use (my modified version of) telstar for gvim.
	color telstar
else
	color zellner
set background=dark
endif

" If you want to change your gVim font or its size, set it here.
if has('gui_gtk2')
	set guifont=Bitstream\ Vera\ Sans\ Mono\ 10
endif

" Tabs are converted to spaces. Use only when required.
"set expandtab

" When using Vim in a terminal (not gVim/MacVim) and you're in insert mode, 
" hit Ctrl-P if you want to paste text from somewhere else and have it 
" look normal.
set pastetoggle=<C-p>

" Make Ctrl-C copy stuff to the clipboard (not to a register).
map <C-c> "+y

" Make Ctrl-V paste stuff from the clipboard (again, not a register).
map <C-v> "+gP

" Persistent undo! Vim 7.3 only.
set undodir=~/.vim/undodir
set undofile

" Show tabs and trailing spaces. Use when you feel like it.
" set listchars=tab:>-,trail:-
set nolist

" Sweet statusline.
set laststatus=2
set statusline=%F%m%r[%L]%=[%p%%][%04l,%04v]%{fugitive#statusline()} 
"               | | | |  |   |       |    |
"               | | | |  |   |       |    +--current column
"               | | | |  |   |       +-------current line
"               | | | |  |   +---------------current % into file
"               | | | |  +-------------------total number of lines, left-justified for some reason.
"               | | | +----------------------stuff to the left of this is left-justified, stuff to the right is right-justified.
"               | | +------------------------read-only flag like so: [RO]
"               | +--------------------------modified flag like so: [+]
"               +----------------------------full path to the file in the buffer
