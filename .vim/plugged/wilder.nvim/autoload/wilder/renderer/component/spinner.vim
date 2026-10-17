function! wilder#renderer#component#spinner#(opts) abort
  let l:state = {
        \ 'num_frames': a:opts.num_frames,
        \ 'delay': a:opts.delay,
        \ 'interval': a:opts.interval,
        \ 'index': -1,
        \ 'was_done': 1,
        \ 'start_time': reltime(),
        \ }

  return {done -> s:spin(l:state, done)}
endfunction

" Returns [frame_index, wait_time]
function! s:spin(state, done) abort
  " Result has finished.
  if a:done
    let a:state.was_done = 1
    let a:state.index = -1
    return [a:state.index, -1]
  endif

  " Previous result was finished. Start spinner again.
  if a:state.was_done
    let a:state.was_done = 0
    let a:state.index = 0
    let a:state.start_time = reltime()
  endif

  let l:elapsed = reltimefloat(reltime(a:state.start_time)) * 1000

  " Calculate time to next frame. Either wait for delay to be over or wait for
  " next frame.
  if l:elapsed < a:state.delay
    let l:wait_time = a:state.delay - l:elapsed + 1
  else
    let l:elapsed_minus_delay = l:elapsed - a:state.delay
    let l:wait_time = a:state.interval - fmod(l:elapsed_minus_delay, a:state.interval) + 1
  endif

  let l:wait_time = float2nr(l:wait_time)

  if a:state.delay > 0 && l:elapsed < a:state.delay
    let a:state.index = -1
    return [a:state.index, l:wait_time]
  endif

  let l:elapsed_minus_delay = l:elapsed - a:state.delay
  let a:state.index = l:elapsed_minus_delay / a:state.interval

  let a:state.index = float2nr(fmod(a:state.index, a:state.num_frames))
  return [a:state.index, l:wait_time]
endfunction
