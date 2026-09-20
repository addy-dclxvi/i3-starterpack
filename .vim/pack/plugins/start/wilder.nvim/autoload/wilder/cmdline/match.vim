function! wilder#cmdline#match#do(ctx) abort
  let l:arg_start = a:ctx.pos

  " TODO? :h :match - watch out for special characters " and |
  if !wilder#cmdline#main#skip_nonwhitespace(a:ctx)
    let a:ctx.expand = 'highlight'
    let a:ctx.pos = l:arg_start
    return
  endif

  if wilder#cmdline#main#skip_whitespace(a:ctx)
    let l:delimiter = a:ctx.cmdline[a:ctx.pos]
    let a:ctx.expand = 'nothing'
    let a:ctx.pos += 1

    call wilder#cmdline#skip_regex#do(a:ctx, l:delimiter)
  endif

  " Skip to trailing |, if any
  while a:ctx.pos < len(a:ctx.cmdline) &&
        \ a:ctx.cmdline[a:ctx.pos] !=# '|'
    let a:ctx.pos += 1
  endwhile

  if a:ctx.pos == len(a:ctx.cmdline)
    return
  endif

  let a:ctx.pos += 1
  let a:ctx.cmd = ''

  call wilder#cmdline#main#do(a:ctx)
endfunction
