function! wilder#renderer#wildmenu_theme#airline_theme(opts) abort
  let l:hls = [
        \ 'airline_c',
        \ 'WildMenu',
        \ 'airline_a_bold',
        \ 'airline_b',
        \ 'airline_y',
        \ 'airline_z_bold',
        \ ]
  return s:theme(copy(a:opts), 'Airline', l:hls)
endfunction

function! wilder#renderer#wildmenu_theme#lightline_theme(opts) abort
  let l:hls = [
        \ 'LightlineMiddle_active',
        \ 'WildMenu',
        \ 'LightlineLeft_active_0',
        \ 'LightlineLeft_active_1',
        \ 'LightlineRight_active_1',
        \ 'LightlineRight_active_0',
        \ ]
  return s:theme(copy(a:opts), 'Lightline', l:hls)
endfunction

" {hls} is in the form [default_hl, selected_hl, left_hl, left_sub_hl,
" right_sub_hl, right_hl]
function! s:theme(opts, namespace, hls) abort
  if !has_key(a:opts, 'highlights')
    let l:highlights = {}
    let a:opts.highlights = l:highlights
  else
    let l:highlights = a:opts.highlights
  endif

  if !has_key(l:highlights, 'default')
    let l:highlights.default = a:hls[0]
  endif

  if !has_key(l:highlights, 'selected')
    let l:highlights.selected = a:hls[1]
  endif

  if !has_key(l:highlights, 'accent')
    let l:highlights.accent = wilder#hl_with_attr(
          \ 'Wilder' . a:namespace . 'ThemeSelected',
          \ l:highlights.default, 'underline', 'bold')
  endif

  if !has_key(l:highlights, 'selected_accent')
    let l:highlights.selected_accent = wilder#hl_with_attr(
          \ 'Wilder' . a:namespace . 'ThemeAccentSelected',
          \ l:highlights.selected, 'underline', 'bold')
  endif

  if !has_key(l:highlights, 'mode')
    let l:highlights.mode = a:hls[2]
  endif

  if !has_key(l:highlights, 'left_arrow2')
    let l:highlights.left_arrow2 = a:hls[3]
  endif

  if !has_key(l:highlights, 'right_arrow2')
    let l:highlights.right_arrow2 = a:hls[4]
  endif

  if !has_key(l:highlights, 'index')
    let l:highlights.index = a:hls[5]
  endif

  let l:is_airline = a:namespace ==# 'Airline'

  if l:is_airline
    let l:use_powerline_symbols = get(
          \ a:opts, 'use_powerline_symbols',
          \ get(g:, 'airline_powerline_fonts', 0))

    if l:use_powerline_symbols
      let l:powerline_symbols = get(a:opts, 'powerline_symbols', ['', ''])
    endif
  else
    let l:lightline = get(g:, 'lightline', {})

    let l:use_powerline_symbols = get(
          \ a:opts, 'use_powerline_symbols',
          \ has_key(l:lightline, 'separator'))

    if l:use_powerline_symbols
      if has_key(l:lightline, 'separator')
        let l:lightline_separators = get(l:lightline, 'separator')
        let l:powerline_symbols = [
              \ l:lightline_separators.left, l:lightline_separators.right]
      else
        let l:powerline_symbols = get(a:opts, 'powerline_symbols', ['', ''])
      endif
    endif
  endif

  if !l:use_powerline_symbols
    let l:separators = ['', '', '', '']
  elseif l:use_powerline_symbols == 1
    let l:separators = [
          \ wilder#wildmenu_powerline_separator(l:powerline_symbols[0],
          \   l:highlights.mode, l:highlights.left_arrow2,  a:namespace . 'Left'),
          \ wilder#wildmenu_powerline_separator(l:powerline_symbols[0],
          \   l:highlights.left_arrow2, l:highlights.default,  a:namespace . 'Left2'),
          \ wilder#wildmenu_powerline_separator(l:powerline_symbols[1],
          \   l:highlights.right_arrow2, l:highlights.default,  a:namespace . 'Right'),
          \ wilder#wildmenu_powerline_separator(l:powerline_symbols[1],
          \   l:highlights.index, l:highlights.right_arrow2,  a:namespace . 'Right2'),
          \ ]
  else
    let l:separators = [
          \ wilder#wildmenu_powerline_separator(l:powerline_symbols[0],
          \   l:highlights.mode, l:highlights.default,  a:namespace . 'Left'),
          \ '',
          \ '',
          \ wilder#wildmenu_powerline_separator(l:powerline_symbols[1],
          \   l:highlights.index, l:highlights.default,  a:namespace . 'Right2'),
          \ ]
  endif

  let a:opts.left = [
        \ wilder#condition(
        \   {-> getcmdtype() ==# ':'},
        \   [' COMMAND ', l:highlights.mode],
        \   [' SEARCH ', l:highlights.mode]
        \ ),
        \ wilder#condition(
        \   {ctx, x -> has_key(ctx, 'error')},
        \   ['!', l:highlights.mode],
        \   wilder#wildmenu_spinner({'hl': l:highlights.mode})
        \ ),
        \ [' ', l:highlights.mode],
        \ l:separators[0],
        \ l:separators[1],
        \ ' ',
        \ ] + get(a:opts, 'left', [])
  let a:opts.right = get(a:opts, 'right', []) + [
        \ ' ',
        \ l:separators[2],
        \ l:separators[3],
        \ wilder#index({'hl': l:highlights.index}),
        \ ]

  return a:opts
endfunction
