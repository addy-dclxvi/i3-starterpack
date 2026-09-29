let s:index = 0

function! wilder#renderer#component#wildmenu_separator#(str, fg, bg, ...) abort
  if a:0 == 0
    let l:key = s:index
    let s:index += 1
  else
    let l:key = a:1
  endif

  let l:name = 'WilderSeparator_' . l:key

  return {
        \ 'value': [a:str, l:name],
        \ 'pre_hook': {ctx -> s:pre_hook(l:name, a:fg, a:bg)},
        \ }
endfunction

function! s:pre_hook(name, from, to) abort
  let l:from_hl = wilder#highlight#get_hl(a:from)
  let l:to_hl = wilder#highlight#get_hl(a:to)

  let l:normal_hl = wilder#highlight#get_hl('Normal')

  let l:cterm_hl = {}
  let l:gui_hl = {}

  let l:colors = [{}, {}, {}]
  call s:get_hl(l:colors[1], l:from_hl[1], l:to_hl[1], l:normal_hl[1], 1)
  call s:get_hl(l:colors[2], l:from_hl[2], l:to_hl[2], l:normal_hl[2], 0)

  call wilder#make_temp_hl(a:name, l:colors)
endfunction

function! s:get_hl(hl, from_hl, to_hl, default_hl, is_cterm) abort
  let l:from_hl_reverse = get(a:from_hl, 'reverse', 0) ||
        \ get(a:from_hl, 'standout', 0)
  let l:to_hl_reverse = get(a:to_hl, 'reverse', 0) ||
        \ get(a:to_hl, 'standout', 0)

  if get(a:default_hl, 'reverse', 0) ||
        \ get(a:default_hl, 'standout', 0)
    let l:default_fg = get(a:default_hl, 'background', 'NONE')
    let l:default_bg = get(a:default_hl, 'foreground', 'NONE')
  else
    let l:default_fg = get(a:default_hl, 'foreground', 'NONE')
    let l:default_bg = get(a:default_hl, 'background', 'NONE')
  endif

  if l:from_hl_reverse
    let l:from_bg = get(a:from_hl, 'foreground', 'NONE')
    if l:from_bg ==# 'NONE'
      let l:from_bg = l:default_fg
    endif
  else
    let l:from_bg = get(a:from_hl, 'background', 'NONE')
    if l:from_bg ==# 'NONE'
      let l:from_bg = l:default_bg
    endif
  endif

  if l:to_hl_reverse
    let l:to_bg = get(a:to_hl, 'foreground', 'NONE')
    if l:to_bg ==# 'NONE'
      let l:to_bg = l:default_fg
    endif
  else
    let l:to_bg = get(a:to_hl, 'background', 'NONE')
    if l:to_bg ==# 'NONE'
      let l:to_bg = l:default_bg
    endif
  endif

  let a:hl.foreground = l:from_bg
  let a:hl.background = l:to_bg
endfunction
