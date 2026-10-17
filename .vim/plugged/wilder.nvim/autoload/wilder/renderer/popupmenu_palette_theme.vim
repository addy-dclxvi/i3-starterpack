function! wilder#renderer#popupmenu_palette_theme#(opts) abort
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

  if has_key(a:opts, 'prompt_border')
    let l:prompt_border_chars = a:opts.prompt_border
  elseif !has_key(a:opts, 'border')
    let l:prompt_border_chars = ['├', '─', '┤']
  elseif has_key(a:opts, 'border') &&
        \ type(a:opts.border) is v:t_string
    if a:opts.border ==# 'solid'
      let l:prompt_border_chars = ['█', '█', '█']
    elseif a:opts.border ==# 'double'
      let l:prompt_border_chars = ['╠', '═', '╣']
    else
      " single or rounded
      let l:prompt_border_chars = ['├', '─', '┤']
    endif
  else
    let l:prompt_border_chars = ['', '', '']
  endif

  let l:prompt_position = get(a:opts, 'prompt_position', 'top')

  let l:opts_without_prompt = copy(a:opts)

  if l:prompt_position ==# 'top'
    let l:opts_without_prompt.top = get(a:opts, 'top', [])
    let l:opts_without_prompt.border = l:prompt_border_chars[:2] + l:border_chars[3:]
  else
    let l:opts_without_prompt.bottom = get(a:opts, 'bottom', [])
    let l:opts_without_prompt.border = l:border_chars[0:4] + l:prompt_border_chars[:2]
  endif

  if !has_key(a:opts, 'max_height') && !has_key(a:opts, 'min_height')
    let l:opts_without_prompt.min_height = 0
    let l:opts_without_prompt.max_height = '75%'
  endif

  if !has_key(a:opts, 'max_width') && !has_key(a:opts, 'min_width')
    let l:opts_without_prompt.max_width = '75%'
    let l:opts_without_prompt.min_width = '75%'
  elseif has_key(a:opts, 'max_width') && !has_key(a:opts, 'min_width')
    let l:opts_without_prompt.min_width = a:opts.max_width
  elseif has_key(a:opts, 'min_width') && !has_key(a:opts, 'max_width') &&
        \ a:opts.min_width != 0
    let l:opts_without_prompt.max_width = a:opts.min_width
  endif

  if !has_key(a:opts, 'empty_message')
    let l:opts_without_prompt.empty_message = wilder#popupmenu_empty_message()
  endif

  let l:hls = copy(get(l:opts_without_prompt, 'highlights', {}))
  let l:opts_without_prompt.highlights = l:hls

  if !has_key(l:hls, 'default')
    let l:hls.default = 'Normal'
  endif

  if !has_key(l:hls, 'selected')
    let l:hls.selected = 'Visual'
  endif

  let l:opts = wilder#popupmenu_border_theme(l:opts_without_prompt)
  " restore original border chars
  let l:opts.border = copy(l:border_chars)

  let l:prompt_hl = get(l:hls, 'prompt', l:hls.default)
  let l:prompt_state = {
        \ 'hl': l:prompt_hl,
        \ 'cursor_hl': get(l:hls, 'prompt_cursor', 'Cursor'),
        \ 'cursor_check_interval': get(l:opts, 'cursor_check_interval', 16),
        \ 'timer': -1,
        \ 'cmdpos': -1,
        \ 'cached_cmdline': '',
        \ 'cached_cmdline_data': [],
        \ 'previous_cursor_pos': 0,
        \ 'previous_start': -1,
        \ 'previous_end': -1,
        \ }

  if l:prompt_position ==# 'top'
    let l:top = [s:prompt_component(l:prompt_state)]
    let l:top = wilder#renderer#popupmenu_border_theme#wrap_top_or_bottom(1, l:top, l:border_chars)
    let l:opts.top = l:top + l:opts.top
  else
    let l:bottom = [s:prompt_component(l:prompt_state)]
    let l:bottom = wilder#renderer#popupmenu_border_theme#wrap_top_or_bottom(0, l:bottom, l:border_chars)
    let l:opts.bottom = l:opts.bottom + l:bottom
  endif

  let l:Margin = get(l:opts, 'margin', 'auto')
  let l:opts.position = s:get_position_func(l:Margin, l:prompt_position ==# 'top')

  return l:opts
endfunction

function! s:prompt_component(state) abort
  return {
        \ 'value': {ctx, result -> s:prompt(a:state, ctx, result)},
        \ 'pre_hook': {-> s:prompt_pre_hook(a:state)},
        \ 'post_hook': {-> s:prompt_post_hook(a:state)},
        \ 'pre_draw': {-> s:prompt_pre_draw(a:state)},
        \ }
endfunction

function! s:get_cmdline_data(state, cmdline) abort
  if a:state.cached_cmdline ==# a:cmdline
    return a:state.cached_cmdline_data
  endif

  let l:cmdline_chars = split(a:cmdline, '\zs')
  let l:cmdline_data = []

  let l:byte_pos = 0
  let l:displaywidth_pos = 0

  let l:i = 0
  while l:i < len(l:cmdline_chars)
    let l:char = l:cmdline_chars[l:i]

    " [char, byte_len, strdisplaywidth, byte_pos, displaywidth_pos]
    let l:byte_len = len(l:char)
    let l:displaywidth = strdisplaywidth(l:char)
    let l:data = [l:char, l:byte_len, l:displaywidth, l:byte_pos, l:displaywidth_pos]
    call add(l:cmdline_data, l:data)

    let l:byte_pos += l:byte_len
    let l:displaywidth_pos += l:displaywidth

    let l:i += 1
  endwhile

  let a:state.cached_cmdline = a:cmdline
  let a:state.cached_cmdline_data = l:cmdline_data

  return a:state.cached_cmdline_data
endfunction

function! s:prompt_pre_draw(state) abort
  return a:state.cached_cmdline !=# getcmdline() ||
        \ a:state.cmdpos != getcmdpos()
endfunction

function! s:prompt(state, ctx, result) abort
  let l:cmdline = getcmdline()
  let a:state.cmdpos = getcmdpos()
  let l:cmdline_data = s:get_cmdline_data(a:state, l:cmdline)
  let l:hl = a:state.hl

  " cmdpos includes the prompt character
  let l:cursor_pos = a:state.cmdpos - 1
  " -1 as the prompt char is always drawn
  let l:max_displaywidth = a:ctx.width - 1
  let l:displaywidth = 0
  let l:previous_start = len(l:cmdline)
  let l:previous_end = 0

  " cursor is at end of cmdline
  if l:cursor_pos >= len(l:cmdline)
    " -1 for the cursor
    let l:max_displaywidth -= 1
    let l:displaywidth = 0
    let l:prompt_str = ''

    " draw entire cmdline starting from the back
    let l:i = len(l:cmdline_data) - 1
    while l:i >= 0
      " [char, byte_len, strdisplaywidth, byte_pos, displaywidth_pos]
      let l:data = l:cmdline_data[l:i]

      if l:displaywidth + l:data[2] > l:max_displaywidth
        break
      endif

      let l:displaywidth += l:data[2]
      let l:prompt_str = l:data[0] . l:prompt_str
      let l:previous_start = l:data[3]

      let l:i -= 1
    endwhile

    let l:previous_end = len(l:cmdline)
    let l:chunks = [[l:prompt_str, l:hl], [' ', a:state.cursor_hl]]
  else
    let l:chunks = v:null

    " check if the cursor fits within previous_start and previous_end
    " if it does, draw the prompt with the same bounds
    if strdisplaywidth(l:cmdline) <= l:max_displaywidth ||
          \ (l:cursor_pos >= a:state.previous_start &&
          \ l:cursor_pos < a:state.previous_end)
      let l:start_seen = 0
      let l:cursor_char = ''
      let l:before_cursor_str = ''
      let l:after_cursor_str = ''

      let l:i = 0
      while l:i < len(l:cmdline_data)
        " [char, byte_len, strdisplaywidth, byte_pos, displaywidth_pos]
        let l:data = l:cmdline_data[l:i]

        if l:data[3] < a:state.previous_start
          let l:i += 1
          continue
        endif

        if !l:start_seen
          let l:start_seen = 1
          let l:previous_start = l:data[3]
        endif

        if l:data[3] > a:state.previous_end
          break
        endif

        if l:displaywidth + l:data[2] > l:max_displaywidth
          break
        endif

        let l:displaywidth += l:data[2]

        if l:data[3] == l:cursor_pos
          let l:cursor_char = l:data[0]
        elseif l:data[3] < l:cursor_pos
          let l:before_cursor_str .= l:data[0]
        else
          let l:after_cursor_str .= l:data[0]
        endif

        let l:previous_end = l:data[1] + l:data[3]

        let l:i += 1
      endwhile

      " max_displaywidth reached but cursor is not inside bounds
      if l:cursor_char !=# ''
        let l:chunks = [[l:before_cursor_str, l:hl], [l:cursor_char, a:state.cursor_hl], [l:after_cursor_str, l:hl]]
      endif
    endif

    " cursor is not within old bounds, draw new bounds with cursor starting
    " at the front or end depending on which direction it moved
    if l:chunks is v:null
      let l:displaywidth = 0

      if l:cursor_pos < a:state.previous_cursor_pos
        " cursor at start
        let l:cursor_char = ''
        let l:prompt_str = ''

        let l:i = 0
        while l:i < len(l:cmdline_data)
          " [char, byte_len, strdisplaywidth, byte_pos, displaywidth_pos]
          let l:data = l:cmdline_data[l:i]

          if l:data[3] < l:cursor_pos
            let l:i += 1
            continue
          endif

          if l:displaywidth + l:data[2] > l:max_displaywidth
            break
          endif

          let l:displaywidth += l:data[2]

          if l:data[3] == l:cursor_pos
            let l:previous_start = l:data[3]
            let l:cursor_char = l:data[0]
          else
            let l:prompt_str .= l:data[0]
          endif

          let l:previous_end = l:data[3] + l:data[1]

          let l:i += 1
        endwhile

        let l:chunks = [[l:cursor_char, a:state.cursor_hl], [l:prompt_str, l:hl]]
      else
        " cursor at end
        let l:cursor_char = ''
        let l:prompt_str = ''

        let l:i = len(l:cmdline_data) - 1
        while l:i >= 0
          " [char, byte_len, strdisplaywidth, byte_pos, displaywidth_pos]
          let l:data = l:cmdline_data[l:i]

          if l:data[3] > l:cursor_pos
            let l:i -= 1
            continue
          endif

          if l:displaywidth + l:data[2] > l:max_displaywidth
            break
          endif

          let l:displaywidth += l:data[2]

          if l:data[3] == l:cursor_pos
            let l:previous_end = l:data[3]
            let l:cursor_char = l:data[0]
          else
            let l:prompt_str = l:data[0] . l:prompt_str
          endif

          let l:previous_start = l:data[3] + l:data[1]

          let l:i -= 1
        endwhile

        let l:chunks = [[l:prompt_str, l:hl], [l:cursor_char, a:state.cursor_hl]]
      endif
    endif
  endif

  " if there is space leftover, add characters depending on the direction
  " which the cursor moved
  if l:displaywidth < l:max_displaywidth
    let l:str = ''

    " cursor moved left, add characters to the end
    if l:cursor_pos < a:state.previous_cursor_pos
      let l:i = 0
      while l:i < len(l:cmdline_data)
        " [char, byte_len, strdisplaywidth, byte_pos, displaywidth_pos]
        let l:data = l:cmdline_data[l:i]

        if l:data[3] < l:previous_end
          let l:i += 1
          continue
        endif

        if l:displaywidth + l:data[2] > l:max_displaywidth
          break
        endif

        let l:displaywidth += l:data[2]
        let l:str .= l:data[0]
        let l:previous_end = l:data[1] + l:data[3]

        let l:i += 1
      endwhile

      call add(l:chunks, [l:str, l:hl])
    else
      " cursor moved right, add characters to the start
      let l:i = len(l:cmdline_data) - 1
      while l:i >= 0
        " [char, byte_len, strdisplaywidth, byte_pos, displaywidth_pos]
        let l:data = l:cmdline_data[l:i]

        if l:data[3] >= l:previous_start
          let l:i -= 1
          continue
        endif

        if l:displaywidth + l:data[2] > l:max_displaywidth
          break
        endif

        let l:displaywidth += l:data[2]
        let l:str = l:data[0] . l:str
        let l:previous_start = l:data[3]

        let l:i -= 1
      endwhile

      call insert(l:chunks, [l:str, l:hl], 0)
    endif
  endif

  " add padding for the rest of the leftover space
  if l:displaywidth < l:max_displaywidth
    call add(l:chunks, [repeat(' ', l:max_displaywidth - l:displaywidth), l:hl])
  endif

  call insert(l:chunks, [getcmdtype(), l:hl], 0)

  let a:state.previous_start = l:previous_start
  let a:state.previous_end = l:previous_end
  let a:state.previous_cursor_pos = l:cursor_pos

  return l:chunks
endfunction

function! s:prompt_pre_hook(state) abort
  call timer_stop(a:state.timer)

  let a:state.cmdpos = -1
  let a:state.previous_start = -1
  let a:state.previous_end = -1

  let a:state.timer = timer_start(a:state.cursor_check_interval, {-> s:prompt_update_cursor(a:state)}, {'repeat': -1})
endfunction

function! s:prompt_post_hook(state) abort
  call timer_stop(a:state.timer)
endfunction

function! s:prompt_update_cursor(state) abort
  let l:cmdpos = getcmdpos()

  if a:state.cmdpos != l:cmdpos
    call wilder#main#draw()
  endif
endfunction

function! s:get_position_func(margin, is_top) abort
  if type(a:margin) is v:t_number
    if a:is_top
      return {ctx, pos, dimensions -> [a:margin, (&columns - dimensions.width) / 2]}
    else
      return {ctx, pos, dimensions -> [&lines - 1 - dimensions.height - a:margin, (&columns - dimensions.width) / 2]}
    endif
  endif

  if type(a:margin) is v:t_string
    let l:matches = matchlist(a:margin, '^\(\d\+%\)$')
    if len(l:matches) >= 2
      let l:percent = 0.01 * str2nr(l:matches[1])
      if l:percent > 1.0
        let l:percent = 1
      endif

      if a:is_top
        return {ctx, pos, dimensions -> [float2nr(l:percent * (&lines - 1)), (&columns - dimensions.width) / 2]}
      else
        return {ctx, pos, dimensions -> [&lines - 1 - dimensions.height - float2nr(l:percent * (&lines - 1)), (&columns - dimensions.width) / 2]}
      endif
    endif
  endif

  " default to center of screen
  return {ctx, pos, dimensions -> s:get_middle_position(ctx, dimensions, a:is_top)}
endfunction

function! s:get_middle_position(ctx, dimensions, is_top) abort
  " Use max_height so the prompt does not move around the screen when height
  " of the candidates changes
  if a:is_top
    let l:row = (&lines - 1 - a:dimensions.max_height) / 2
  else
    let l:row = (&lines - 1 - a:dimensions.max_height) / 2 + a:dimensions.max_height - a:dimensions.height
  endif

  let l:col = (&columns - a:dimensions.width) / 2

  return [l:row, l:col]
endfunction
