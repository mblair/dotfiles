" What is vi again?
set nocompatible

call pathogen#runtime_append_all_bundles()
call pathogen#helptags()
filetype plugin indent on

" Syntax highlighting.
syntax on

" Make backspace/del work like they should.
set backspace=2

" Source .vimrc when you change it.
autocmd! bufwritepost vimrc source %

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

" No toolbar, menu, scrollbars for gvim
set guioptions-=T
set guioptions-=m
set guioptions-=L
set guioptions-=l
set guioptions-=R
set guioptions-=r
set guioptions-=b

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

if has("gui_running")
" Use (my modified version of) telstar for gvim.
	color telstar
else
	color zellner
endif

" Tabs are converted to spaces. Use only when required.
"set expandtab

" When using Vim in a terminal (not gVim/MacVim) and you're in insert mode, 
" hit Ctrl-P if you want to paste text from somewhere else and have it 
" look normal.
"set pastetoggle=<C-p>

" Make Ctrl-C copy stuff to the system clipboard, also known as the + register. 
map <C-c> "+y

" Make Ctrl-V paste stuff from the clipboard.
" Disables visual block mode, which I never use.
nnoremap <C-v> "+gp
" Make it work in insert mode.
inoremap <C-v> <Esc>"+gpa

" Toggle Gundo with F5.
nnoremap <F5> :GundoToggle<CR>

" Persistent undo! Vim 7.3 only.
set undodir=~/.vim/undodir
set undofile

" Show tabs and trailing spaces. Use when you feel like it.
" set listchars=tab:>-,trail:-
set nolist

" Sweet statusline.
set laststatus=2
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

"" Toggles NERDTree
map <silent> <F2> :call NTFinderP()<CR>

" Can no longer increment numbers in normal mode.
map <C-a> <plug>NERDCommenterToggle

autocmd FileType ruby                   setlocal ai et ts=2 sw=2 tw=0

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
	set guifont=Menlo Regular:h14
endif

"Why is this not working?
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
  exec ':silent !google-chrome ' . line
endfunction
map <F6> :call Browser ()<CR>

DoShowMarks!
" Write the swap file every [updatetime] ms. Showmarks relies on this to load
" the marks.
set updatetime=250
