function! wilder#renderer#component#popupmenu_spinner#(opts) abort
  let l:frames = get(a:opts, 'frames', ['-', '\', '|', '/'])
  if type(l:frames) is v:t_string
    let l:frames = split(l:frames, '\zs')
  endif

  let l:delay = get(a:opts, 'delay', 100)

  let l:Spinner = wilder#renderer#component#spinner#({
        \ 'num_frames': len(l:frames),
        \ 'delay': l:delay,
        \ 'interval': get(a:opts, 'interval', 100),
        \ })

  let l:first_draw_delay = get(a:opts, 'first_draw_delay', 10)
  if l:first_draw_delay > l:delay
    let l:first_draw_delay = l:delay
  endif

  let l:state = {
        \ 'frames': l:frames,
        \ 'done': get(a:opts, 'done', ' '),
        \ 'spinner': l:Spinner,
        \ 'align': get(a:opts, 'align', 'bottom'),
        \ 'first_draw_delay': l:first_draw_delay,
        \ 'timer': -1,
        \ 'run_id': -1,
        \ }

  if has_key(a:opts, 'hl')
    let l:state.hl = a:opts.hl
  endif

  return {
        \ 'value': {ctx, result -> s:spinner(l:state, ctx, result)},
        \ 'pre_draw': {ctx, result -> s:pre_draw(l:state, ctx, result)},
        \ }
endfunction

function! s:pre_draw(state, ctx, result) abort
  if a:ctx.run_id == a:state.run_id
    return 1
  endif

  let a:state.run_id = a:ctx.run_id

  call timer_stop(a:state.timer)
  let a:state.timer = timer_start(a:state.first_draw_delay, {-> wilder#main#draw()})

  return 0
endfunction

function! s:spinner(state, ctx, result) abort
  call timer_stop(a:state.timer)

  let l:height = a:ctx.height

  let [l:frame_number, l:wait_time] = a:state.spinner(a:ctx.done)

  if l:wait_time >= 0
    let a:state.timer = timer_start(l:wait_time, {-> wilder#main#draw()})
  endif

  if l:frame_number == -1
    let l:frame = a:state.done
  else
    let l:frame = a:state.frames[l:frame_number]
  endif

  let l:width = strdisplaywidth(l:frame)

  let l:spaces = repeat(' ', l:width)

  let l:column_chunks = repeat([[[l:spaces]]], l:height)

  let l:hl = get(a:state, 'hl', a:ctx.highlights.default)
  let l:selected_hl = a:ctx.highlights.selected
  if a:state.align ==# 'bottom'
    let l:column_chunks[-1] = [[l:frame, l:hl, l:selected_hl]]
  else
    let l:column_chunks[0] = [[l:frame, l:hl, l:selected_hl]]
  endif

  return l:column_chunks
endfunction
