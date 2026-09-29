function! wilder#cmdline#global#do(ctx) abort
  if a:ctx.pos >= len(a:ctx.cmdline)
    return
  endif

  let l:delimiter = a:ctx.cmdline[a:ctx.pos]
  let a:ctx.pos += 1

  let l:arg_start = a:ctx.pos
  let l:delimiter_reached = 0

  while a:ctx.pos < len(a:ctx.cmdline)
    if a:ctx.cmdline[a:ctx.pos] ==# '\' &&
          \ a:ctx.pos + 1 < len(a:ctx.cmdline)
      let a:ctx.pos += 1
    elseif a:ctx.cmdline[a:ctx.pos] ==# l:delimiter
      let l:delimiter_reached = 1

      break
    endif

    let a:ctx.pos += 1
  endwhile

  " delimiter not reached
  if !wilder#cmdline#skip_regex#do(a:ctx, l:delimiter)
    let a:ctx.pos = l:arg_start
    return
  endif

  " skip delimiter
  let a:ctx.pos += 1

  " new command
  let a:ctx.cmd = ''
  let a:ctx.expand = ''

  call wilder#cmdline#main#do(a:ctx)
endfunction
