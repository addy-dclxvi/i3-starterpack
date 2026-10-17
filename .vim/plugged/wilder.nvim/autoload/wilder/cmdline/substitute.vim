function! wilder#cmdline#substitute#do(ctx) abort
  let a:ctx.substitute_args = []

  if a:ctx.pos >= len(a:ctx.cmdline)
    return
  endif

  let l:cmd_start = a:ctx.pos

  let l:delimiter = a:ctx.cmdline[a:ctx.pos]

  " delimiter cannot be alphanumeric, '\' or '|', see E146
  if l:delimiter >=# 'a' && l:delimiter <=# 'z' ||
        \ l:delimiter >=# 'A' && l:delimiter <=# 'Z' ||
        \ l:delimiter >=# '0' && l:delimiter <=# '9' ||
        \ l:delimiter ==# '\' || l:delimiter ==# '|'
    return
  endif

  call add(a:ctx.substitute_args, l:delimiter)

  let a:ctx.pos += 1
  let l:arg_start = a:ctx.pos

  " delimiter not reached
  if !wilder#cmdline#skip_regex#do(a:ctx, l:delimiter)
    call add(a:ctx.substitute_args, a:ctx.cmdline[l:arg_start :])
    let a:ctx.pos = l:arg_start
    return
  endif

  call add(a:ctx.substitute_args, a:ctx.cmdline[l:arg_start : a:ctx.pos - 1])

  " skip delimiter
  let a:ctx.pos += 1
  let l:arg_start = a:ctx.pos
  call add(a:ctx.substitute_args, l:delimiter)

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

  if !l:delimiter_reached
    call add(a:ctx.substitute_args, a:ctx.cmdline[l:arg_start :])
    let a:ctx.pos = l:arg_start
    return
  endif

  call add(a:ctx.substitute_args, a:ctx.cmdline[l:arg_start : a:ctx.pos - 1])

  " skip delimiter
  let a:ctx.pos += 1
  let l:arg_start = a:ctx.pos
  call add(a:ctx.substitute_args, l:delimiter)

  " consume until | or " is reached
  while a:ctx.pos < len(a:ctx.cmdline)
    if a:ctx.cmdline[a:ctx.pos] ==# '"'
      let a:ctx.pos = len(a:ctx.cmdline)

      return []
    elseif a:ctx.cmdline[a:ctx.pos] ==# '|'
      let a:ctx.pos += 1
      let a:ctx.cmd = ''
      let a:ctx.expand = ''

      call wilder#cmdline#main#do(a:ctx)
      return []
    endif

    let a:ctx.pos += 1
  endwhile

  if a:ctx.pos != l:arg_start
    call add(a:ctx.substitute_args, a:ctx.cmdline[l:arg_start :])
  endif

  return
endfunction
