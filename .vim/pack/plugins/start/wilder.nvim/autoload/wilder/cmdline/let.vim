function! wilder#cmdline#let#do(ctx)
  if a:ctx.cmd ==# 'let'
    let a:ctx.expand = 'var'
    if match(a:ctx.cmdline[a:ctx.pos :], '[' . "'" . '"+\-*/%.=!?~|&$([<>,#]') == -1
      " let var1 var2 ...
      let l:arg_start = a:ctx.pos

      while a:ctx.pos < len(a:ctx.cmdline)
        if wilder#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
          let l:arg_start = a:ctx.pos + 1
        endif

        let a:ctx.pos += 1
      endwhile

      let a:ctx.pos = l:arg_start

      return
    endif
  else
    let a:ctx.expand = a:ctx.cmd ==# 'call' ? 'function' : 'expression'
  endif

  let l:got_eq = 0

  let l:arg_start = a:ctx.pos

  while a:ctx.pos < len(a:ctx.cmdline)
    let l:match = match(a:ctx.cmdline[a:ctx.pos :], '[' . "'" . '"+\-*/%.=!?~|&$([<>,# ]')

    if l:match != -1
      let a:ctx.pos += l:match
      let l:char = a:ctx.cmdline[a:ctx.pos]

      if l:char ==# '&' && a:ctx.pos < len(a:ctx.cmdline)
        if a:ctx.cmdline[a:ctx.pos + 1] ==# '&'
          let a:ctx.pos += 1
          let a:ctx.expand = (a:ctx.cmd ==# 'let' || l:got_eq)
                \ ? 'expression'
                \ : 'nothing'
        elseif l:char !=# ' '
          let a:ctx.expand = 'option'
          if a:ctx.pos + 2 < len(a:ctx.cmdline) &&
                \ (a:ctx.cmdline[a:ctx.pos + 1] ==# 'l' ||
                \ a:ctx.cmdline[a:ctx.pos + 2] ==# 'g') &&
                \ a:ctx.cmdline[a:ctx.pos + 2] ==# ':'
            let a:ctx.pos += 2
          endif
        endif
      elseif l:char ==# '$'
        let a:ctx.expand = 'environment'
      elseif l:char ==# '='
        let l:got_eq = 1
        let a:ctx.expand = 'expression'
      elseif l:char ==# '#' && a:ctx.expand ==# 'expression'
        " this doesn't look correct
        " but we follow the wildmenu implementation
        break
      elseif (l:char ==# '<' || l:char ==# '#') &&
            \ a:ctx.expand ==# 'function' &&
            \ stridx(a:ctx.cmdline[a:ctx.pos + 1 :], '(') == -1
        " this doesn't look correct either
        break
      elseif a:ctx.cmd !=# 'let' || l:got_eq
        " this doesn't look correct either
        if l:char ==# '"'
          let a:ctx.pos += 1

          while a:ctx.pos < len(a:ctx.cmdline)
                \ && a:ctx.cmdline[a:ctx.pos] !=# '"'
            if a:ctx.pos + 1 < len(a:ctx.cmdline) &&
                  \ a:ctx.cmdline[a:ctx.pos] ==# '\'
              let a:ctx.pos += 1
            endif

            let a:ctx.pos += 1
          endwhile

          let a:ctx.expand = 'nothing'
        elseif l:char ==# "'"
          while a:ctx.pos < len(a:ctx.cmdline) &&
                \ a:ctx.cmdline[a:ctx.pos] !=# "'"
              let a:ctx.pos += 1
          endwhile

          let a:ctx.expand = 'nothing'
        elseif l:char ==# '|'
          if a:ctx.pos + 1 < len(a:ctx.cmdline) &&
                \ a:ctx.cmdline[a:ctx.pos + 1] ==# '|'
            let a:ctx.pos += 1
            let a:ctx.expand = 'expression'
          else
            let a:ctx.expand = 'command'
          endif
        else
          let a:ctx.expand = 'expression'
        endif
      else
        let a:ctx.expand = 'expression'
      endif

      let a:ctx.pos += 1

      if wilder#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
        call wilder#cmdline#main#skip_whitespace(a:ctx)
      endif

      let l:arg_start = a:ctx.pos
    else
      break
    endif
  endwhile

  let a:ctx.pos = l:arg_start
endfunction
