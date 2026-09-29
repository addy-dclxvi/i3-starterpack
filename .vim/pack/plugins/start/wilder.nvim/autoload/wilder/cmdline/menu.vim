function! wilder#cmdline#menu#do(ctx) abort
  let a:ctx.expand = 'menu'
  let a:ctx.menu_arg = a:ctx.cmdline[a:ctx.pos :]
  let l:arg_start = a:ctx.pos

  while a:ctx.pos < len(a:ctx.cmdline)
    if a:ctx.cmdline[a:ctx.pos] ==# '\' &&
          \ a:ctx.pos + 1 < len(a:ctx.cmdline)
      let a:ctx.pos += 1
    elseif a:ctx.cmdline[a:ctx.pos] ==# '.'
      let l:arg_start = a:ctx.pos + 1
    endif

    let a:ctx.pos += 1
  endwhile

  let a:ctx.pos = l:arg_start
endfunction
