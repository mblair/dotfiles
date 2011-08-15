" Be iMproved.
" This must be first, as it changes other options.
set nocompatible

call pathogen#runtime_append_all_bundles()
call pathogen#helptags()

" Enable filetype detection, along with language-aware indentation.
filetype plugin indent on

" Syntax highlighting.
syntax on

" Allow backspacing over everything in insert mode.
set backspace=2

" Source .vimrc when you change it.
" This causes problems with Fugtive's :Gdiff if I'm staging changes in my
" vimrc. So just do `:so %`
"autocmd! bufwritepost vimrc source %

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
set linebreak

" Search with case insensitivity.
set ignorecase

" No toolbar, menu, or scrollbars for gVim.
set guioptions-=T
set guioptions-=m
set guioptions-=L
set guioptions-=R
set guioptions-=r
set guioptions-=b

" cd to the buffer's working directory.
set autochdir

" For commands that autocomplete filenames, ignore these files.
set wildignore=*.class,*.o,*.so

" Lower the priority of swap files when doing tab completion. Don't want to
" ignore them in case I need to actually open them.
" Also lower the priority of HTML files so I don't keep opening Rocco's
" generated docs.
set suffixes=.swp,.html

" Search incrementally.
set incsearch

" Highlight search results.
set hlsearch

if has("gui_running")
	" Use (my modified version of) telstar for gvim.
	colorscheme telstar
else
	" http://vim.wikia.com/wiki/256_colors_in_vim 
	set t_Co=256
	colorscheme inkpot
	 "colorscheme zellner
endif

" Tabs are converted to spaces. Use only when required.
"set expandtab

" When using Vim in a terminal (not gVim/MacVim) and you're in insert mode, 
" hit Shift-Insert if you want to paste text from somewhere else and have it 
" look normal. This basically toggles autoindentation on pasted code (which is
" probably already indented).
set pastetoggle=<S-Insert>

" Make Ctrl-C copy stuff to the system clipboard, also known as the + register. 
map <C-c> "+y

" Make Ctrl-V paste stuff from the clipboard.
" Disables visual block mode, which I never use.
nnoremap <C-v> "+gp
" Make it work in insert mode too.
inoremap <C-v> <Esc>"+gpa

" Toggle Gundo with F5.
nnoremap <F5> :GundoToggle<CR>

" Persistent undo! Vim 7.3 only.
set undodir=~/.vim/undodir
set undofile

" TODO: Document this.
set viminfo=%,'100,<1000,f100,n~/Dropbox/viminfo

" Show tabs and trailing spaces. Use when you feel like it.
"set list listchars=tab:>-,trail:-
set nolist

" Change the background of the entire line the cursor's on.
set cursorline

