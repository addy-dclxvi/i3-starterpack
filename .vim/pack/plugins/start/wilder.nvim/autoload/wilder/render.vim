scriptencoding utf-8

let s:has_strtrans_issue = strdisplaywidth('') != strdisplaywidth(strtrans(''))

" DEPRECATED: use wilder#render#draw_candidate()
function! wilder#render#draw_x(ctx, result, i) abort
  return wilder#render#draw_candidate(a:ctx, a:result, a:i)
endfunction

function! wilder#render#draw_candidate(ctx, result, i) abort
  let l:x = wilder#main#get_candidate(a:ctx, a:result, a:i)

  if has_key(a:result, 'draw')
    let l:ctx = {
          \ 'i': a:i,
          \ 'selected': a:ctx.selected == a:i,
          \ }

    for l:F in a:result.draw
      if type(l:F) isnot v:t_func
        let l:F = function(l:F)
      endif

      let l:x = l:F(l:ctx, l:x, get(a:result, 'data', {}))
    endfor
  endif

  return wilder#render#to_printable(l:x)
endfunction

function! wilder#render#spans_to_chunks(str, spans, is_selected, highlights) abort
  let l:res = []

  let l:non_span_start = 0
  let l:end = 0

  let l:non_span_hl = a:highlights[a:is_selected ? 'selected' : 'default']
  let l:default_span_hl = a:highlights[a:is_selected ? 'selected_accent' : 'accent']

  let l:i = 0
  while l:i < len(a:spans)
    let l:span = a:spans[l:i]
    let l:start = l:span[0]
    let l:len = l:span[1]

    if len(l:span) == 2
      " [start, length]
      let l:span_hl = l:default_span_hl
    elseif len(l:span) == 3
      " [start, length, hl]
      let l:span_hl = l:span[2]
    else
      " [start, length, hl, selected_hl]
      let l:span_hl = a:is_selected ?
            \ l:span[3] :
            \ l:span[2]
    endif

    if l:start > 0
      call add(l:res, [strpart(a:str, l:non_span_start, l:start - l:non_span_start), l:non_span_hl])
    endif

    call add(l:res, [strpart(a:str, l:start, l:len), l:span_hl])

    let l:non_span_start = l:start + l:len
    let l:i += 1
  endwhile

  call add(l:res, [strpart(a:str, l:non_span_start), l:non_span_hl])

  return l:res
endfunction

function! s:add_span(res, str, span_hls, hl_index) abort
  if len(a:span_hls) == 1
    call add(a:res, [a:str, a:span_hls[0]])
    return a:hl_index
  elseif empty(a:span_hls)
    call add(a:res, [a:str])
    return a:hl_index
  endif

  let l:chars = split(a:str, '\zs')
  let l:hl_index = a:hl_index

  for l:char in l:chars
    if l:hl_index < len(a:span_hls)
      call add(a:res, [l:char, a:span_hls[l:hl_index]])
      let l:hl_index += 1
    else
      call add(a:res, [l:char, a:span_hls[-1]])
    endif
  endfor
  
  return l:hl_index
endfunction

function! wilder#render#to_printable(x) abort
  if !s:has_strtrans_issue
    " check if first character is a combining character
    if strdisplaywidth(' ' . a:x) == strdisplaywidth(a:x)
      return strtrans(' ' . a:x)
    endif

    return strtrans(a:x)
  endif

  let l:transformed = strtrans(a:x)
  " strtrans is ok
  if strdisplaywidth(a:x) == strdisplaywidth(l:transformed)
    " check if first character is a combining character
    if strdisplaywidth(' ' . a:x) == strdisplaywidth(a:x)
      return strtrans(' ' . a:x)
    endif

    return strtrans(a:x)
  endif

  let l:res = ''
  let l:first = 1

  for l:char in split(a:x, '\zs')
    let l:transformed_char = strtrans(l:char)

    let l:transformed_width = strdisplaywidth(l:transformed_char)
    let l:width = strdisplaywidth(l:char)

    if l:transformed_width == l:width
      " strtrans is ok
      let l:res .= l:transformed_char
    elseif l:transformed_width == 0
      " strtrans returns empty character, use original char
      if l:first && strdisplaywidth(' ' . l:char) == strdisplaywidth(l:char)
        " check if first character is combining character
        let l:res .= ' ' . l:char
      else
        let l:res .= l:char
      endif
    else
      " fallback to hex representation
      let l:res .= '<' . printf('%02x', char2nr(l:char)) . '>'
    endif

    let l:first = 0
  endfor

  return l:res
endfunction

function! wilder#render#truncate(len, x, ...) abort
  return s:truncate_and_maybe_pad(a:len, a:x, get(a:, 1, 0), 0)
endfunction

function! wilder#render#truncate_and_pad(len, x, ...) abort
  return s:truncate_and_maybe_pad(a:len, a:x, get(a:, 1, 0), 1)
endfunction

" direction 0 = truncate left
"           1 = truncate right
function! s:truncate_and_maybe_pad(len, x, direction, should_pad) abort
  if a:len <= 0
    return ''
  endif

  let l:width = strdisplaywidth(a:x)
  if l:width > a:len
    let l:chars = split(a:x, '\zs')

    if a:direction
      let l:index = 0
      while l:width > a:len && l:index < len(l:chars)
        let l:width -= strdisplaywidth(l:chars[l:index])

        let l:index += 1
      endwhile

      let l:str = join(l:chars[l:index :], '')
    else
      let l:index = len(l:chars) - 1
      while l:width > a:len && l:index >= 0
        let l:width -= strdisplaywidth(l:chars[l:index])

        let l:index -= 1
      endwhile

      let l:str = join(l:chars[:l:index], '')
    endif
  else
    let l:str = a:x
  endif

  if a:should_pad
    let l:str .= repeat(' ', a:len - l:width)
  endif

  return l:str
endfunction

function! wilder#render#truncate_chunks(len, xs, ...) abort
  if a:len <= 0
    return []
  endif

  " direction 0 = truncate left
  "           1 = truncate right
  let l:direction = get(a:, 1, 0)

  let l:width = 0
  let l:res = []

  if l:direction
    let l:i = len(a:xs) - 1
    while l:i >= 0
      let l:chunk = a:xs[l:i]
      let l:chunk_width = strdisplaywidth(l:chunk[0])

      if l:width + l:chunk_width > a:len
        let l:truncated_chunk = [wilder#render#truncate(a:len - l:width, l:chunk[0], 1)]
        let l:truncated_chunk += l:chunk[1:]
        call insert(l:res, l:truncated_chunk)
        return l:res
      endif

      call insert(l:res, l:chunk)
      let l:width += l:chunk_width
      let l:i -= 1
    endwhile
  else
    let l:i = 0
    while l:i < len(a:xs)
      let l:chunk = a:xs[l:i]
      let l:chunk_width = strdisplaywidth(l:chunk[0])

      if l:width + l:chunk_width > a:len
        let l:truncated_chunk = [wilder#render#truncate(a:len - l:width, l:chunk[0])]
        let l:truncated_chunk += l:chunk[1:]
        call add(l:res, l:truncated_chunk)
        return l:res
      endif

      call add(l:res, l:chunk)
      let l:width += l:chunk_width
      let l:i += 1
    endwhile
  endif

  return l:res
endfunction

function! wilder#render#chunks_displaywidth(chunks) abort
  let l:width = 0

  for l:chunk in a:chunks
    if !empty(l:chunk)
      let l:width += strdisplaywidth(l:chunk[0])
    endif
  endfor

  return l:width
endfunction
