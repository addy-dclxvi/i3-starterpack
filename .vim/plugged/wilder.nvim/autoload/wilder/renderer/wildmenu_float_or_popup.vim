function! wilder#renderer#wildmenu_float_or_popup#(opts) abort
  let l:state = wilder#renderer#wildmenu#prepare_state(a:opts)
  let l:state.active = 0
  let l:state.zindex = get(a:opts, 'zindex', 250)

  if a:opts.mode ==# 'float'
    let l:state.api = wilder#renderer#nvim_api#()
  else
    let l:state.api = wilder#renderer#vim_api#()
  endif

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

  let l:chunks = wilder#renderer#wildmenu#make_hl_chunks(
        \ a:state, &columns, a:ctx, a:result)

  if a:state.api.need_timer()
    call timer_start(0, {-> s:render_chunks(a:state, l:chunks)})
  else
    call s:render_chunks(a:state, l:chunks)
  endif
endfunction

function! s:render_chunks(state, chunks) abort
  if !a:state.active
    return
  endif

  call a:state.api.show()

  let a:state.columns = &columns

  let l:cmdheight = wilder#renderer#get_cmdheight()
  if a:state.cmdheight != l:cmdheight
    let l:row = &lines - l:cmdheight - 1
    call a:state.api.move(l:row, 0, 1, &columns)
    let a:state.cmdheight = l:cmdheight
  endif

  let l:text = ''
  for l:elem in a:chunks
    let l:text .= l:elem[0]
  endfor

  call a:state.api.delete_all_lines()
  call a:state.api.clear_all_highlights()
  call a:state.api.set_line(0, l:text)
  call a:state.api.set_firstline(1)

  let l:start = 0
  for l:elem in a:chunks
    let l:end = l:start + len(l:elem[0])

    if len(l:elem) > 1
      let l:hl = l:elem[1]
      call a:state.api.add_highlight(l:hl, 0, l:start, l:end)
    endif

    let l:start = l:end
  endfor

  call wilder#renderer#redraw(a:state.apply_incsearch_fix)
endfunction

function! s:pre_hook(state, ctx) abort
  call a:state.api.new({
        \ 'normal_highlight': a:state.highlights.default,
        \ 'zindex': a:state.zindex,
        \ })
  call a:state.api.show()

  let l:cmdheight = wilder#renderer#get_cmdheight()
  let l:row = &lines - l:cmdheight - 1
  call a:state.api.move(l:row, 0, 1, &columns)

  for l:Component in a:state.left + a:state.right
    call wilder#renderer#call_component_pre_hook(a:ctx, l:Component)
  endfor

  let a:state.active = 1
endfunction

function! s:post_hook(state, ctx) abort
  call a:state.api.hide()

  for l:Component in a:state.left + a:state.right
    call wilder#renderer#call_component_post_hook(a:ctx, l:Component)
  endfor

  let a:state.active = 0
endfunction
