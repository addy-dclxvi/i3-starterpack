function! wilder#renderer#wildmenu#prepare_state(opts) abort
  let l:highlights = copy(get(a:opts, 'highlights', {}))
  let l:state = {
        \ 'highlights': extend(l:highlights, {
        \   'default': get(a:opts, 'hl', 'StatusLine'),
        \   'selected': get(a:opts, 'selected_hl', 'WildMenu'),
        \   'error': get(a:opts, 'error_hl', 'ErrorMsg'),
        \ }, 'keep'),
        \ 'separator': wilder#render#to_printable(get(a:opts, 'separator', '  ')),
        \ 'ellipsis': wilder#render#to_printable(get(a:opts, 'ellipsis', '...')),
        \ 'apply_incsearch_fix': get(a:opts, 'apply_incsearch_fix', has('nvim') && !has('nvim-0.5.1')),
        \
        \ 'page': [-1, -1],
        \ 'columns': -1,
        \ 'cmdheight': -1,
        \ 'draw_cache': wilder#cache#cache(),
        \ 'highlight_cache': wilder#cache#cache(),
        \ 'run_id': -1,
        \ }

  if !has_key(a:opts, 'left') && !has_key(a:opts, 'right')
    let l:state.left = [wilder#previous_arrow()]
    let l:state.right = [wilder#next_arrow()]
  else
    let l:state.left = get(a:opts, 'left', [])
    let l:state.right = get(a:opts, 'right', [])
  endif

  if !has_key(l:state.highlights, 'separator')
    let l:state.highlights.separator =
          \ get(a:opts, 'separator_hl', l:state.highlights.default)
  endif

  if !has_key(l:state.highlights, 'accent')
    let l:state.highlights.accent =
          \ wilder#hl_with_attr(
          \ 'WilderWildmenuAccent',
          \ l:state.highlights.default,
          \'underline', 'bold')
  endif

  if !has_key(l:state.highlights, 'selected_accent')
    let l:state.highlights.selected_accent =
          \ wilder#hl_with_attr(
          \ 'WilderWildmenuSelectedAccent',
          \ l:state.highlights.selected,
          \ 'underline', 'bold')
  endif

  if has_key(a:opts, 'highlighter')
    let l:Highlighter = a:opts.highlighter
  elseif has_key(a:opts, 'apply_highlights')
    let l:Highlighter = a:opts.apply_highlights
  else
    let l:Highlighter = 0
  endif

  if type(l:Highlighter) is v:t_list
    let l:Highlighter = wilder#highlighter#apply_first(l:Highlighter)
  endif

  let l:state.highlighter = l:Highlighter

  return l:state
endfunction

function! wilder#renderer#wildmenu#make_hl_chunks(state, width, ctx, result) abort
  if a:state.run_id != a:ctx.run_id
    call a:state.draw_cache.clear()
    call a:state.highlight_cache.clear()
  endif

  let a:state.run_id = a:ctx.run_id

  if a:ctx.clear_previous
    let a:state.page = [-1, -1]
  endif

  if a:state.page != [-1, -1]
    if a:state.page[0] > len(a:result.value)
      let a:state.page = [-1, -1]
    elseif a:state.page[1] > len(a:result.value)
      let a:state.page[1] = len(a:result.value) - 1
    endif
  endif

  let l:space_used = 0
  for l:Component in a:state.left + a:state.right
    let l:space_used += wilder#renderer#wildmenu#get_item_len(l:Component, a:ctx, a:result)
  endfor

  let a:ctx.space = a:width - l:space_used
  let a:ctx.page = a:state.page
  let a:ctx.separator = a:state.separator
  let a:ctx.ellipsis = a:state.ellipsis

  let l:page = s:make_page(a:state, a:ctx, a:result)
  let a:ctx.page = l:page
  let a:state.page = l:page

  let a:ctx.highlights = a:state.highlights

  return s:make_hl_chunks(a:state, a:ctx, a:result,)
endfunction

function! wilder#renderer#wildmenu#get_item_len(item, ctx, result) abort
  let l:Item = a:item

  if type(l:Item) is v:t_dict
    if has_key(l:Item, 'len')
      if type(l:Item.len) is v:t_func
        return l:Item.len(a:ctx, a:result)
      endif

      return l:Item.len
    endif

    let l:Item = l:Item.value
  endif

  if type(l:Item) is v:t_func
    let l:Item = l:Item(a:ctx, a:result)
  endif

  if type(l:Item) is v:t_list
    if empty(l:Item)
      return 0
    endif

    if type(l:Item[0]) is v:t_string
      return strdisplaywidth(l:Item[0])
    endif

    return wilder#render#chunks_displaywidth(l:Item)
  endif

  return strdisplaywidth(l:Item)
