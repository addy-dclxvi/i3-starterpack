let s:hl_list = []

let s:attr_list = ['bold', 'underline', 'undercurl', 'strikethrough',
      \ 'italic', 'standout', 'reverse', 'inverse']

let s:attr_map = {
      \ 'bold': 0,
      \ 'underline': 0,
      \ 'undercurl': 0,
      \ 'strikethrough': 0,
      \ 'italic': 0,
      \ 'standout': 0,
      \ 'reverse': 0,
      \ }

function! wilder#highlight#init_hl() abort
  for [l:name, l:x, l:xs] in s:hl_list
    call s:make_hl(l:name, l:x, l:xs)
  endfor
endfunction

function! wilder#highlight#make_hl(name, x, xs) abort
  call s:make_hl(a:name, a:x, a:xs)
  call filter(s:hl_list, {i, elem -> elem[0] !=# a:name})
  call add(s:hl_list, [a:name, deepcopy(a:x), deepcopy(a:xs)])
  return a:name
endfunction

function! wilder#highlight#make_temp_hl(name, x, xs) abort
  call s:make_hl(a:name, a:x, a:xs)
  return a:name
endfunction

function! s:make_hl(name, x, xs) abort
  let l:x = s:to_hl_list(a:x)

  for l:elem in a:xs
    let l:y = s:to_hl_list(l:elem)
    let l:x = s:combine_hl_list(l:x, l:y)
  endfor

  call s:make_hl_from_list(a:name, l:x)
endfunction

function! s:to_hl_list(x) abort
  if type(a:x) is v:t_string
    let l:x = wilder#highlight#get_hl(a:x)
  else
    let l:x = a:x
  endif

  if type(l:x) is v:t_list && type(l:x[0]) is v:t_list
    return l:x
  endif

  let l:term_hl = s:get_attrs_as_list(l:x[0])

  let l:cterm_hl = [
        \ get(l:x[1], 'foreground', 'NONE'),
        \ get(l:x[1], 'background', 'NONE')
        \ ] + s:get_attrs_as_list(l:x[1])

  let l:gui_hl = [
        \ get(l:x[2], 'foreground', 'NONE'),
        \ get(l:x[2], 'background', 'NONE')
        \ ] + s:get_attrs_as_list(l:x[2])

  return [l:term_hl, l:cterm_hl, l:gui_hl]
endfunction

function! s:combine_hl_list(l, m) abort
  let l:term_hl = copy(a:l[0])
  let l:cterm_hl = copy(a:l[1])
  let l:gui_hl = copy(a:l[2])

  if len(l:term_hl) <= 2
    let l:term_hl = copy(a:m[0])
  else
    let l:term_hl += a:m[0][2:]
  endif

  let l:cterm_fg = get(a:m[1], 0, -1)
  if l:cterm_fg isnot 'NONE' && l:cterm_fg isnot -1
    if empty(l:cterm_hl)
      let l:cterm_hl = [l:cterm_fg]
    else
      let l:cterm_hl[0] = l:cterm_fg
    endif
  endif

  let l:cterm_bg = get(a:m[1], 1, -1)
  if l:cterm_bg isnot 'NONE' && l:cterm_bg isnot -1
    if empty(l:cterm_hl)
      let l:cterm_hl = ['NONE', l:cterm_bg]
    else
      let l:cterm_hl[1] = l:cterm_bg
    endif
  endif

  if len(a:m[1]) > 2
    if empty(l:cterm_hl)
      let l:cterm_hl = ['NONE', 'NONE'] + a:m[1][2:]
    else
      let l:cterm_hl += a:m[1][2:]
    endif
  endif

  let l:gui_fg = get(a:m[2], 0, -1)
  if l:gui_fg isnot 'NONE' && l:gui_fg isnot -1
    if empty(l:gui_hl)
      let l:gui_hl = [l:gui_fg]
    else
      let l:gui_hl[0] = l:gui_fg
    endif
  endif

  let l:gui_bg = get(a:m[2], 1, -1)
  if l:gui_bg isnot 'NONE' && l:gui_bg isnot -1
    if empty(l:gui_hl)
      let l:gui_hl = ['NONE', l:gui_bg]
    else
      let l:gui_hl[1] = l:gui_bg
    endif
  endif

  if len(a:m[2]) > 2
    if empty(l:gui_hl)
      let l:gui_hl = ['NONE', 'NONE'] + a:m[2][2:]
    else
      let l:gui_hl += a:m[2][2:]
    endif
  endif

  return [l:term_hl, l:cterm_hl, l:gui_hl]
endfunction

function! s:normalise_attrs(hl) abort
  let l:attr_map = copy(s:attr_map)

  for l:attr in a:hl[2:]
    if has_key(l:attr_map, l:attr)
      let l:attr_map[l:attr] = 1
    elseif l:attr[:1] ==# 'no' && has_key(l:attr_map, l:attr[2:])
      let l:attr_map[l:attr[2:]] = 0
    endif
  endfor

  let l:result = []
  for l:attr in keys(l:attr_map)
    if l:attr_map[l:attr]
      call add(l:result, l:attr)
    endif
  endfor

  return a:hl[:1] + l:result
endfunction

function! s:make_hl_from_list(name, args) abort
  let l:term_hl = s:normalise_attrs(a:args[0])
  let l:cterm_hl = s:normalise_attrs(a:args[1])
  let l:gui_hl = s:normalise_attrs(a:args[2])

  let l:cmd = 'hi! ' . a:name . ' '

  let l:term_attr = l:term_hl[2:]
  if len(l:term_hl) >= 2
    let l:cmd .= 'term=' . join(l:term_attr, ',') . ' '
  endif

  let l:cterm_attr = l:cterm_hl[2:]
  if !empty(l:cterm_attr)
    let l:cmd .= 'cterm=' . join(l:cterm_attr, ',') . ' '
  endif

  if len(l:cterm_hl) >= 1
    if l:cterm_hl[0] >= 0
      let l:cmd .= 'ctermfg=' . l:cterm_hl[0] . ' '
    endif

    if len(l:cterm_hl) >= 2 && l:cterm_hl[1] >= 0
      let l:cmd .= 'ctermbg=' . l:cterm_hl[1] . ' '
    endif
  endif

  let l:gui_attr = l:gui_hl[2:]
  if !empty(l:gui_attr)
    let l:cmd .= 'gui=' . join(l:gui_attr, ',') . ' '
  endif

  if len(l:gui_hl) >= 1
    if type(l:gui_hl[0]) == v:t_number
      let l:cmd .= 'guifg=' . printf('#%06x', l:gui_hl[0]) . ' '
    else
      let l:cmd .= 'guifg=' . l:gui_hl[0] . ' '
    endif

    if len(l:gui_hl) >= 2
      if type(l:gui_hl[1]) == v:t_number
        let l:cmd .= 'guibg=' . printf('#%06x', l:gui_hl[1]) . ' '
      else
        let l:cmd .= 'guibg=' . l:gui_hl[1] . ' '
      endif
    endif
  endif

  exe l:cmd
endfunction

function! s:get_attrs_as_list(attrs) abort
  let l:res = []

  for l:attr in s:attr_list
    if has_key(a:attrs, l:attr)
      if l:attr ==# 'inverse'
        let l:attr = 'reverse'
      endif

      if a:attrs[l:attr]
        call add(l:res, l:attr)
      else
        call add(l:res, 'no' . l:attr)
      endif
    endif
  endfor

  return l:res
endfunction

function! wilder#highlight#get_hl(group) abort
  if has('nvim')
    return wilder#highlight#get_hl_nvim(a:group)
  else
    return wilder#highlight#get_hl_vim(a:group)
  endif
endfunction

function! wilder#highlight#get_hl_nvim(group) abort
  try
    let l:cterm_hl = nvim_get_hl_by_name(a:group, 0)
    let l:gui_hl = nvim_get_hl_by_name(a:group, 1)

    return [{}, l:cterm_hl, l:gui_hl]
  catch
    return [{}, {}, {}]
  endtry
endfunction

function! wilder#highlight#get_hl_vim(group) abort
  try
    let l:highlight = execute('silent highlight ' . a:group)

    let l:link_matches = matchlist(l:highlight, 'links to \(\S\+\)')
     " follow the link
    if len(l:link_matches) > 0
      return wilder#highlight#get_hl_vim(l:link_matches[1])
    endif

    let l:term_hl = {}
    if match(l:highlight, 'term=\S*') >= 0
      call s:get_hl_attrs(l:term_hl, 'term', l:highlight)
    endif

    let l:cterm_hl = {}
    if match(l:highlight, 'cterm=\S*') >= 0
      call s:get_hl_attrs(l:cterm_hl, 'cterm', l:highlight)
    endif

    let l:cterm_hl.background = get(matchlist(l:highlight, 'ctermbg=\([0-9A-Za-z]\+\)'), 1, 'NONE')
    let l:cterm_hl.foreground = get(matchlist(l:highlight, 'ctermfg=\([0-9A-Za-z]\+\)'), 1, 'NONE')

    let l:gui_hl = {}
    if match(l:highlight, 'gui=\S*') >= 0
      call s:get_hl_attrs(l:gui_hl, 'gui', l:highlight)
    endif

    let l:gui_hl.background = get(matchlist(l:highlight, 'guibg=\([#0-9A-Za-z]\+\)'), 1, 'NONE')
    let l:gui_hl.foreground = get(matchlist(l:highlight, 'guifg=\([#0-9A-Za-z]\+\)'), 1, 'NONE')

    return [l:term_hl, l:cterm_hl, l:gui_hl]
  catch
    return [{}, {}, {}]
  endtry
endfunction

function! s:get_hl_attrs(attrs, key, hl) abort
  let l:prefix = ' ' . a:key . '=\S*'

  for l:attr in s:attr_list
    if match(a:hl, l:prefix . l:attr) >= 0
      if l:attr ==# 'inverse'
        let l:attr = 'reverse'
      endif
      let a:attrs[l:attr] = v:true
    endif
  endfor
endfunction
