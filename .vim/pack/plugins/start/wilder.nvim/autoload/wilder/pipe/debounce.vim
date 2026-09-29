function! wilder#pipe#debounce#(t) abort
  let l:state = {
        \ 'timer': 0,
        \ 'interval': a:t,
        \ }

  return {ctx, x -> s:debounce(l:state, ctx, x)}
endfunction

function! s:debounce(state, _, x) abort
  return {ctx -> s:start(a:state, ctx, a:x)}
endfunction

function! s:start(state, ctx, x) abort
  call timer_stop(a:state['timer'])
  let a:state['timer'] = timer_start(
        \ a:state.interval, {-> wilder#resolve(a:ctx, a:x)})
endfunction
