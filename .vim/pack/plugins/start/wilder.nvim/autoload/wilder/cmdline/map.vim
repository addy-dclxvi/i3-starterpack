function! wilder#cmdline#map#do(ctx) abort
  if a:ctx.force && a:ctx.cmd !=# 'map' && a:ctx.cmd !=# 'unmap'
    let a:ctx.expand = 'nothing'
    return
  endif

  let a:ctx.expand = 'mapping'
  let l:arg_start = a:ctx.pos

  while a:ctx.pos < len(a:ctx.cmdline)
    let l:arg = a:ctx.cmdline[l:arg_start :]

    if !has_key(a:ctx, 'map_args')
      let a:ctx.map_args = {}
    endif

    if l:arg[:7] ==# '<buffer>' ||
          \ l:arg[:7] ==# '<unique>' ||
          \ l:arg[:7] ==# '<nowait>' ||
          \ l:arg[:7] ==# '<silent>' ||
          \ l:arg ==# '<special>' ||
          \ l:arg[:7] ==# '<script>' ||
          \ l:arg ==# '<expr>'
      let a:ctx.map_args[l:arg[:7]] = 1
      let l:arg_start += 8
    elseif l:arg[:5] ==# '<expr>'
      let a:ctx.map_args[l:arg[:5]] = 1
      let l:arg_start += 6
    elseif l:arg[:8] ==# '<special>'
      let a:ctx.map_args[l:arg[:8]] = 1
      let l:arg_start += 9
    else
      let a:ctx.pos = l:arg_start
      call wilder#cmdline#main#skip_whitespace(a:ctx)
      return
    endif

    let a:ctx.pos = l:arg_start
    call wilder#cmdline#main#skip_whitespace(a:ctx)
    let l:arg_start = a:ctx.pos
  endwhile

  let a:ctx.pos = l:arg_start
endfunction
