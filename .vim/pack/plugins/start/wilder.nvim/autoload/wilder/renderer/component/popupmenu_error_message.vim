function! wilder#renderer#component#popupmenu_error_message#() abort
  return {ctx, error -> s:error_message(ctx, error)}
endfunction

function! s:error_message(ctx, message) abort
  let l:max_width = a:ctx.max_width
  let l:min_width = a:ctx.min_width
  let l:max_height = a:ctx.max_height
  let l:min_height = a:ctx.min_height

  let l:message = substitute(a:message, "\t", '  ', 'g')
  let l:chars = split(l:message, '\zs')
  let l:lines = []
  let l:line = ''
  let l:line_width = 0

  let l:i = 0
  while l:i < len(l:chars)
    let [l:i, l:whitespace, l:word, l:new_line] = s:find_next_word(l:chars, l:i)

    let l:whitespace_width = strdisplaywidth(l:whitespace)
    let l:word_width = strdisplaywidth(l:word)

    " whitespace + word does not fit in current line
    " move word to next line and omit whitespace
    if l:line_width + l:whitespace_width + l:word_width > l:max_width
      if !empty(l:line)
        call add(l:lines, l:line)
        let l:line = ''
        let l:line_width = 0
      endif

      " word does not fit in 1 line
      if l:word_width > l:line_width
        let [l:split_word, l:line, l:line_width] = s:split_word_into_lines(l:chars, l:i - len(l:word) - 1, l:i, l:max_width)
        let l:lines += l:split_word
      else
        let l:line = l:word
        let l:line_width = l:word_width
      endif
    else
      " skip whitespace if at start of line
      let l:line .= l:whitespace
      let l:line_width += l:whitespace_width

      let l:line .= l:word
      let l:line_width += l:word_width
    endif

    if l:new_line
      call add(l:lines, l:line)
      let l:line = ''
      let l:line_width = 0
    endif
  endwhile

  if !empty(l:line)
    call add(l:lines, l:line)
  endif

  " truncate under max height
  let l:lines = l:lines[: l:max_height]

  " get maximum line width
  let l:max_width = l:min_width
  for l:line in l:lines
    let l:line_width = strdisplaywidth(l:line)
    if l:line_width > l:max_width
      let l:max_width = l:line_width
    endif
  endfor

  let l:hl = a:ctx.highlights.error

  let l:chunkss = []
  for l:line in l:lines
    let l:line = wilder#render#truncate_and_pad(l:max_width, l:line)
    let l:chunk = [l:line, l:hl]
    call add(l:chunkss, [l:chunk])
  endfor

  if len(l:chunkss) < l:min_height
    let l:padding = repeat(' ', l:max_width)
    let l:chunkss += repeat([[[padding, l:hl]]], l:min_height - len(l:chunkss))
  endif

  return l:chunkss
endfunction

function! s:find_next_word(chars, i) abort
  let l:whitespace = ''
  let l:new_line = 0

  " find whitespace
  let l:i = a:i
  while l:i < len(a:chars)
    let l:char = a:chars[l:i]
    if l:char ==# "\<CR>" || l:char ==# "\<NL>"
      let l:i += 1
      let l:new_line = 1
      break
    elseif l:char !~# '\s'
      break
    endif

    let l:whitespace .= l:char
    let l:i += 1
  endwhile

  let l:word = ''
  if !l:new_line
    while l:i < len(a:chars)
      let l:char = a:chars[l:i]
      if l:char ==# "\<CR>" || l:char ==# "\<NL>"
        let l:i += 1
        let l:new_line = 1
        break
      elseif l:char !~# '\S'
        break
      endif

      let l:word .= l:char
      let l:i += 1
    endwhile
  endif

  return [l:i, l:whitespace, l:word, l:new_line]
endfunction

function! s:split_word_into_lines(chars, start, end, max_width) abort
  let l:lines = []
  let l:line = ''
  let l:line_width = 0
  let l:seen_non_whitespace = 0

  let l:i = a:start
  while l:i < a:end
    let l:char = a:chars[l:i]

    " trim leading whitespace
    if l:char =~# '\s'
      if !l:seen_non_whitespace
        let l:i += 1
        continue
      endif
    else
      let l:seen_non_whitespace = 1
    endif

    let l:width = strdisplaywidth(l:char)

    if l:char ==# "\<CR>" || l:char ==# "\<NL>"
      call add(l:lines, l:line)
      let l:line = ''
      let l:line_width = 0

      let l:i += 1
      continue
    elseif l:line_width + l:width > a:max_width
      call add(l:lines, l:line)
      let l:line = ''
      let l:line_width = 0
    endif

    let l:line .= l:char
    let l:line_width += l:width

    let l:i += 1
  endwhile

  return [l:lines, l:line, l:line_width]
endfunction
