function! wilder#renderer#component#wildmenu_index#(args) abort
  let l:hl = get(a:args, 'hl', 0)
  return {
        \ 'value': {ctx, result -> s:value(ctx, result, l:hl)},
        \ 'len': {ctx, result -> len(len(result.value)) * 2 + 1 + 2},
        \ 'hl': get(a:args, 'hl', ''),
        \ }
endfunction

function! s:value(ctx, result, hl) abort
  let l:total = len(a:result.value) == 0 ? '-' : len(a:result.value)
  let l:displaywidth = len(l:total)
  let l:selected = a:ctx.selected == -1 ? '-' : a:ctx.selected + 1

  let l:result = ' '
  let l:result .= repeat(' ', l:displaywidth - len(l:selected)) . l:selected
  let l:result .= '/' . l:total
  let l:result .= ' '

  if a:hl is 0
    return l:result
  endif

  return [l:result, a:hl]
endfunction
