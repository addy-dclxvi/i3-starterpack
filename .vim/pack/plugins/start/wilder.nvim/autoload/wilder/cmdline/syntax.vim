function! wilder#cmdline#syntax#do(ctx) abort
  " get subcommand
  let l:arg_start = a:ctx.pos
  let l:in_subcommand = 1
  while a:ctx.pos < len(a:ctx.cmdline)
    if wilder#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
      let l:in_subcommand = 0
      break
    endif

    let a:ctx.pos += 1
  endwhile

  if l:in_subcommand
    let a:ctx.pos = l:arg_start
    let a:ctx.expand = 'syntax_subcommand'
    return
  endif

  let l:subcommand = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]

  call wilder#cmdline#main#skip_whitespace(a:ctx)
  let l:arg_start = a:ctx.pos
  call wilder#cmdline#main#skip_nonwhitespace(a:ctx)
  let l:arg_end = a:ctx.pos
  call wilder#cmdline#main#skip_whitespace(a:ctx)

  if a:ctx.pos != l:arg_end
    let a:ctx.expand = 'nothing'
    return
  endif

  let a:ctx.pos = l:arg_start

  if l:subcommand ==# 'case' ||
        \ l:subcommand ==# 'spell' ||
        \ l:subcommand ==# 'sync'
    let a:ctx.expand = 'syntax'
  elseif l:subcommand ==# 'keyword' ||
        \ l:subcommand ==# 'region' ||
        \ l:subcommand ==# 'match' ||
        \ l:subcommand ==# 'list'
    let a:ctx.expand = 'highlight'
  else
    let a:ctx.expand = 'nothing'
  endif
endfunction
