function! wilder#cmdline#highlight#do(ctx) abort
  let a:ctx.expand = 'highlight'
  let l:arg_start = a:ctx.pos

  if !wilder#cmdline#main#skip_nonwhitespace(a:ctx)
    let a:ctx.pos = l:arg_start
    return
  endif

  let l:subcommand = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]

  if l:subcommand ==# 'default'
    if !wilder#cmdline#main#skip_whitespace(a:ctx)
      return
    endif

    let l:arg_start = a:ctx.pos

    if !wilder#cmdline#main#skip_nonwhitespace(a:ctx)
      let a:ctx.pos = l:arg_start
      return
    endif

    let l:subcommand = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]
  endif

  if l:subcommand ==# 'link' || l:subcommand ==# 'clear'
    if !wilder#cmdline#main#skip_whitespace(a:ctx)
      return
    endif

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
  endif

  if a:ctx.pos != len(a:ctx.cmdline)
    let a:ctx.expand = 'nothing'
  endif

  let a:ctx.pos = l:arg_start
endfunction