" Always show the statusline.
set laststatus=2
" Sweet statusline.
" Formatting from here:
" http://www.vi-improved.org/vimrc.php
set statusline=%F%m%r[%L]%=[%p%%][%04l,%04v]%{fugitive#statusline()}
"               | | | |  |   |       |    |  |
"               | | | |  |   |       |    |  +--shows your current git branch
"               | | | |  |   |       |    +-----current column
"               | | | |  |   |       +----------current line
"               | | | |  |   +------------------current % into file
"               | | | |  +----------------------stuff to the left of this is left-justified, stuff to the right is right-justified.
"               | | | +-------------------------total number of lines
"               | | +---------------------------read-only flag like so: [RO]
"               | +-----------------------------modified flag like so: [+]
"               +-------------------------------full path to the file in the buffer

" http://stackoverflow.com/questions/3907639/how-can-i-make-nerdtree-to-open-on-the-same-drive-that-the-file-that-im-editing/4170294#4170294
function! NTFinderP()
    "" Check if NERDTree is open
    if exists("t:NERDTreeBufName")
        let s:ntree = bufwinnr(t:NERDTreeBufName)
    else
        let s:ntree = -1
    endif
    if (s:ntree != -1)
        "" If NERDTree is open, close it.
        :NERDTreeClose
    else
        "" Try to open a :Rtree for the rails project
        if exists(":Rtree")
            "" Open Rtree (using rails plugin, it opens in project dir)
            :Rtree
        else
            "" Open NERDTree in the file path
            :NERDTreeFind
        endif
    endif
endfunction

 "Toggles NERDTree
map <silent> <F2> :call NTFinderP()<CR>

 "Can no longer increment numbers in normal mode. Oh well.
map <C-a> <plug>NERDCommenterToggle

autocmd FileType ruby setlocal autoindent tabstop=2 expandtab shiftwidth=2 textwidth=0

"http://svn.python.org/view/*checkout*/python/trunk/Misc/Vim/vimrc
autocmd FileType python setlocal autoindent tabstop=4 expandtab shiftwidth=4 softtabstop=4
autocmd BufRead,BufNewFile *.md set filetype=markdown

"Macvim already has shortcuts for font size changes.
if has("gui_gtk2")
	set guifont=Inconsolata\ 14
	"set guifont=DejaVu\ Sans\ Mono\ 14

	"http://vim.wikia.com/wiki/Change_font_size_quickly
	let s:pattern = '^\(.* \)\([1-9][0-9]*\)$'
	let s:minfontsize = 12
	let s:maxfontsize = 30
	function! AdjustFontSize(amount)
	if has("gui_gtk2") && has("gui_running")
		let fontname = substitute(&guifont, s:pattern, '\1', '')
		let cursize = substitute(&guifont, s:pattern, '\2', '')
		let newsize = cursize + a:amount
		if (newsize >= s:minfontsize) && (newsize <= s:maxfontsize)
		let newfont = fontname . newsize
		let &guifont = newfont
		endif
	else
		echoerr "You need to run the GTK2 version of Vim to use this function."
	endif
	endfunction

	function! LargerFont()
	call AdjustFontSize(1)
	endfunction

	function! SmallerFont()
	call AdjustFontSize(-1)
	endfunction

	"Make F11/F12 decrease/increase the font size. Reset split heights and widths,
	"and display the new font size.
	nnoremap <F11> :call SmallerFont()<CR><C-w>=:set guifont<CR>
	nnoremap <F12> :call LargerFont()<CR><C-w>=:set guifont<CR>
endif

if has("mac") && has("gui_running")
	set guifont=Menlo\ Regular:h25
endif

" Why is this not working?
":w !sudo tee >/dev/null %

"Open the file under the cursor in a new vertical split with F8.
"vim.wikia.com/wiki/Open_file_under_cursor
:map <F8> :vertical wincmd f<CR>

"http://vim.wikia.com/wiki/Open_a_web-browser_with_the_URL_in_the_current_line
function! Browser ()
  let line0 = getline (".")
  let line = matchstr (line0, "http[^ ]*")
  let line = escape (line, "#?&;|%")
  :if line==""
  let line = "\"" . (expand("%:p")) . "\""
  :endif
  exec ':silent !chromium-browser ' . line . ' &'
endfunction
map <F6> :call Browser ()<CR>

" Courtesy of Hacking Vim 7.2.
" Move up and down virtual lines when they're soft-wrapped.
map <DOWN> gj
map <UP> gk
imap <DOWN> <ESC>gji
imap <UP> <ESC>gki

" F1 gets help on the WORD under the cursor.
" Words are only alphanumeric.
" WORDS contain everything but whitespace.
map <F1> <ESC>:exec "help ".expand("<cWORD>")<CR>

autocmd VimEnter * DoShowMarks!
" Write the swap file every [updatetime] ms. Showmarks relies on this to
" update marks.
set updatetime=250

" https://github.com/linsong/vim-config/blob/master/_vimrc
" Make moving betweens splits easy.
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l

" Make realigning splits easy.
nnoremap <C-w> <C-w>=

" Make enter clear search highlighting. Just hit n/N to see them again.
nnoremap <CR> :nohlsearch<CR>

" Nice mapping for quickfix mode
nnoremap <F3>   :cprev \| norm zz<CR>
nnoremap <F4>   :cnext \| norm zz<CR>

" No need to press <shift> anymore :-)
nnoremap ; :

" Read and write sessions.
" TODO: Figure out why this messes with manpageview.vim
nnoremap <F9> :source ~/Dropbox/session.vim<CR>
nnoremap <F10> :mksession! ~/Dropbox/session.vim<CR>

function! RemoveFugitiveBuffers()
	for buf in range(1, bufnr('$'))
		if bufname(buf) =~? "fugitive.*"
			if buflisted(buf)
				exe 'bdelete ' . buf
			endif
		endif
	endfor
endfunction

function! ListVersion()
	let bye = []
	bufdo if bufname("%") =~? "fugitive.*" | :call add(bye, bufnr("%")) | endif

	for buf in bye
		exe 'bdelete ' . buf
	endfor
endfunction

"TODO: Figure out something with nobuflisted that makes this all unnecessary.
autocmd VimLeave * :call RemoveFugitiveBuffers()

let Tlist_GainFocus_On_ToggleOpen=1
"let Tlist_Show_One_File=1
nnoremap <silent> <F7> :TlistToggle<CR>

"TODO: Make mappings for rspec, cucumber/steak, minitest, rocco/pandoc.
