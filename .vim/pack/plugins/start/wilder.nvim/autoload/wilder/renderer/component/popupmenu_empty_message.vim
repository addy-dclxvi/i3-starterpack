function! wilder#renderer#component#popupmenu_empty_message#(opts) abort
  let l:Message = get(a:opts, 'message', ' No candidates found ')
  if type(l:Message) is v:t_string
    let l:message = l:Message
    let l:Message = {-> l:message}
  endif

  let l:align = get(a:opts, 'align', 'middle-middle')
  let l:align_split = split(l:align, '-')
  let l:vertical = l:align_split[0]
  let l:horizontal = l:align_split[1]

  let l:state = {
        \ 'message': l:Message,
        \ 'vertical': l:vertical,
        \ 'horizontal': l:horizontal,
        \ }

  return {ctx, result -> s:empty_message(l:state, ctx, result)}
endfunction

function! s:empty_message(state, ctx, result) abort
  let l:min_width = a:ctx.min_width
  let l:max_width = a:ctx.max_width
  let l:min_height = a:ctx.min_height

  let l:hl = a:ctx.highlights.empty_message

  let l:message = a:state.message(a:ctx, a:result)
  if type(l:message) is v:t_string
    let l:chunks = [[l:message, l:hl]]
  else
    let l:chunks = l:message
  endif

  let l:remaining_width = l:min_width - wilder#render#chunks_displaywidth(l:chunks)

  if l:remaining_width > 0
    if a:state.horizontal ==# 'middle'
      let l:chunks = [[repeat(' ', l:remaining_width / 2), l:hl]] + l:chunks
      let l:chunks += [[repeat(' ', (l:remaining_width + 1) / 2), l:hl]]
    elseif a:state.horizontal ==# 'left'
      let l:chunks += [[repeat(' ', l:remaining_width), l:hl]]
    else
      " right
      let l:chunks = [[repeat(' ', l:remaining_width), l:hl]] + l:chunks
    endif
  endif

  let l:rows = [l:chunks]

  if l:min_height > 1
    " + 1 for the added space.
    let l:width = wilder#render#chunks_displaywidth(l:chunks)
    let l:padding_rows = [[repeat(' ', l:width), l:hl]]
    let l:min_height_rows = repeat([l:padding_rows], l:min_height - 1)

    if a:state.vertical ==# 'middle'
      let l:rows = repeat([l:padding_rows], (l:min_height - 1) / 2) + l:rows
      let l:rows += repeat([l:padding_rows], l:min_height / 2)
    elseif a:state.vertical ==# 'bottom'
      let l:rows = repeat([l:padding_rows], l:min_height - 1) + l:rows
    else
      " bottom
      let l:rows += repeat([l:padding_rows], l:min_height - 1)
    endif
  endif

  return l:rows
endfunction
