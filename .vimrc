"common settings
filetype plugin indent on
syntax enable
set autoindent
set background=dark
set cursorline
set dictionary+=/usr/share/dict/words
set hlsearch
set ignorecase
set incsearch
set laststatus=2
set list
set listchars=tab:>\ ,trail:•
set mouse=
set nocompatible
set noexpandtab
set norelativenumber
set noshowmode
set nowrap
set number
set scrolloff=8
set shiftwidth=4
set smartcase
set splitbelow
set splitright
set t_Co=16
set tabstop=4
set updatetime=300

"install plugins
call plug#begin()
Plug 'dense-analysis/ale'
Plug 'jiangmiao/auto-pairs'
Plug 'rhysd/clever-f.vim'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'liuchengxu/vim-which-key'
Plug 'tpope/vim-commentary'
Plug 'gelguy/wilder.nvim'
Plug 'justinmk/vim-sneak'
Plug 'machakann/vim-highlightedyank'
Plug 'itchyny/vim-cursorword'
Plug 'markonm/traces.vim'
Plug 'junegunn/goyo.vim'
Plug 'lifepillar/vim-mucomplete'
Plug 'mhinz/vim-startify'
call plug#end()

"startify
let g:startify_custom_header = []

"mucomplete
set completeopt+=menuone,noselect
set shortmess+=c
let g:mucomplete#enable_default_keybindings=1
let g:mucomplete#enable_auto_at_startup = 1
let g:mucomplete#completion_delay = 1
let g:mucomplete#no_mappings = 1
let g:AutoPairsMapSpace = 0
imap <silent> <expr> <space> pumvisible() ? "<space>" : "<c-r>=AutoPairsSpace()<cr>"

"ale
let g:ale_lint_on_text_changed='normal'
let g:ale_lint_on_insert_leave=1

"wilder
call wilder#setup({'modes':[':','/','?']})
call wilder#set_option('renderer',wilder#popupmenu_renderer({'highlighter':wilder#basic_highlighter(),'min_width':'100%','max_height':'30%'}))

"yank
let g:highlightedyank_highlight_duration=300

"sneak
nmap <CR> <Plug>Sneak_s

"which-key
let mapleader=" "
let g:mapleader=" "
set timeoutlen=500
nmap <leader>c gcc
nnoremap <silent> <leader> :<c-u>WhichKey '<Space>'<CR>
nnoremap <silent> <leader>/ :nohlsearch<CR>
nnoremap <silent> <leader>n :setlocal number!<CR>
vmap <leader>c gc
vnoremap <silent> <leader> :<c-u>WhichKeyVisual '<Space>'<CR>
let g:which_key_map={}
let g:which_key_map.Q = [':qa!','quit without saving']
let g:which_key_map.W = [':wq','write changes then exit']
let g:which_key_map.a = {'name':'+ale','n':['<Plug>(ale_next_wrap)','next error'],'p':['<Plug>(ale_previous_wrap)','previous error'],'f':[':ALEFix','fix errors'],'d':[':ALEDetail','show error detail'],'t':[':ALEToggle','toggle linting']}
let g:which_key_map.b = {'name':'+buffer','n':[':bnext','next buffer'],'p':[':bprevious','previous buffer'],'d':[':bdelete','delete buffer'],'l':[':ls','list open buffers'],'b':[':CtrlPBuffer','search buffers (ctrlp)']}
let g:which_key_map.c = 'comment out/in'
let g:which_key_map.f = {'name':'+file','f':[':CtrlP','find file'],'m':[':CtrlPMRU','recent files (mru)'],'s':[':w','save file']}
let g:which_key_map.g = [':Goyo','goyo on/off']
let g:which_key_map.n = 'show/hide line number'
let g:which_key_map.q = [':q','quit']
let g:which_key_map.r = [':source $MYVIMRC','reload configuration']
let g:which_key_map.w = [':w','write changes']
let g:which_key_map['/']='clear search highlight'
let g:which_key_map['='] = ['gg=G<C-o>','auto formatting']
call which_key#register('<Space>',"g:which_key_map")

"shortcuts
inoremap <C-BS> <C-\><C-o>db
inoremap <C-h> <C-\><C-o>db
inoremap <C-s> <Esc>:w<CR>
inoremap <C-w> <C-\><C-o>db
inoremap <C-z> <C-o>u
inoremap <silent> <C-/> <C-o>:nohlsearch<CR>
inoremap <silent> <C-_> <C-o>:nohlsearch<CR>
nnoremap <C-s> :w<CR>
nnoremap <C-z> u
nnoremap <silent> <C-/> :nohlsearch<CR>
nnoremap <silent> <C-_> :nohlsearch<CR>

