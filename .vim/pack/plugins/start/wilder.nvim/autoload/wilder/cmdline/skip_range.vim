let s:chars = " \t0123456789.$%'/?-+,;\\"

function! wilder#cmdline#skip_range#do(ctx) abort
  while a:ctx.pos < len(a:ctx.cmdline) &&
        \ stridx(s:chars, a:ctx.cmdline[a:ctx.pos]) != -1
    let l:char = a:ctx.cmdline[a:ctx.pos]
    if l:char ==# '\'
      if a:ctx.pos + 1 >= len(a:ctx.cmdline)
        return 1
      endif

      let l:second_char = a:ctx.cmdline[a:ctx.pos + 1]

      if l:second_char ==# '?' ||
            \ l:second_char ==# '/' ||
            \ l:second_char ==# '&'
        let a:ctx.pos += 2
      else
        return 1
      endif
    elseif l:char ==# "'"
      let a:ctx.pos += 1
    elseif l:char ==# '/' || l:char ==# '?'
      let l:delim = l:char
      let a:ctx.pos += 1

      while a:ctx.pos < len(a:ctx.cmdline) && a:ctx.cmdline[a:ctx.pos] !=# l:delim
        if a:ctx.cmdline[a:ctx.pos] ==# '\' &&
              \ a:ctx.pos + 1 < len (a:ctx.cmdline)
          let a:ctx.pos += 1
        endif

        let a:ctx.pos += 1
      endwhile

      if a:ctx.pos == len(a:ctx.cmdline)
        return
      endif
    endif

    let a:ctx.pos += 1
  endwhile
endfunc
