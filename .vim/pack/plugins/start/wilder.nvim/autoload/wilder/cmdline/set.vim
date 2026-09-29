function! wilder#cmdline#set#get_bool_options() abort
  return copy(s:bool_options_list)
endfunction

function! wilder#cmdline#set#do(ctx) abort
  let a:ctx.expand = 'option'

  if a:ctx.pos == len(a:ctx.cmdline)
    return
  endif

  let l:arg_start = a:ctx.pos
  let l:p = len(a:ctx.cmdline) - 1

  while l:p > l:arg_start
    let l:s = l:p
    if a:ctx.cmdline[l:p] ==# ' ' || a:ctx.cmdline[l:p] ==# ','
      while l:s > l:arg_start && a:ctx.cmdline[l:s-1] ==# '\'
        let l:s -= 1
      endwhile

      if a:ctx.cmdline[l:p] ==# ' ' && (l:p - l:s) % 2 == 0
        let l:p += 1
        break
      endif
    endif

    let l:p -= 1
  endwhile

  if a:ctx.cmdline[l:p : l:p+1] ==# 'no'
    let l:p += 2
    let a:ctx.expand = 'option_bool'
  endif

  if a:ctx.cmdline[l:p : l:p+2] ==# 'inv'
    let l:p += 3
    let a:ctx.expand = 'option_bool'
  endif

  let a:ctx.pos = l:p

  " skip termkeys and termcap options

  while l:p < len(a:ctx.cmdline)
    let l:char = a:ctx.cmdline[l:p]
    if !(l:char >=# 'a' && l:char <=# 'z' ||
          \ l:char >=# 'A' && l:char <=# 'Z' ||
          \ l:char >=# '0' && l:char <=# '9') &&
          \ l:char !=# '_' &&
          \ l:char !=# '*'
      break
    endif

    let l:p += 1
  endwhile

  if l:p == len(a:ctx.cmdline)
    return
  endif

  let l:option_name = a:ctx.cmdline[a:ctx.pos : l:p - 1]
  let l:completions = getcompletion(l:option_name, 'option')
  if empty(l:completions)
    " Show unknown option error if trying to set non-existent option.
    if a:ctx.cmdline[len(a:ctx.cmdline) - 1] ==# '='
      let a:ctx.expand = 'option_old'
      let a:ctx.option = l:option_name
    endif

    return
  endif

  if len(l:completions) == 1
        \ && l:completions[0] ==# l:option_name
        \ && has_key(s:bool_options, l:option_name)
    let a:ctx.expand = 'nothing'
    return
  endif

  let a:ctx.option = l:option_name

  let l:char = a:ctx.cmdline[l:p]

  if (l:char ==# '-' || l:char ==# '+' || l:char ==# '^') &&
        \ l:p < len(a:ctx.cmdline) &&
        \ a:ctx.cmdline[l:p+1] ==# '='
    let l:char = '='
    let l:p += 1
  endif

  if l:char !=# '=' && l:char !=# ':' ||
        \ a:ctx.expand ==# 'option_bool' ||
        \ has_key(s:bool_options, l:option_name)
    let a:ctx.expand = 'unsuccessful'
    return
  endif

  if l:p + 1 == len(a:ctx.cmdline)
    let a:ctx.expand = 'option_old'
  else
    let a:ctx.expand = 'nothing'
  endif

  let a:ctx.pos = l:p + 1
endfunction

let s:bool_options = {
      \ 'allowrevins': 1,
      \ 'autochdir': 1,
      \ 'arabic': 1,
      \ 'arabicshape': 1,
      \ 'autoindent': 1,
      \ 'autoread': 1,
      \ 'autowrite': 1,
      \ 'autowriteall': 1,
      \ 'backup': 1,
      \ 'binary': 1,
      \ 'bomb': 1,
      \ 'breakindent': 1,
      \ 'buflisted': 1,
      \ 'cindent': 1,
      \ 'confirm': 1,
      \ 'copyindent': 1,
      \ 'cscoperelative': 1,
      \ 'cscopetag': 1,
      \ 'cursorbind': 1,
      \ 'cursorcolumn': 1,
      \ 'cursorline': 1,
      \ 'delcombine': 1,
      \ 'diff': 1,
      \ 'digraph': 1,
      \ 'emoji': 1,
      \ 'endofline': 1,
      \ 'equalalways': 1,
      \ 'errorbells': 1,
      \ 'expandtab': 1,
      \ 'fileignorecase': 1,
      \ 'fixendofline': 1,
      \ 'foldenable': 1,
      \ 'fsync': 1,
      \ 'gdefault': 1,
      \ 'hidden': 1,
      \ 'hkmap': 1,
      \ 'hkmapp': 1,
      \ 'hlsearch': 1,
      \ 'icon': 1,
      \ 'ignorecase': 1,
      \ 'imcmdline': 1,
      \ 'imdisable': 1,
      \ 'incsearch': 1,
      \ 'infercase': 1,
      \ 'insertmode': 1,
      \ 'joinspaces': 1,
      \ 'langremap': 1,
      \ 'lazyredraw': 1,
      \ 'linebreak': 1,
      \ 'lisp': 1,
      \ 'list': 1,
      \ 'loadplugins': 1,
      \ 'magic': 1,
      \ 'modeline': 1,
      \ 'modelineexpr': 1,
      \ 'modifiable': 1,
      \ 'modified': 1,
      \ 'more': 1,
      \ 'mousefocus': 1,
      \ 'mousehide': 1,
      \ 'number': 1,
      \ 'opendevice': 1,
      \ 'paste': 1,
      \ 'preserveindent': 1,
      \ 'previewwindow': 1,
      \ 'prompt': 1,
      \ 'readonly': 1,
      \ 'relativenumber': 1,
      \ 'remap': 1,
      \ 'revins': 1,
      \ 'rightleft': 1,
      \ 'ruler': 1,
      \ 'scrollbind': 1,
      \ 'secure': 1,
      \ 'shellslash': 1,
      \ 'shelltemp': 1,
      \ 'shiftround': 1,
      \ 'showcmd': 1,
      \ 'showfulltag': 1,
      \ 'showmatch': 1,
      \ 'showmode': 1,
      \ 'smartcase': 1,
      \ 'smartindent': 1,
      \ 'smarttab': 1,
      \ 'spell': 1,
      \ 'splitbelow': 1,
      \ 'splitright': 1,
      \ 'startofline': 1,
      \ 'swapfile': 1,
      \ 'tagbsearch': 1,
      \ 'tagrelative': 1,
      \ 'tagstack': 1,
      \ 'termbidi': 1,
      \ 'termguicolors': 1,
      \ 'terse': 1,
      \ 'tildeop': 1,
      \ 'timeout': 1,
      \ 'ttimeout': 1,
      \ 'title': 1,
      \ 'undofile': 1,
      \ 'visualbell': 1,
      \ 'warn': 1,
      \ 'wildignorecase': 1,
      \ 'wildmenu': 1,
      \ 'winfixheight': 1,
      \ 'winfixwidth': 1,
      \ 'wrap': 1,
      \ 'wrapscan': 1,
      \ 'write': 1,
      \ 'writeany': 1,
      \ 'writebackup': 1,
      \ }

let s:bool_options_list = sort(keys(s:bool_options))