"independent statusline implementation
hi StatusCommand ctermbg=2 ctermfg=0 cterm=NONE
hi StatusInsert ctermbg=4 ctermfg=0 cterm=NONE
hi StatusMid ctermbg=NONE ctermfg=NONE cterm=NONE
hi StatusNormal ctermbg=15 ctermfg=0 cterm=NONE
hi StatusReplace ctermbg=1 ctermfg=0 cterm=NONE
hi StatusRight ctermbg=8 ctermfg=15 cterm=NONE
hi StatusVisual ctermbg=3 ctermfg=0 cterm=NONE
let g:currentmode={'n':'normal','v':'visual','V':'v-line',"\<C-V>":'v-block','i':'insert','R':'replace','c':'command','t':'terminal'}
function! StatusActive() abort
	let l:m=mode()
	if l:m==#'i' | let l:color='%#StatusInsert#'
	elseif l:m==#'v' || l:m==#'V' || l:m==#"\<C-V>" | let l:color='%#StatusVisual#'
	elseif l:m==#'R' | let l:color='%#StatusReplace#'
	elseif l:m==#'c' | let l:color='%#StatusCommand#'
	else | let l:color='%#StatusNormal#'
	endif
	let l:modestr=get(g:currentmode,l:m,l:m)
	return l:color . ' ' . l:modestr . ' %#StatusMid#%=%#StatusRight# %t '
endfunction
function! StatusInactive() abort
	return '%#StatusMid#%=%#StatusRight# %t '
endfunction
augroup CustomStatusLine
	autocmd!
	autocmd WinEnter,BufEnter * setlocal statusline=%!StatusActive()
	autocmd WinLeave,BufLeave * setlocal statusline=%!StatusInactive()
	autocmd InsertEnter,InsertLeave * redrawstatus
	if exists('##ModeChanged')
		autocmd ModeChanged *:* redrawstatus
	endif
augroup END
set statusline=%!StatusActive()

"editor elements colorscheme
hi bold ctermbg=NONE ctermfg=NONE cterm=bold
hi colorcolumn ctermbg=0 ctermfg=NONE cterm=NONE
hi conceal ctermbg=0 ctermfg=8 cterm=NONE
hi cursearch ctermbg=3 ctermfg=0 cterm=NONE
hi cursor ctermbg=15 ctermfg=0 cterm=NONE
hi cursorcolumn ctermbg=0 ctermfg=NONE cterm=NONE
hi cursorline ctermbg=0 ctermfg=NONE cterm=NONE
hi cursorlinenr ctermbg=0 ctermfg=NONE cterm=bold
hi debugbreakpoint ctermbg=NONE ctermfg=8 cterm=NONE
hi debugpc ctermbg=NONE ctermfg=7 cterm=NONE
hi diffadd ctermbg=10 ctermfg=0 cterm=NONE
hi diffadded ctermbg=NONE ctermfg=10 cterm=NONE
hi diffchange ctermbg=12 ctermfg=0 cterm=NONE
hi diffchanged ctermbg=NONE ctermfg=12 cterm=NONE
hi diffdelete ctermbg=9 ctermfg=0 cterm=NONE
hi difffile ctermbg=NONE ctermfg=12 cterm=NONE
hi diffindexline ctermbg=NONE ctermfg=14 cterm=NONE
hi diffline ctermbg=NONE ctermfg=7 cterm=NONE
hi diffnewfile ctermbg=NONE ctermfg=13 cterm=NONE
hi diffoldfile ctermbg=NONE ctermfg=11 cterm=NONE
hi diffremoved ctermbg=NONE ctermfg=9 cterm=NONE
hi difftext ctermbg=14 ctermfg=0 cterm=NONE
hi directory ctermbg=NONE ctermfg=4 cterm=NONE
hi errormsg ctermbg=NONE ctermfg=7 cterm=bold,italic
hi foldcolumn ctermbg=NONE ctermfg=7 cterm=NONE
hi folded ctermbg=NONE ctermfg=12 cterm=NONE
hi healtherror ctermbg=NONE ctermfg=1 cterm=NONE
hi healthsuccess ctermbg=NONE ctermfg=2 cterm=NONE
hi healthwarning ctermbg=NONE ctermfg=3 cterm=NONE
hi helpleadblank ctermbg=NONE ctermfg=NONE cterm=NONE
hi helpnormal ctermbg=NONE ctermfg=NONE cterm=NONE
hi incsearch ctermbg=1 ctermfg=0 cterm=NONE
hi italic ctermbg=NONE ctermfg=NONE cterm=italic
hi linenr ctermbg=NONE ctermfg=8 cterm=NONE
hi matchparen ctermbg=8 ctermfg=NONE cterm=bold
hi modemsg ctermbg=15 ctermfg=0 cterm=bold
hi moremsg ctermbg=NONE ctermfg=4 cterm=NONE
hi nontext ctermbg=NONE ctermfg=0 cterm=NONE
hi pmenu ctermbg=0 ctermfg=NONE cterm=NONE
hi pmenusbar ctermbg=0 ctermfg=NONE cterm=NONE
hi pmenusel ctermbg=4 ctermfg=0 cterm=NONE
hi pmenuthumb ctermbg=7 ctermfg=NONE cterm=NONE
hi question ctermbg=NONE ctermfg=4 cterm=NONE
hi quickfixline ctermbg=0 ctermfg=14 cterm=NONE
hi search ctermbg=8 ctermfg=NONE cterm=NONE
hi signcolumn ctermbg=NONE ctermfg=7 cterm=NONE
hi specialkey ctermbg=NONE ctermfg=8 cterm=NONE
hi spellbad ctermbg=NONE ctermfg=NONE cterm=undercurl
hi spellcap ctermbg=NONE ctermfg=NONE cterm=undercurl
hi spelllocal ctermbg=NONE ctermfg=NONE cterm=undercurl
hi spellrare ctermbg=NONE ctermfg=NONE cterm=undercurl
hi tabline ctermbg=0 ctermfg=NONE cterm=NONE
hi tablinefill ctermbg=NONE ctermfg=NONE cterm=NONE
hi tablinesel ctermbg=15 ctermfg=0 cterm=NONE
hi title ctermbg=NONE ctermfg=4 cterm=bold
hi toolbarbutton ctermbg=8 ctermfg=15 cterm=NONE
hi toolbarline ctermbg=0 ctermfg=15 cterm=NONE
hi vertsplit ctermbg=0 ctermfg=NONE cterm=NONE
hi vertsplitnc ctermbg=0 ctermfg=8 cterm=NONE
hi visual ctermbg=8 ctermfg=15 cterm=bold
hi visualnos ctermbg=8 ctermfg=15 cterm=bold
hi warningmsg ctermbg=NONE ctermfg=11 cterm=NONE
hi wildmenu ctermbg=0 ctermfg=15 cterm=NONE

