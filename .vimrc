"shared plugin between vim and nvim
set runtimepath^=~/.vim
set runtimepath+=~/.vim/after
set notermguicolors
let &packpath = &runtimepath

"ale
let g:ale_fixers = {
\'*': ['remove_trailing_lines', 'trim_whitespace'],
\'fish': ['fish_indent'],
\}

"easycomplete
let g:easycomplete_tabnine_enable = 0
let g:easycomplete_tabnine_suggestion = 0
let g:easycomplete_nerd_font = 0
let g:easycomplete_winborder = 1
let g:easycomplete_pum_format = ["kind", "abbr", "menu"]
noremap gr :EasyCompleteReference<CR>
noremap gd :EasyCompleteGotoDefinition<CR>
noremap rn :EasyCompleteRename<CR>
noremap gb :BackToOriginalBuffer<CR>
let g:easycomplete_cmdline = 1
set completeopt+=menuone,noselect,fuzzy
set shortmess+=c
set belloff+=ctrlg

"ctrlp
let g:ctrlp_map = '<c-p>'
let g:ctrlp_cmd = 'CtrlP'

"wilder.nvim
call wilder#setup({'modes': [':', '/', '?']})
let g:popup_renderer = wilder#popupmenu_renderer({
\'highlighter': wilder#basic_highlighter(),
\'left': [
\' ', wilder#popupmenu_devicons(),
\],
\'right': [
\' ', wilder#popupmenu_scrollbar(),
\],
\})
call wilder#set_option('renderer', wilder#renderer_mux({
\':': g:popup_renderer,
\'/': g:popup_renderer,
\}))

"colorizer
if !exists('g:current_t_co')
let g:current_t_co = 16
endif
let &t_Co = g:current_t_co
command! EnableColorizer let g:current_t_co = 256 |
\let &t_Co = 256 | source $MYVIMRC | execute 'ColorHighlight'
command! DisableColorizer execute 'ColorClear' |
\let g:current_t_co = 16 | let &t_Co = 16 | source $MYVIMRC

"clever-f.vim
let g:clever_f_ignore_case = 1
let g:clever_f_mark_direct = 0
let g:clever_f_show_prompt = 1
nmap <Esc> <Plug>(clever-f-reset)

"display"
noh
syntax on
set background=dark
set lazyredraw
set encoding=utf-8
set list
set listchars=tab:\│\ 
set listchars+=trail:•
set fillchars=eob:\ 
set fillchars+=vert:\ 
set matchpairs+=<:>
set nowrap
set cursorline
set modelines=0
set showcmd
set cmdheight=1
set laststatus=2
set showtabline=1
set scrolloff=8
set ruler
set number
set spelllang=en_us

"behavior"
filetype on
filetype plugin on
set nocompatible
set backspace=indent,eol,start
set formatoptions=tqn1
set magic

"tabulation"
set copyindent
set preserveindent
set softtabstop=0
set shiftwidth=4
set tabstop=4
set noexpandtab
set noshiftround

"searching"
set incsearch
set hlsearch
set ignorecase
set smartcase

"shortcut in normal mode"
nmap <C-S> :w<CR>
nmap <C-_> :noh<CR>
nmap <S-Left> v<Left>
nmap <S-Right> v<Right>
nmap <C-Up> 8k
nmap <C-Down> 8j
nmap <C-O> o<Esc>
nmap <C-Z> u
nmap <C-Y> <C-R>
nmap <C-F> :%s///g<Left><Left><Left>
nmap <C-H> i<C-W><Esc>
nmap <C-T> :tabnew 
nmap <A-Right> :tabnext<CR>
nmap <A-Left> :tabprevious<CR>
nmap <A-Up> :bnext<CR>
nmap <A-Down> :bprevious<CR>
nmap <F4> :q<CR>

