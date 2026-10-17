function! wilder#renderer#popupmenu_border_theme#(opts) abort
  let l:border_chars = get(a:opts, 'border', 'single')
  if type(l:border_chars) is v:t_string
    if l:border_chars ==# 'solid'
      let l:border_chars = ['█', '█', '█',
            \               '█',      '█',
            \               '█', '█', '█']
    elseif l:border_chars ==# 'rounded'
      let l:border_chars = ['╭', '─', '╮',
            \               '│',      '│',
            \               '╰', '─', '╯']
    elseif l:border_chars ==# 'double'
      let l:border_chars = ['╔', '═', '╗',
            \               '║',      '║',
            \               '╚', '═', '╝']
    else
      " single
      let l:border_chars = ['┌', '─', '┐',
            \               '│',      '│',
            \               '└', '─', '┘']
    endif
  endif

  let l:with_border = copy(a:opts)

  if !has_key(a:opts, 'highlights')
    let l:with_border.highlights = {}
  else
    let l:with_border.highlights = copy(a:opts.highlights)
  endif

  let l:top = get(a:opts, 'top', [])
  let l:with_border.top = wilder#renderer#popupmenu_border_theme#wrap_top_or_bottom(1, l:top, l:border_chars)

  let l:bottom = get(a:opts, 'bottom', [])
  let l:with_border.bottom = wilder#renderer#popupmenu_border_theme#wrap_top_or_bottom(0, l:bottom, l:border_chars)

  if has_key(a:opts, 'empty_message') &&
        \ a:opts.empty_message isnot 0 &&
        \ (!empty(l:border_chars[3]) || !empty(l:border_chars[4]))
    if type(a:opts.empty_message) is v:t_dict
      let l:with_border.empty_message = copy(a:opts.empty_message)
      let l:Value = a:opts.empty_message.value
      let l:with_border.empty_message.value = {ctx, result ->
            \ s:wrap_message(ctx, result, l:Value, l:border_chars, 'empty_message')}
    else
      let l:with_border.empty_message = {ctx, result ->
            \ s:wrap_message(ctx, result, a:opts.empty_message, l:border_chars, 'empty_message')}
    endif
  endif

  if !has_key(a:opts, 'error_message')
    let l:Error_message = wilder#renderer#component#popupmenu_error_message#()
  else
    let l:Error_message = a:opts.error_message
  endif

  let l:with_border.error_message = {ctx, error -> s:wrap_message(ctx, error, l:Error_message, l:border_chars, 'error')}

  if !has_key(a:opts, 'left') && !has_key(a:opts, 'right')
    let l:with_border.left = [' ']
    let l:with_border.right = [' ', wilder#popupmenu_scrollbar()]
  else
    let l:with_border.left = copy(get(a:opts, 'left', []))
    let l:with_border.right = copy(get(a:opts, 'right', []))
  endif

  if !has_key(l:with_border.highlights, 'border')
    let l:with_border.highlights.border = 'Normal'
  endif

  if !has_key(l:with_border.highlights, 'bottom_border')
    let l:with_border.highlights.bottom_border = l:with_border.highlights.border
  endif

  let l:border_hl = l:with_border.highlights.border

  if !empty(l:border_chars[3])
    call insert(l:with_border.left, [l:border_chars[3], l:border_hl])
  endif
  if !empty(l:border_chars[4])
    call add(l:with_border.right, [l:border_chars[4], l:border_hl])
  endif

  return l:with_border
endfunction

function! wilder#renderer#popupmenu_border_theme#wrap_top_or_bottom(is_top, lines, border_chars) abort
  let l:new_lines = []
  for l:Line in a:lines
    let l:New_line = s:wrap_with_border(l:Line, a:border_chars[3], a:border_chars[4])
    call add(l:new_lines, l:New_line)
  endfor

  if a:is_top
    if !empty(a:border_chars[0]) || !empty(a:border_chars[1]) || !empty(a:border_chars[2])
      call insert(l:new_lines, {ctx -> s:make_top_or_bottom_border(ctx, 1, a:border_chars)})
    endif
  elseif !empty(a:border_chars[5]) || !empty(a:border_chars[6]) || !empty(a:border_chars[7])
    call add(l:new_lines, {ctx -> s:make_top_or_bottom_border(ctx, 0, a:border_chars)})
  endif

  return l:new_lines
endfunction

function! s:wrap_with_border(line, left, right) abort
  if type(a:line) is v:t_dict
    return s:wrap_dict_with_border(a:line, a:left, a:right)
  endif

  return {ctx, result -> s:wrap_string_or_func_with_border(ctx, result, a:line, a:left, a:right)}
endfunction

function! s:wrap_dict_with_border(line, left, right) abort
  let l:Value = a:line.value
  let l:line = copy(a:line)
  let l:line.value = {ctx, result -> s:wrap_string_or_func_with_border(ctx, result, l:Value, a:left, a:right)}
  return l:line
endfunction

function! s:wrap_string_or_func_with_border(ctx, result, line, left, right) abort
  let l:width = a:ctx.width
  let l:width -= strdisplaywidth(a:left)
  let l:width -= strdisplaywidth(a:right)
  if l:width < 0
    let l:width = 0
  endif

  if type(a:line) is v:t_func
    let l:ctx = copy(a:ctx)
    let l:ctx.width = l:width
    let l:result = a:line(l:ctx, a:result)

    if empty(l:result)
      return l:result
    endif

    if type(l:result) is v:t_string
      let l:chunks = [[wilder#render#truncate_and_pad(l:width, l:result)]]
    else
      let l:chunks = l:result
    endif
  else
    if empty(a:line)
      return a:line
    endif

    let l:chunks = [[wilder#render#truncate_and_pad(l:width, a:line)]]
  endif

  let l:border_hl = a:ctx.highlights.border
  return [[a:left, l:border_hl]] + l:chunks + [[a:right, l:border_hl]]
endfunction

function! s:make_top_or_bottom_border(ctx, is_top, border_chars) abort
  let l:left = a:is_top ? a:border_chars[0] : a:border_chars[5]
  let l:middle = a:is_top ? a:border_chars[1] : a:border_chars[6]
  let l:right = a:is_top ? a:border_chars[2] : a:border_chars[7]

  let l:left_width = strdisplaywidth(l:left)
  let l:middle_width = strdisplaywidth(l:middle)
  let l:right_width = strdisplaywidth(l:right)

  let l:expected_middle_width = a:ctx.width - l:left_width - l:right_width
  let l:middle_repeat =  l:expected_middle_width / l:middle_width
  if l:middle_repeat < 0
    let l:middle_repeat = 0
  endif

  let l:middle_str = repeat(l:middle, l:middle_repeat)
  let l:actual_middle_width = strdisplaywidth(l:middle_str)
  if l:actual_middle_width < l:expected_middle_width
    let l:middle_chars = split(l:middle, '\zs')

    let l:i = 0
    for l:char in l:middle_chars
      let l:new_middle_width = l:actual_middle_width + strdisplaywidth(l:char)

      if l:new_middle_width > l:expected_middle_width
        break
      endif

      let l:middle_str .= l:char
      let l:actual_middle_width = l:new_middle_width
    endfor

    let l:middle_str .= repeat(' ', l:expected_middle_width - l:actual_middle_width)
  endif

  let l:border_hl = a:ctx.highlights.border
  let l:middle_hl = a:is_top ? l:border_hl : a:ctx.highlights.bottom_border

  return [[l:left, l:border_hl], [l:middle_str, l:middle_hl], [l:right, l:border_hl]]
endfunction

function! s:wrap_message(ctx, result, message, border_chars, hl_key) abort
  let l:left = a:border_chars[3]
  let l:right = a:border_chars[4]
  let l:left_width = strdisplaywidth(l:left)
  let l:right_width = strdisplaywidth(l:right)

  let l:min_width = a:ctx.min_width - l:left_width - l:right_width
  let l:max_width = a:ctx.max_width - l:left_width - l:right_width
  " min_height and max_height have already accounted for the top and bottom
  " lines, so we don't have to adjust them.
  let l:max_height = a:ctx.max_height
  let l:min_height = a:ctx.min_height

  let l:Message = a:message
  if type(l:Message) is v:t_func
    let l:ctx = copy(a:ctx)
    let l:ctx.min_width = l:min_width
    let l:ctx.max_width = l:max_width
    let l:ctx.min_height = l:min_height
    let l:ctx.max_height = l:max_height

    let l:Message = copy(a:message(l:ctx, a:result))
  endif

  if type(l:Message) is v:t_string
    let l:message = l:Message
    let l:message = wilder#render#truncate(l:max_width, l:message)
    let l:message .= repeat(' ', l:min_width - strdisplaywidth(l:message))

    let l:hl = get(a:ctx.highlights, a:hl_key)
    let l:Message = [[[l:message, l:hl]]]

    if l:min_height > 1
      let l:width = strdisplaywidth(l:message)
      let l:Message += repeat([[[repeat(' ', l:width)]]], l:min_height - 1)
    endif
  endif

  let l:border_hl = a:ctx.highlights.border
  if l:left_width && l:right_width
    return map(l:Message, {_, row -> [[l:left, l:border_hl]] + row + [[l:right, l:border_hl]]})
  endif

  if l:left_width
    return map(l:Message, {_, row -> [[l:left, l:border_hl]] + row})
  endif

  if l:right_width
    return map(l:Message, {_, row -> row + [[l:right, l:border_hl]]})
  endif

  return l:Message
endfunction
