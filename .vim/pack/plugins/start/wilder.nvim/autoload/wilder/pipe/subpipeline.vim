function! wilder#pipe#subpipeline#(f) abort
  return {_, x -> {ctx -> s:subpipeline(a:f, ctx, x)}}
endfunction

function! s:subpipeline(pipeline_func, ctx, x) abort
  let l:handler_id = a:ctx.handler_id
  let l:pipeline = a:pipeline_func(a:ctx, a:x)

  call wilder#pipeline#run(
        \ l:pipeline,
        \ {ctx, x -> s:on_finish(l:handler_id, ctx, x)},
        \ {ctx, x -> s:on_error(l:handler_id, ctx, x)},
        \ copy(a:ctx),
        \ copy(a:x),
        \ )
endfunction

function! s:on_finish(handler_id, ctx, x) abort
  let l:ctx = copy(a:ctx)
  let l:ctx.handler_id = a:handler_id

  call wilder#resolve(l:ctx, a:x)
endfunction

function! s:on_error(handler_id, ctx, x) abort
  let l:ctx = copy(a:ctx)
  let l:ctx.handler_id = a:handler_id

  call wilder#reject(l:ctx, a:x)
endfunction
