function! wilder#renderer#component#popupmenu_buffer_flags#(opts) abort
  let l:flags = get(a:opts, 'flags', '1u%a-+ ')

  if empty(l:flags)
    return {-> ''}
  endif

  let l:icons = {
        \ '%': '%',
        \ '#': '#',
        \ '+': '+',
        \ '-': '-',
        \ '=': '=',
        \ 'a': 'a',
        \ 'h': 'h',
        \ 'u': 'u',
        \ }
  if has_key(a:opts, 'icons')
    let l:icons = extend(l:icons, a:opts.icons)
  endif

  let l:spacing = {}
  let l:icon_width = {}
  for l:flag in ['%', '+', '-', 'a', 'u', 'A']
    let l:icon = l:flag ==# 'A' ? l:icons['%'] : l:icons[l:flag]
    let l:width = strdisplaywidth(l:icon)
    let l:icon_width[l:flag] = l:width
    let l:spacing[l:flag] = repeat(' ', l:width)
  endfor

  let l:state = {
        \ 'flags': l:flags,
        \ 'cache': wilder#cache#cache(),
        \ 'session_id': -1,
        \ 'icons': l:icons,
        \ 'icon_width': l:icon_width,
        \ 'spacing': l:spacing,
        \ }

  if has_key(a:opts, 'hl')
    let l:state.hl = a:opts.hl
  endif

  if has_key(a:opts, 'selected_hl')
    let l:state.selected_hl = a:opts.selected_hl
  endif

  return {ctx, result -> s:buffer_status(l:state, ctx, result)}
endfunction

function! s:buffer_status(state, ctx, result) abort
  if !has_key(a:result, 'data')
    return ''
  endif

  let l:expand = get(a:result.data, 'cmdline.expand', '')

  if l:expand !=# 'buffer' && l:expand !=# 'file' && l:expand !=# 'file_in_path'
    return ''
  endif

  let l:flags = a:state.flags

  let l:session_id = a:ctx.session_id
  if a:state.session_id != l:session_id
    call a:state.cache.clear()
    let a:state.session_id = l:session_id
  endif

  let [l:start, l:end] = a:ctx.page
  let l:rows = repeat([0], l:end - l:start + 1)

  let l:hl = get(a:state, 'hl', a:ctx.highlights['default'])
  let l:selected_hl = get(a:state, 'selected_hl', a:ctx.highlights['selected'])

  let l:width = s:get_strdisplaywidth(l:flags, a:state.icon_width)
  let l:empty_chunks = [[repeat(' ', l:width), l:hl, l:selected_hl]]

  let l:i = l:start
  while l:i <= l:end
    let l:index = l:i - l:start

    let l:key = wilder#main#get_candidate(a:ctx, a:result, l:i)

    if a:state.cache.has_key(l:key)
      let l:rows[l:index] = a:state.cache.get(l:key)
      let l:i += 1
      continue
    endif

    let l:x = fnamemodify(l:key, ':~')

    let l:bufnr = bufnr('^' . l:x . '$')

    if l:bufnr == -1
      call a:state.cache.set(l:key, l:empty_chunks)
      let l:rows[l:index] = l:empty_chunks
      let l:i += 1
      continue
    endif

    let l:status = ''

    let l:j = 0
    while l:j < len(l:flags)
      let l:flag = l:flags[l:j]

      if l:flag ==# '1'
        let l:status .= repeat(' ', a:state.icon_width['1'] - strdisplaywidth(l:bufnr))
      endif

      let l:status .= s:get_str(l:flag, l:bufnr, a:state.icons, a:state.spacing)

      let l:chunks = [[l:status, l:hl, l:selected_hl]]
      let l:rows[l:index] = l:chunks

      let l:j += 1
    endwhile

    call a:state.cache.set(l:key, l:chunks)

    let l:i += 1
  endwhile

  let l:height = a:ctx.height
  let l:width = empty(l:rows) ? 0 : wilder#render#chunks_displaywidth(l:rows[0])
  let l:empty_row = [[repeat(' ', l:width)]]
  let l:rows += repeat([l:empty_row], l:height - len(l:rows))

  return l:rows
endfunction

function! s:get_strdisplaywidth(flags, icon_width) abort
  let l:width = 0

  let l:i = 0
  while l:i < len(a:flags)
    let l:flag = a:flags[l:i]

    if l:flag ==# '1'
      let l:bufnr_width = strdisplaywidth(bufnr('$'))
      let l:width += l:bufnr_width

      let a:icon_width['1'] = l:bufnr_width
    elseif l:flag ==# ' '
      let l:width += 1
    elseif has_key(a:icon_width, l:flag)
      let l:width += a:icon_width[l:flag]
    endif

    let l:i += 1
  endwhile

  return l:width
endfunction

function! s:get_str(flag, bufnr, icons, spacing) abort
  if a:flag ==# ' '
    return ' '
  endif

  if a:flag ==# '1'
    return a:bufnr
  endif

  if a:flag ==# '%'
    if a:bufnr == bufnr('%')
      return a:icons['%']
    endif

    if a:bufnr == bufnr('#')
      return a:icons['#']
    endif

    return a:spacing['%']
  endif

  if a:flag ==# 'A'
    if a:bufnr == bufnr('%')
      return a:icons['%']
    endif

    if a:bufnr == bufnr('#')
      return a:icons['#']
    endif

    if bufloaded(a:bufnr)
      return !empty(win_findbuf(a:bufnr)) ?
            \ a:icons['a'] :
            \ a:icons['h']
    endif

    return a:spacing['%']
  endif

  if a:flag ==# '+'
    return getbufvar(a:bufnr, '&modified') ?
          \ a:icons['+'] :
          \ a:spacing['+']
  endif

  if a:flag ==# '-'
    return getbufvar(a:bufnr, '&readonly') ?
          \ a:icons['='] :
          \ !getbufvar(a:bufnr, '&modifiable') ?
          \ a:icons['-'] :
          \ a:spacing['-']
  endif

  if a:flag ==# 'a'
    if bufloaded(a:bufnr)
      return !empty(win_findbuf(a:bufnr)) ?
            \ a:icons['a'] :
            \ a:icons['h']
    endif

    return a:spacing['a']
  endif

  if a:flag ==# 'u'
    return buflisted(a:bufnr) ?
          \ a:spacing['u'] :
          \ a:icons['u']
  endif

  return ''
endfunction