"shortcut in insert mode"
imap <C-S> <Esc>:w<CR>a
imap <C-_> <Esc>:noh<CR>a
imap <S-Left> <Esc>lv<Left>
imap <S-Right> <Esc>lv<Right>
imap <C-Up> <Esc>8ka
imap <C-Down> <Esc>8ja
imap <C-O> <Esc>o
imap <C-Z> <Esc>ua
imap <C-Y> <Esc><C-R>a
imap <C-F> <Esc>:%s///g<Left><Left><Left>
imap <C-H> <C-W>
imap <C-V> <Esc>pa
imap <C-T> <Esc>:tabnew 
imap <A-Right> <Esc>:tabnext<CR>a
imap <A-Left> <Esc>:tabprevious<CR>a
imap <A-Up> <Esc>:bnext<CR>a
imap <A-Down> <Esc>:bprevious<CR>a
imap <F4> <Esc>:q<CR>

"shortcut in visual mode"
vmap <C-Up> 8k
vmap <C-Down> 8j

"some useful command in command mode"
command DeleteAllComment :g/^\(#\|$\)/d
command ReplaceWithTab :%s/    /\t/g
command ReduceSpace :%s/  / /g
command LowerCaseColorHex :%s/#\x\{6\}/\L&/g
command UpperCaseColorHex :%s/#\x\{6\}/\U&/g
command WhiteSpaceCleanUp :%s/\s\+$//
command StripTags :%s/<[^>]\+>//g
command DeleteEmptyLines :g/^\s*$/d
command AllLowerCase :%s/.*/\L&/g
command NumberOn :set number
command NumberOff :set nonumber
command Reload :source $MYVIMRC

"colorscheme without colorscheme plugin"

"warning"
"color 0 8 7 15 (black, lightgray, darkgray, white)
"in the terminal colorscheme have to be different

"main editor elements
hi linenr ctermbg=NONE ctermfg=0 cterm=NONE
hi cursorline ctermbg=NONE ctermfg=NONE cterm=NONE
hi cursorlinenr ctermbg=NONE ctermfg=NONE cterm=NONE
hi comment ctermbg=NONE ctermfg=8 cterm=NONE
hi pmenu ctermbg=0 ctermfg=NONE cterm=NONE
hi pmenusel ctermbg=4 ctermfg=0 cterm=NONE
hi pmenusbar ctermbg=0 ctermfg=NONE cterm=NONE
hi pmenuthumb ctermbg=7 ctermfg=NONE cterm=NONE
hi matchparen ctermbg=0 ctermfg=NONE cterm=NONE
hi search ctermbg=0 ctermfg=NONE cterm=NONE
hi vertsplit ctermbg=0 ctermfg=NONE cterm=NONE
hi vertsplitnc ctermbg=0 ctermfg=8 cterm=NONE
hi tablinefill ctermbg=NONE ctermfg=NONE cterm=NONE
hi tabline ctermbg=0 ctermfg=7 cterm=NONE
hi tablinesel ctermbg=2 ctermfg=7 cterm=NONE
hi group1 ctermbg=NONE ctermfg=0 cterm=NONE
hi group2 ctermbg=NONE ctermfg=0 cterm=NONE
match group1 /\s\+$/
match group2 /\t/

"other editor elements
hi nontext ctermbg=NONE ctermfg=0 cterm=NONE
hi ignore ctermbg=NONE ctermfg=NONE cterm=NONE
hi underlined ctermbg=NONE ctermfg=NONE cterm=underline
hi bold ctermbg=NONE ctermfg=NONE cterm=bold
hi italic ctermbg=NONE ctermfg=NONE cterm=italic
hi title ctermbg=NONE ctermfg=4 cterm=bold
hi cursor ctermbg=15 ctermfg=0 cterm=NONE
hi cursorcolumn ctermbg=0 ctermfg=NONE cterm=NONE
hi helpleadblank ctermbg=NONE ctermfg=NONE cterm=NONE
hi helpnormal ctermbg=NONE ctermfg=NONE cterm=NONE
hi visual ctermbg=8 ctermfg=15 cterm=bold
hi visualnos ctermbg=8 ctermfg=15 cterm=bold
hi foldcolumn ctermbg=NONE ctermfg=7 cterm=NONE
hi folded ctermbg=NONE ctermfg=12 cterm=NONE
hi wildmenu ctermbg=0 ctermfg=15 cterm=NONE
hi specialkey ctermbg=NONE ctermfg=8 cterm=NONE
hi incsearch ctermbg=1 ctermfg=0 cterm=NONE
hi cursearch ctermbg=3 ctermfg=0 cterm=NONE
hi directory ctermbg=NONE ctermfg=4 cterm=NONE
hi spellbad ctermbg=NONE ctermfg=NONE cterm=undercurl
hi spellcap ctermbg=NONE ctermfg=NONE cterm=undercurl
hi spelllocal ctermbg=NONE ctermfg=NONE cterm=undercurl
hi spellrare ctermbg=NONE ctermfg=NONE cterm=undercurl
hi colorcolumn ctermbg=0 ctermfg=NONE cterm=NONE
hi signcolumn ctermbg=NONE ctermfg=7 cterm=NONE
hi modemsg ctermbg=15 ctermfg=0 cterm=bold
hi moremsg ctermbg=NONE ctermfg=4 cterm=NONE
hi question ctermbg=NONE ctermfg=4 cterm=NONE
hi quickfixline ctermbg=0 ctermfg=14 cterm=NONE
hi conceal ctermbg=0 ctermfg=8 cterm=NONE
hi toolbarline ctermbg=0 ctermfg=15 cterm=NONE
hi toolbarbutton ctermbg=8 ctermfg=15 cterm=NONE
hi debugpc ctermbg=NONE ctermfg=7 cterm=NONE
hi debugbreakpoint ctermbg=NONE ctermfg=8 cterm=NONE
hi errormsg ctermbg=NONE ctermfg=7 cterm=bold,italic
hi warningmsg ctermbg=NONE ctermfg=11 cterm=NONE
hi diffadd ctermbg=10 ctermfg=0 cterm=NONE
hi diffchange ctermbg=12 ctermfg=0 cterm=NONE
hi diffdelete ctermbg=9 ctermfg=0 cterm=NONE
hi difftext ctermbg=14 ctermfg=0 cterm=NONE
hi diffadded ctermbg=NONE ctermfg=10 cterm=NONE
hi diffremoved ctermbg=NONE ctermfg=9 cterm=NONE
hi diffchanged ctermbg=NONE ctermfg=12 cterm=NONE
hi diffoldfile ctermbg=NONE ctermfg=11 cterm=NONE
hi diffnewfile ctermbg=NONE ctermfg=13 cterm=NONE
hi difffile ctermbg=NONE ctermfg=12 cterm=NONE
hi diffline ctermbg=NONE ctermfg=7 cterm=NONE
hi diffindexline ctermbg=NONE ctermfg=14 cterm=NONE
hi healtherror ctermbg=NONE ctermfg=1 cterm=NONE
hi healthsuccess ctermbg=NONE ctermfg=2 cterm=NONE
hi healthwarning ctermbg=NONE ctermfg=3 cterm=NONE

"syntax
hi constant ctermbg=NONE ctermfg=3 cterm=NONE
hi error ctermbg=NONE ctermfg=1 cterm=NONE
hi identifier ctermbg=NONE ctermfg=9 cterm=NONE
hi function ctermbg=NONE ctermfg=4 cterm=NONE
hi special ctermbg=NONE ctermfg=13 cterm=NONE
hi statement ctermbg=NONE ctermfg=5 cterm=NONE
hi string ctermbg=NONE ctermfg=2 cterm=NONE
hi operator ctermbg=NONE ctermfg=6 cterm=NONE
hi boolean ctermbg=NONE ctermfg=3 cterm=NONE
hi label ctermbg=NONE ctermfg=14 cterm=NONE
hi keyword ctermbg=NONE ctermfg=5 cterm=NONE
hi exception ctermbg=NONE ctermfg=5 cterm=NONE
hi conditional ctermbg=NONE ctermfg=5 cterm=NONE
hi preproc ctermbg=NONE ctermfg=13 cterm=NONE
hi include ctermbg=NONE ctermfg=5 cterm=NONE
hi macro ctermbg=NONE ctermfg=5 cterm=NONE
hi storageclass ctermbg=NONE ctermfg=11 cterm=NONE
hi structure ctermbg=NONE ctermfg=11 cterm=NONE
hi todo ctermbg=9 ctermfg=7 cterm=bold
hi type ctermbg=NONE ctermfg=11 cterm=NONE

"change to relative numbering when on visual mode
augroup VisualRelNumber
autocmd!
autocmd ModeChanged *:[vV\x16]* setlocal relativenumber
autocmd ModeChanged [vV\x16]*:* setlocal norelativenumber
augroup END

"set linear (absolute) line numbers by default
set norelativenumber

"function to turn on relative numbers safely
function! StartOperator(op)
set relativenumber
augroup ToggleLineNumbers
autocmd!
"restore linear numbers as soon as the operator finishes or is canceled
autocmd SafeState * set norelativenumber | autocmd! ToggleLineNumbers
augroup END
return a:op
endfunction

"map d and y cleanly
nnoremap <expr> d StartOperator('d')
nnoremap <expr> y StartOperator('y')

"statusline without statusline plugin"
let g:currentmode={
\'n'  : 'Normal ',
\'no' : 'N·Operator Pending ',
\'v'  : 'Visual ',
\'V'  : 'V·Line ',
\"\<C-V>" : 'V·Block ',
\'s'  : 'Select ',
\'S'  : 'S·Line ',
\"\<C-S>" : 'S·Block ',
\'i'  : 'Insert ',
\'R'  : 'Replace ',
\'Rv' : 'V·Replace ',
\'c'  : 'Command ',
\'cv' : 'Vim Ex ',
\'ce' : 'Ex ',
\'r'  : 'Prompt ',
\'rm' : 'More ',
\'r?' : 'Confirm ',
\'!'  : 'Shell ',
\'t'  : 'Terminal '
\}

hi user1 ctermbg=1 ctermfg=0
hi user2 ctermbg=4 ctermfg=NONE
hi user3 ctermbg=0 ctermfg=NONE
hi user4 ctermbg=NONE ctermfg=NONE
hi statusline ctermbg=0 ctermfg=NONE
hi statuslinenc ctermbg=0 ctermfg=0

function! Changestatuslinecolor()
if (mode() =~# '\v(n|no)')
exe 'hi! user1 ctermbg=1 ctermfg=NONE'
elseif (mode() =~# '\v(v|V)' || mode() ==# "\<C-V>" || mode() ==# 't')
exe 'hi! user1 ctermbg=5 ctermfg=0'
elseif (mode() ==# 'i')
exe 'hi! user1 ctermbg=2 ctermfg=0'
elseif (mode() ==# 'R')
exe 'hi! user1 ctermbg=3 ctermfg=0'
else
exe 'hi! user1 ctermbg=1 ctermfg=0'
endif
return ''
endfunction

augroup StatuslineUpdate
autocmd!
silent! autocmd InsertEnter,InsertLeave,CursorMoved,ModeChanged * 
\call Changestatuslinecolor() | redrawstatus
augroup END

set statusline=
set statusline+=%{Changestatuslinecolor()}
set statusline+=%1*\ %{get(g:currentmode,mode(),mode())}
set statusline+=%3*\ %f\ %4*\ 
set statusline+=%=\ 
set statusline+=%3*\ %l\ of\ %L\ %2*\ 
set statusline+=%2*%{&filetype}\ 
set noshowmode

