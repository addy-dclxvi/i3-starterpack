function! wilder#cmdline#isearch#do(ctx) abort
  " skip count
  while a:ctx.pos < len(a:ctx.cmdline) &&
        \ a:ctx.cmdline[a:ctx.pos] >=# '1' &&
        \ a:ctx.cmdline[a:ctx.pos] <=# '9'
    let a:ctx.pos += 1
  endwhile

  if !wilder#cmdline#main#skip_whitespace(a:ctx)
    return
  endif

  let l:delimiter = '/'
  if a:ctx.cmdline[a:ctx.pos] ==# l:delimiter
    let a:ctx.pos += 1

    " should use skip_regex
    " but follow the wildmenu implementation
    let l:delimiter_reached = 0
    while a:ctx.pos < len(a:ctx.cmdline)
      if a:ctx.cmdline[a:ctx.pos] ==# '\'
        if a:ctx.pos + 1 < len(a:ctx.cmdline)
          let a:ctx.pos += 1
        endif
      elseif a:ctx.cmdline[a:ctx.pos] ==# l:delimiter
        let a:ctx.pos += 1
        let l:delimiter_reached = 1
        break
      endif

      let a:ctx.pos += 1
    endwhile

    if !l:delimiter_reached
      return
    endif

    if !wilder#cmdline#main#skip_whitespace(a:ctx)
      return
    endif

    if a:ctx.cmdline[a:ctx.pos] ==# '|'
      let a:ctx.pos += 1
      let a:ctx.cmd = ''
      let a:ctx.expand = ''

      call wilder#cmdline#main#do(a:ctx)
      return
    endif

    " either comment or invalid args
  endif

  " no args when there is no delimiter
  let a:ctx.pos = len(a:ctx.cmdline)
endfunction
