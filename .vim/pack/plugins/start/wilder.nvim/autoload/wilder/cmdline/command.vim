function! wilder#cmdline#command#do(ctx) abort
  let l:arg_start = a:ctx.pos

  " check for -attr
  while a:ctx.cmdline[a:ctx.pos] ==# '-'
    let a:ctx.pos += 1
    let l:attr_start = a:ctx.pos

    " skip to white space
    call wilder#cmdline#main#skip_nonwhitespace(a:ctx)

    " cursor ends in attr
    if a:ctx.pos == len(a:ctx.cmdline)
      " check if cursor is in -attr= part
      let a:ctx.pos = l:attr_start

      while a:ctx.pos < len(a:ctx.cmdline)
        if a:ctx.cmdline[a:ctx.pos] ==# '='
          break
        endif

        let a:ctx.pos += 1
      endwhile

      if a:ctx.pos == len(a:ctx.cmdline)
        let a:ctx.expand = 'user_cmd_flags'
        let a:ctx.pos = l:attr_start
        return
      endif

      let l:attr = a:ctx.cmdline[l:attr_start : a:ctx.pos - 1]
      if l:attr ==# 'complete'
        let a:ctx.expand = 'user_complete'
        let a:ctx.pos += 1
      elseif l:attr ==# 'nargs'
        let a:ctx.expand = 'user_nargs'
        let a:ctx.pos += 1
      elseif l:attr ==# 'addr'
        let a:ctx.expand = 'user_addr_type'
        let a:ctx.pos += 1
      else
        " in -attr part
        let a:ctx.pos = l:arg_start
      endif

      return
    endif

    if !wilder#cmdline#main#skip_whitespace(a:ctx)
      return
    endif
  endwhile

  " command name
  " skip to white space
  while a:ctx.pos < len(a:ctx.cmdline)
    if wilder#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
      break
    endif

    let a:ctx.pos += 1
  endwhile

  " cursor ends at command name
  if a:ctx.pos == len(a:ctx.cmdline)
    let a:ctx.expand = 'user_commands'
    let a:ctx.pos = l:arg_start
    return
  endif

  " new command
  let a:ctx.cmd = ''
  let a:ctx.expand = ''

  call wilder#cmdline#main#do(a:ctx)
endfunction
