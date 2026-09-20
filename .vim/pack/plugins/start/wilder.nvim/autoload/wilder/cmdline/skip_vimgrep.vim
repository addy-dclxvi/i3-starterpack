function! wilder#cmdline#skip_vimgrep#do(ctx) abort
  " isident
  if match(a:ctx.cmdline[a:ctx.pos], '\i') != -1
    call wilder#cmdline#main#skip_nonwhitespace(a:ctx)
  else
    let l:delimiter = a:ctx.cmdline[a:ctx.pos]
    let a:ctx.pos += 1

    if !wilder#cmdline#skip_regex#do(a:ctx, l:delimiter)
      return
    endif

    while a:ctx.pos < len(a:ctx.cmdline) &&
          \ (a:ctx.cmdline[a:ctx.pos] ==# 'g' ||
          \ a:ctx.cmdline[a:ctx.pos] ==# 'j')
      let a:ctx.pos += 1
    endwhile
  endif
endfunction