endfunction

function! s:make_page(state, ctx, result) abort
  if empty(a:result.value)
    return [-1, -1]
  endif

  let l:page = a:ctx.page
  let l:selected = a:ctx.selected

  " if selected is within old page
  if l:page != [-1, -1] && l:selected != -1 && l:selected >= l:page[0] && l:selected <= l:page[1]
    " check if page_start to selected still fits within space
    " space might have changed due to resizing or due to custom draw functions
    let l:selected = a:ctx.selected

    let l:i = l:page[0]
    let l:separator_width = strdisplaywidth(a:ctx.separator)
    let l:width = strdisplaywidth(s:draw_candidate(a:state, a:ctx, a:result, l:i))
    let l:i += 1

    while l:i <= l:page[1]
      let l:width += l:separator_width
      let l:width += strdisplaywidth(s:draw_candidate(a:state, a:ctx, a:result, l:i))

      " cannot fit in current page
      if l:width > a:ctx.space
        break
      endif

      let l:i += 1
    endwhile

    if l:width <= a:ctx.space
      return l:page
    endif

    " continue below otherwise
  endif

  let l:selected = l:selected == -1 ? 0 : l:selected

  if l:page == [-1, -1]
    return s:make_page_from_start(a:state, a:ctx, a:result, l:selected)
  endif

  if a:ctx.direction < 0
    return s:make_page_from_end(a:state, a:ctx, a:result, l:selected)
  endif

  return s:make_page_from_start(a:state, a:ctx, a:result, l:selected)
endfunction

function! s:draw_candidate(state, ctx, result, i) abort
  let l:use_cache = a:ctx.selected == a:i
  if l:use_cache && a:state.draw_cache.has_key(a:i)
    return a:state.draw_cache.get(a:i)
  endif

  let l:x = wilder#render#draw_candidate(a:ctx, a:result, a:i)

  if l:use_cache
    call a:state.draw_cache.set(a:i, l:x)
  endif

  return l:x
endfunction

function! s:make_page_from_start(state, ctx, result, start) abort
  let l:space = a:ctx.space
  let l:start = a:start
  let l:end = l:start

  let l:width = strdisplaywidth(s:draw_candidate(a:state, a:ctx, a:result, l:start))
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(a:ctx.separator)

  while 1
    if l:end + 1 >= len(a:result.value)
      break
    endif

    let l:width = strdisplaywidth(s:draw_candidate(a:state, a:ctx, a:result, l:end + 1))

    if l:width + l:separator_width > l:space
      break
    endif

    let l:space -= l:width + l:separator_width
    let l:end += 1
  endwhile

  return [l:start, l:end]
endfunction

function! s:make_page_from_end(state, ctx, result, end) abort
  let l:space = a:ctx.space
  let l:end = a:end
  let l:start = l:end

  let l:width = strdisplaywidth(s:draw_candidate(a:state, a:ctx, a:result, l:start))
  let l:space = l:space - l:width
  let l:separator_width = strdisplaywidth(a:ctx.separator)

  while 1
    if l:start - 1 < 0
      break
    endif

    let l:width = strdisplaywidth(s:draw_candidate(a:state, a:ctx, a:result, l:start - 1))

    if l:width + l:separator_width > l:space
      break
    endif

    let l:space -= l:width + l:separator_width
    let l:start -= 1
  endwhile

  " moving left from page [5,10] ends in [0,4]
  " but there might be leftover space, so we increase l:end to fill up the
  " space e.g. to [0,6]
  while 1
    if l:end + 1 >= len(a:result.value)
      break
    endif

    let l:width = strdisplaywidth(s:draw_candidate(a:state, a:ctx, a:result, l:end + 1))

    if l:width + l:separator_width > l:space
      break
    endif

    let l:space -= l:width + l:separator_width
    let l:end += 1
  endwhile

  return [l:start, l:end]
endfunction

function! s:make_hl_chunks(state, ctx, result) abort
  let l:chunks = []
  for l:Item in a:state.left
    let l:chunks += wilder#renderer#wildmenu#draw_item(l:Item, a:ctx, a:result)
  endfor

  if has_key(a:ctx, 'error')
    let l:chunks += s:draw_error(a:ctx.highlights.error, a:ctx, a:ctx.error)
  else
    let l:chunks += s:draw_candidates(a:state, a:ctx, a:result)
  endif

  for l:Item in a:state.right
    let l:chunks += wilder#renderer#wildmenu#draw_item(l:Item, a:ctx, a:result)
  endfor

  return l:chunks
  "return wilder#render#normalise_chunks(l:default_hl, l:chunks)
