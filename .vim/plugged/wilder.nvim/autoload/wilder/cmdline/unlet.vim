function! wilder#cmdline#unlet#do(ctx) abort
  let l:last_arg = a:ctx.pos

  " find start of last argument
  while a:ctx.pos < len(a:ctx.cmdline)
    let l:char = a:ctx.cmdline[a:ctx.pos]

    let a:ctx.pos += 1

    if l:char ==# ' ' || l:char ==# "\t"
      let l:last_arg = a:ctx.pos
    endif
  endwhile

  let a:ctx.pos = l:last_arg

  if a:ctx.cmdline[a:ctx.pos] ==# '$'
    let a:ctx.expand = 'environment'
    let a:ctx.pos += 1
    return
  endif

  let a:ctx.expand = 'var'
endfunction
