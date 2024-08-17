"display"
noh
syntax on
set t_Co=16
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
set noshowmode
set modelines=0
set showcmd
set cmdheight=1
set laststatus=2
set showtabline=1
set scrolloff=8
set ruler
set number

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
imap <A-Up> :bnext<CR>a
imap <A-Down> :bprevious<CR>a
imap <F4> <Esc>:q<CR>

"shortcut in visual mode"
vmap <C-Up> 8k
vmap <C-Down> 8j

"force shortcut in insert mode"
inoremap <C-Space> <C-N>
inoremap <C-@> <C-Space>

"autopair without autopair plugin"
inoremap ( ()<Left>
inoremap { {}<Left>
inoremap [ []<Left>
inoremap " ""<Left>
inoremap ' ''<Left>

"some useful command in command mode"
command Shredcomment :g/^\(#\|$\)/d
command Realtab :%s/    /\t/g
command Reducespace :%s/  / /g

"colorscheme without colorscheme plugin"
hi linenr ctermfg=0
hi cursorline ctermbg=NONE ctermfg=NONE cterm=NONE
hi cursorlinenr ctermbg=NONE ctermfg=NONE cterm=NONE
hi comment ctermfg=8
hi pmenu ctermbg=0 ctermfg=NONE
hi pmenusel ctermbg=4 ctermfg=0
hi pmenusbar ctermbg=0
hi pmenuthumb ctermbg=7
hi matchparen ctermbg=0 ctermfg=NONE
hi search ctermbg=0 ctermfg=NONE
hi vertsplit ctermbg=0 ctermfg=0 cterm=NONE
hi tablinefill ctermbg=NONE ctermfg=NONE cterm=NONE
hi tabline ctermbg=NONE ctermfg=0
hi tablinesel ctermbg=6 ctermfg=7
hi group1 ctermbg=NONE ctermfg=0
hi group2 ctermbg=NONE ctermfg=0
match group1 /\s\+$/
match group2 /\t/

"tab autocomplete without autocomplete plugin"
inoremap <expr> <Tab> TabComplete()
fun! TabComplete()
if getline('.')[col('.') - 2] =~ '\K' || pumvisible()
return "\<C-P>"
else
return "\<Tab>"
endif
endfun
set completeopt=menu,menuone,noinsert
inoremap <expr> <CR> pumvisible() ? "\<C-Y>" : "\<CR>"
autocmd InsertCharPre * call AutoComplete()
fun! AutoComplete()
if v:char =~ '\K'
\ && getline('.')[col('.') - 4] !~ '\K'
\ && getline('.')[col('.') - 3] =~ '\K'
\ && getline('.')[col('.') - 2] =~ '\K'
\ && getline('.')[col('.') - 1] !~ '\K'
call feedkeys("\<C-P>", 'n')
end
endfun

set completeopt+=menuone
set completeopt+=noselect
set shortmess+=c
set belloff+=ctrlg

"statusline without statusline plugin"
let g:currentmode={
\ 'n'  : 'Normal ',
\ 'no' : 'N·Operator Pending ',
\ 'v'  : 'Visual ',
\ 'V'  : 'V·Line ',
\ 'x22' : 'V·Block ',
\ 's'  : 'Select ',
\ 'S'  : 'S·Line ',
\ 'x19' : 'S·Block ',
\ 'i'  : 'Insert ',
\ 'R'  : 'Replace ',
\ 'Rv' : 'V·Replace ',
\ 'c'  : 'Command ',
\ 'cv' : 'Vim Ex ',
\ 'ce' : 'Ex ',
\ 'r'  : 'Prompt ',
\ 'rm' : 'More ',
\ 'r?' : 'Confirm ',
\ '!'  : 'Shell ',
\ 't'  : 'Terminal '
\}

hi user1 ctermbg=1 ctermfg=0
hi user2 ctermbg=4 ctermfg=0
hi user3 ctermbg=0 ctermfg=NONE
hi user4 ctermbg=NONE ctermfg=NONE
hi statusline ctermbg=0 ctermfg=NONE
hi statuslinenc ctermbg=0 ctermfg=0

function! Changestatuslinecolor()
if (mode() =~# '\v(n|no)')
exe 'hi! user1 ctermbg=1 ctermfg=0'
elseif (mode() =~# '\v(v|V)' || g:currentmode[mode()] ==# 'Visual Block' || get(g:currentmode, mode(), '') ==# 't')
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

set statusline=
set statusline+=%{Changestatuslinecolor()}
set statusline+=%1*\ %{g:currentmode[mode()]}
set statusline+=%3*\ %f\ %4*\ 
set statusline+=%=\ 
set statusline+=%3*\ %l\ of\ %L\ %2*\ 
set statusline+=%2*%{&filetype}\ 