"syntax highlighting colorscheme
hi boolean ctermbg=NONE ctermfg=11 cterm=NONE
hi character ctermbg=NONE ctermfg=2 cterm=NONE
hi comment ctermbg=NONE ctermfg=7 cterm=NONE
hi conditional ctermbg=NONE ctermfg=5 cterm=NONE
hi constant ctermbg=NONE ctermfg=11 cterm=NONE
hi debug ctermbg=NONE ctermfg=13 cterm=NONE
hi define ctermbg=NONE ctermfg=6 cterm=NONE
hi delimiter ctermbg=NONE ctermfg=7 cterm=NONE
hi error ctermbg=1 ctermfg=15 cterm=NONE
hi exception ctermbg=NONE ctermfg=13 cterm=NONE
hi float ctermbg=NONE ctermfg=11 cterm=NONE
hi function ctermbg=NONE ctermfg=12 cterm=NONE
hi identifier ctermbg=NONE ctermfg=NONE cterm=NONE
hi ignore ctermbg=NONE ctermfg=NONE cterm=NONE
hi include ctermbg=NONE ctermfg=6 cterm=NONE
hi keyword ctermbg=NONE ctermfg=5 cterm=NONE
hi label ctermbg=NONE ctermfg=5 cterm=NONE
hi macro ctermbg=NONE ctermfg=14 cterm=NONE
hi number ctermbg=NONE ctermfg=11 cterm=NONE
hi operator ctermbg=NONE ctermfg=7 cterm=NONE
hi precondit ctermbg=NONE ctermfg=6 cterm=NONE
hi preproc ctermbg=NONE ctermfg=6 cterm=NONE
hi repeat ctermbg=NONE ctermfg=5 cterm=NONE
hi special ctermbg=NONE ctermfg=14 cterm=NONE
hi specialchar ctermbg=NONE ctermfg=14 cterm=NONE
hi specialcomment ctermbg=NONE ctermfg=10 cterm=NONE
hi statement ctermbg=NONE ctermfg=5 cterm=NONE
hi storageclass ctermbg=NONE ctermfg=3 cterm=NONE
hi string ctermbg=NONE ctermfg=2 cterm=NONE
hi structure ctermbg=NONE ctermfg=3 cterm=NONE
hi tag ctermbg=NONE ctermfg=14 cterm=NONE
hi todo ctermbg=3 ctermfg=0 cterm=NONE
hi type ctermbg=NONE ctermfg=3 cterm=NONE
hi typedef ctermbg=NONE ctermfg=3 cterm=NONE
hi underlined ctermbg=NONE ctermfg=NONE cterm=underline
