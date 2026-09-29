function! wilder#cmdline#autocmd#do(ctx, doautocmd) abort
  " :au[tocmd] [group] {event} {pat} [++once] [++nested] {cmd}

  let l:group = ''

  " check for group name
  let l:arg_start = a:ctx.pos
  while a:ctx.pos < len(a:ctx.cmdline)
    if wilder#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos]) ||
          \ a:ctx.cmdline[a:ctx.pos] ==# '|'
      break
    endif

    let a:ctx.pos += 1
  endwhile

  let l:has_group = 0
  let l:group_name = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]

  " exists('#abc') returns 1 if either the group or event exists so we have to
  " confirm that this is a group by checking that the event does not exist.
  if exists('#' . l:group_name) && !exists('##' . l:group_name)
    let l:has_group = 1
    call wilder#cmdline#main#skip_whitespace(a:ctx)
  else
    " Return to the start and treat the arg as an event
    let a:ctx.pos = l:arg_start
  endif

  " handle event name
  let l:arg_start = a:ctx.pos
  while a:ctx.pos < len(a:ctx.cmdline) &&
        \ !wilder#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
    " handle ,
    if a:ctx.cmdline[a:ctx.pos] ==# ','
      let l:arg_start = a:ctx.pos + 1
    endif

    let a:ctx.pos += 1
  endwhile

  " complete event/group name
  if a:ctx.pos == len(a:ctx.cmdline)
    if l:has_group
      let a:ctx.expand = 'event'
    else
      let a:ctx.expand = 'event_and_augroup'
    endif
    let a:ctx.pos = l:arg_start
    return
  endif

  call wilder#cmdline#main#skip_whitespace(a:ctx)

  " handle pattern
  let l:arg_start = a:ctx.pos
  while a:ctx.pos < len(a:ctx.cmdline) &&
        \ !wilder#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
    if a:ctx.cmdline[a:ctx.pos] ==# '\' &&
          \ a:ctx.pos + 1 < len(a:ctx.cmdline)
      let a:ctx.pos += 1
    endif

    let a:ctx.pos += 1
  endwhile

  " new command
  if a:ctx.pos < len(a:ctx.cmdline)
    let a:ctx.pos += 1
    let a:ctx.cmd = ''

    call wilder#cmdline#main#do(a:ctx)
    return
  endif

  if a:doautocmd
    let a:ctx.expand = 'file'
    let a:ctx.pos =  l:arg_start
  else
    " still in pattern
    let a:ctx.expand = 'nothing'
  endif
endfunction
