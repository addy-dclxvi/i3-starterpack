function! wilder#cmdline#sign#do(ctx) abort
  let a:ctx.expand = 'sign'
  let a:ctx.subcommand_start = a:ctx.pos

  let l:arg_start = a:ctx.pos

  if !wilder#cmdline#main#skip_nonwhitespace(a:ctx)
    let a:ctx.pos = l:arg_start
    return
  endif

  if !wilder#cmdline#main#skip_whitespace(a:ctx)
    return
  endif

  let l:arg_start = a:ctx.pos

  if !wilder#cmdline#main#skip_nonwhitespace(a:ctx)
    let a:ctx.pos = l:arg_start
    return
  endif

  while a:ctx.pos < len(a:ctx.cmdline)
    if !wilder#cmdline#main#skip_whitespace(a:ctx)
      return
    endif

    let l:arg_start = a:ctx.pos

    if !wilder#cmdline#main#skip_nonwhitespace(a:ctx)
      break
    endif
  endwhile

  let a:ctx.pos = l:arg_start

  while a:ctx.pos < len(a:ctx.cmdline)
    if a:ctx.cmdline[a:ctx.pos] ==# '='
      let a:ctx.pos += 1
      return
    endif

    let a:ctx.pos += 1
  endwhile

  let a:ctx.pos = l:arg_start
endfunction
