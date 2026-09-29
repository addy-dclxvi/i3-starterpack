function! wilder#cmdline#filter#do(ctx) abort
  if a:ctx.pos == len(a:ctx.cmdline)
    return
  endif

  call wilder#cmdline#skip_vimgrep#do(a:ctx)

  if a:ctx.pos == len(a:ctx.cmdline)
    return
  endif

  call wilder#cmdline#main#skip_whitespace(a:ctx)

  let a:ctx.cmd = ''

  call wilder#cmdline#main#do(a:ctx)
endfunction
