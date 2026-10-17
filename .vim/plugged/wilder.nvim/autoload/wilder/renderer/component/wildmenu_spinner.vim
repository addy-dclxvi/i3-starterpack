function! wilder#renderer#component#wildmenu_spinner#(args) abort
  let l:frames = get(a:args, 'frames', ['-', '\', '|', '/'])
  if type(l:frames) is v:t_string
    let l:frames = split(l:frames, '\zs')
  endif

  let l:Done = get(a:args, 'done', '·')

  let l:Spinner = wilder#renderer#component#spinner#({
        \ 'num_frames': len(l:frames),
        \ 'delay': get(a:args, 'delay', 100),
        \ 'interval': get(a:args, 'interval', 100),
        \ })

  let l:state = {
        \ 'frames': l:frames,
        \ 'current_frame': l:Done,
        \ 'done': l:Done,
        \ 'spinner': l:Spinner,
        \ 'timer': -1,
        \ 'hl': get(a:args, 'hl', 0),
        \ }

  return {
        \ 'value': {ctx, result -> s:spinner(l:state, ctx, result)},
        \ 'len': {ctx, result -> wilder#renderer#wildmenu#get_item_len(
        \   s:get_char(l:state, ctx, result), ctx, result)},
        \ 'pre_draw': {-> 1},
        \ }
endfunction

" Set current_char in here so it is consistent with the actual rendered
" char. Due to reltime(), the char might be changed since len is called
" earlier
function! s:get_char(state, ctx, result) abort
  call timer_stop(a:state.timer)

  let [l:frame_index, l:wait_time] = a:state.spinner(a:ctx.done)

  if l:wait_time >= 0
    let a:state.timer = timer_start(l:wait_time, {-> wilder#main#draw()})
  endif

  if l:frame_index == -1
    let a:state.current_frame = a:state.done
  else
    let a:state.current_frame = a:state.frames[l:frame_index]
  endif

  return a:state.current_frame
endfunction

function! s:spinner(state, ctx, result) abort
  if a:state.hl is 0
    return a:state.current_frame
  endif

  return [a:state.current_frame, a:state.hl]
endfunction
