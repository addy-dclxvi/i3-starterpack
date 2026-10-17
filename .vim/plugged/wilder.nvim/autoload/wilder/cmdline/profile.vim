function! wilder#cmdline#profile#do(ctx) abort
  let l:arg_start = a:ctx.pos

  if !wilder#cmdline#main#skip_nonwhitespace(a:ctx)
    let a:ctx.expand = 'profile'
    let a:ctx.pos = l:arg_start
    return
  endif

  let l:subcommand = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]

  if l:subcommand ==# 'start'
    let a:ctx.expand = 'files'
    call wilder#cmdline#main#skip_whitespace(a:ctx)
  endif

  let a:ctx.expand = 'nothing'
endfunction
