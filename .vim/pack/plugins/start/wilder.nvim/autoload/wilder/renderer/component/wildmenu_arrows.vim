function! wilder#renderer#component#wildmenu_arrows#previous(args) abort
  let l:previous = get(a:args, 'previous', '< ')
  let l:hl = get(a:args, 'hl', 0)

  return {
        \ 'value': {ctx, result -> s:left(ctx, result, l:previous, l:hl)},
        \ 'len': strdisplaywidth(l:previous),
        \ }
endfunction

function! wilder#renderer#component#wildmenu_arrows#next(args) abort
  let l:previous = get(a:args, 'previous', '< ')
  let l:next = get(a:args, 'next', ' >')
  let l:hl = get(a:args, 'hl', 0)

  return {
        \ 'value': {ctx, result -> s:right(ctx, result, l:previous, l:next, l:hl)},
        \ 'len': strdisplaywidth(l:next),
        \ }
endfunction

function! s:left(ctx, result, previous, hl) abort
  let l:str = a:ctx.page[0] > 0 ? a:previous : ''

  if a:hl is 0
    return l:str
  endif

  return [l:str, a:hl]
endfunction

function! s:right(ctx, result, previous, next,  hl) abort
  let l:next_page_arrow = a:ctx.page[1] < len(a:result.value) - 1
        \ ? a:next
        \ : repeat(' ', strdisplaywidth(a:next))

  " add padding if previous arrow is empty
  let l:str = a:ctx.page[0] > 0
        \ ? ''
        \ : repeat(' ', strdisplaywidth(a:previous))
  let l:str .= l:next_page_arrow

  if a:hl is 0
    return l:str
  endif

  return [l:str, a:hl]
endfunction