endfunction

function! wilder#renderer#wildmenu#draw_item(item, ctx, result) abort
  let l:Item = a:item

  if type(l:Item) is v:t_dict
    let l:Item = l:Item.value
  endif

  if type(l:Item) is v:t_func
    let l:Item = l:Item(a:ctx, a:result)
  endif

  if type(l:Item) is v:t_string
    return [[l:Item, a:ctx.highlights.default]]
  endif

  " v:t_list
  if empty(l:Item)
    return []
  endif

  " highlight chunk
  if type(l:Item[0]) is v:t_string
    return [l:Item]
  endif

  " list  of highlight chunks
  return l:Item
endfunction

function! s:draw_error(hl, ctx, error) abort
  let l:space = a:ctx.space
  let l:error = wilder#render#to_printable(a:error)

  if strdisplaywidth(l:error) > a:ctx.space
    let l:ellipsis = wilder#render#to_printable(a:ctx.ellipsis)
    let l:space_minus_ellipsis = l:space - strdisplaywidth(l:ellipsis)

    let l:error = wilder#render#truncate(l:space_minus_ellipsis, l:error)

    let l:error = l:error . l:ellipsis
  endif

  return [[l:error, a:hl], [repeat(' ', l:space - strdisplaywidth(l:error))]]
endfunction

function! s:draw_candidates(state, ctx, result) abort
  let l:selected = a:ctx.selected
  let l:space = a:ctx.space
  let l:page = a:ctx.page
  let l:separator = a:ctx.separator

  if l:page == [-1, -1]
    return [[repeat(' ', l:space), a:ctx.highlights['default']]]
  endif

  let l:start = l:page[0]
  let l:end = l:page[1]

  let l:xs = []
  let l:len = l:end - l:start + 1
  let l:data = get(a:result, 'data', {})
  let l:Highlighter = a:state.highlighter

  let l:i = 0
  while l:i < l:len
    let l:current = l:i + l:start
    let l:x = s:draw_candidate(a:state, a:ctx, a:result, l:current)

    if !a:state.highlight_cache.has_key(l:x) &&
          \ l:Highlighter isnot 0
      let l:highlight = l:Highlighter(a:ctx, l:x, l:data)

      if l:highlight isnot 0
        call a:state.highlight_cache.set(l:x, l:highlight)
      endif
    endif

    call add(l:xs, l:x)
    let l:i += 1
  endwhile

  " only 1 x, possible that it exceeds l:space
  if l:len == 1
    let l:x = l:xs[0]
    let l:is_selected = l:selected == 0

    if strdisplaywidth(l:x) > l:space
      let l:res = []

      let l:ellipsis = a:ctx.ellipsis
      let l:space_minus_ellipsis = l:space - strdisplaywidth(l:ellipsis)

      if a:state.highlight_cache.has_key(l:x)
        let l:chunks = wilder#render#spans_to_chunks(
              \ l:x,
              \ a:state.highlight_cache.get(l:x),
              \ l:is_selected,
              \ a:ctx.highlights)
        let l:res += wilder#render#truncate_chunks(l:space_minus_ellipsis, l:chunks)
      else
        let l:x = wilder#render#truncate(l:space_minus_ellipsis, l:x)
        call add(l:res, [l:x, a:ctx.highlights[l:is_selected ? 'selected' : 'default']])
      endif

      call add(l:res, [l:ellipsis, a:ctx.highlights['default']])
      let l:padding = repeat(' ', l:space - wilder#render#chunks_displaywidth(l:res))
      call add(l:res, [l:padding, a:ctx.highlights['default']])
      return l:res
    endif
  endif

  let l:current = l:start
  let l:res = [['']]
  let l:width = 0

  let l:i = 0
  while l:i < l:len
    if l:i > 0
      call add(l:res, [l:separator, a:ctx.highlights.separator])
      let l:width += strdisplaywidth(l:separator)
    endif

    let l:x = l:xs[l:i]
    let l:is_selected = l:selected == l:i + l:start

    if a:state.highlight_cache.has_key(l:x)
      let l:chunks = wilder#render#spans_to_chunks(
            \ l:x,
            \ a:state.highlight_cache.get(l:x),
            \ l:is_selected,
            \ a:ctx.highlights)
      let l:res += chunks
    else
      call add(l:res, [l:x, a:ctx.highlights[l:is_selected ? 'selected' : 'default']])
    endif

    let l:width += strdisplaywidth(l:x)
    let l:i += 1
  endwhile

  call add(l:res, [repeat(' ', l:space - l:width)])
  return l:res
endfunction
