noh
syntax on
set t_Co=16
set noexpandtab
set copyindent
set preserveindent
set softtabstop=0
set shiftwidth=4
set tabstop=4
set background=dark
set nocompatible
set showmode
set showcmd
set ruler
set number
set noshiftround
set lazyredraw
set magic
set hlsearch
set incsearch
set ignorecase
set smartcase
set encoding=utf-8
set modelines=0
set formatoptions=tqn1
set cmdheight=1
set laststatus=2
set backspace=indent,eol,start
set list
set listchars=tab:——
set listchars+=trail:•
set matchpairs+=<:>
set statusline=%1*\ file\ %3*\ %f\ %4*\ 
set statusline+=%=\ 
set statusline+=%3*\ %l\ of\ %L\ %2*\ line\ 
set scrolloff=8
nmap <C-S> :w<CR>
nmap <C-_> :noh<CR>
nmap <S-Left> v<Left>
nmap <S-Right> v<Right>
nmap <C-Up> 8k
nmap <C-Down> 8j
nmap <C-O> o<Esc>
nmap <C-Z> u
nmap <C-Y> <C-R>
nmap <C-F> :%s/
nmap <C-H> i<C-W><Esc>
nmap <C-T> :tabnew 
nmap <A-Right> :tabnext<CR>
nmap <A-Left> :tabprevious<CR>
nmap <F3> :set invnumber<CR>
nmap <F4> :q<CR>
nmap <F5> :%s/    /\t/g<CR>
nmap <F6> :%s/  / /g<CR>
imap <C-S> <Esc>:w<CR>a
imap <C-_> <Esc>:noh<CR>a
imap <S-Left> <Esc>lv<Left>
imap <S-Right> <Esc>lv<Right>
imap <C-Up> <Esc>8ka
imap <C-Down> <Esc>8ja
imap <C-O> <Esc>o
imap <C-Z> <Esc>ua
imap <C-Y> <Esc><C-R>a
imap <C-F> <Esc>:%s/
imap <C-H> <C-W>
imap <C-V> <Esc>pa
imap <C-T> <Esc>:tabnew 
imap <A-Right> <Esc>:tabnext<CR>a
imap <A-Left> <Esc>:tabprevious<CR>a
imap <F3> <Esc>:set invnumber<CR>a
imap <F4> <Esc>:q<CR>
imap <F5> <Esc>:%s/    /\t/g<CR>a
imap <F6> :%s/  / /g<CR>a
vmap <C-Up> 8k
vmap <C-Down> 8j
inoremap <C-Space> <C-N>
inoremap <C-@> <C-Space>
command NoPaste :set nopaste
command ShredComment :g/^\(#\|$\)/d
command RealTab :%s/	/\t/g
command SpellEnglish :set spell spelllang=en_us
command SpellIndonesian :set spell spelllang=id
command SpellOff :set nospell
command ReduceSpace :%s/  / /g
hi linenr ctermfg=0
hi comment ctermfg=8
hi pmenu ctermbg=0 ctermfg=NONE
hi pmenusel ctermbg=4 ctermfg=0
hi pmenusbar ctermbg=0
hi pmenuthumb ctermbg=7
hi matchparen ctermbg=0 ctermfg=NONE
hi search ctermbg=0 ctermfg=NONE
hi statusline ctermbg=0 ctermfg=NONE
hi statuslinenc ctermbg=0 ctermfg=0
hi user1 ctermbg=1 ctermfg=0
hi user2 ctermbg=4 ctermfg=0
hi user3 ctermbg=0 ctermfg=NONE
hi user4 ctermbg=NONE ctermfg=NONE
hi group1 ctermbg=NONE ctermfg=0
hi group2 ctermbg=NONE ctermfg=0
match group1 /\s\+$/
match group2 /\t/

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
