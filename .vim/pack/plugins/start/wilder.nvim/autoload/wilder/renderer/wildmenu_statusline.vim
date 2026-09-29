function! wilder#renderer#wildmenu_statusline#(opts) abort
  let l:state = wilder#renderer#wildmenu#prepare_state(a:opts)

  return {
        \ 'render': {ctx, result -> s:render(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:render(state, ctx, result) abort
  if !a:ctx.done &&
        \ !wilder#renderer#pre_draw(a:state.left + a:state.right, a:ctx, a:result)
    return
  endif

  let l:width = &laststatus == 3 ? &columns : winwidth(0)
  let l:chunks = wilder#renderer#wildmenu#make_hl_chunks(
        \ a:state, l:width, a:ctx, a:result)

  call s:render_chunks(l:chunks, a:state.highlights['default'], a:state.apply_incsearch_fix)
endfunction

function! s:render_chunks(chunks, hl, apply_incsearch_fix) abort
  let l:statusline = ''
  let g:_wilder_xs = map(copy(a:chunks), {_, x -> x[0]})

  let l:i = 0
  while l:i < len(a:chunks)
    let l:statusline .= '%#' . get(a:chunks[l:i], 1, a:hl) . '#'

    if stridx(g:_wilder_xs[l:i], '%') >= 0
      " prevent leading space from being truncated
      if g:_wilder_xs[l:i][0] ==# ' '
        let l:statusline .= ' '
        let g:_wilder_xs[l:i] = g:_wilder_xs[l:i][1:]
      endif

      let l:statusline .= '%{g:_wilder_xs[' . string(l:i) . ']}'
    else
      let l:statusline .= g:_wilder_xs[l:i]
    endif

    let l:i += 1
  endwhile

  call setwinvar(0, '&statusline', l:statusline)

  call wilder#renderer#redrawstatus(a:apply_incsearch_fix)
endfunction

function! s:pre_hook(state, ctx) abort
  let a:state.old_laststatus = &laststatus
  let &laststatus = &laststatus == 3 ? 3 : 2
  let a:state.old_statusline = &statusline

  for l:Component in a:state.left + a:state.right
    call wilder#renderer#call_component_pre_hook(a:ctx, l:Component)
  endfor
endfunction

function! s:post_hook(state, ctx) abort
  let &laststatus = a:state.old_laststatus
  let &statusline = a:state.old_statusline

  if getcmdtype() !=# '/' && getcmdtype() !=# '?'
    redrawstatus
  else
    " Redraw from timer to avoid hlsearch flashing.
    call timer_start(0, {-> execute('redrawstatus')})
  endif

  for l:Component in a:state.left + a:state.right
    call wilder#renderer#call_component_post_hook(a:ctx, l:Component)
  endfor
endfunction
