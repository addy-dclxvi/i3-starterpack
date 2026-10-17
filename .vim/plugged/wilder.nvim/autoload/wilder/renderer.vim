function! wilder#renderer#redraw(apply_incsearch_fix) abort
  call s:redraw(a:apply_incsearch_fix, 0)
endfunction

function! wilder#renderer#redrawstatus(apply_incsearch_fix) abort
  call s:redraw(a:apply_incsearch_fix, 1)
endfunction

function! s:redraw(apply_incsearch_fix, is_redrawstatus) abort
  if a:apply_incsearch_fix &&
        \ &incsearch &&
        \ (getcmdtype() ==# '/' || getcmdtype() ==# '?')
    call feedkeys("\<C-R>\<BS>", 'n')
    return
  endif

  if a:is_redrawstatus
    redrawstatus
  else
    redraw
  endif
endfunction

function! wilder#renderer#get_cmdheight() abort
  if !has('nvim')
    " For Vim, if cmdline exceeds cmdheight, the screen lines are pushed up
    " similar to :mess, so we draw the popupmenu just above the cmdline.
    " Lines exceeding cmdheight do not count into target line number.
    return &cmdheight
  endif

  let l:cmdline = getcmdline()

  " include the cmdline character
  let l:display_width = strdisplaywidth(l:cmdline) + 1
  let l:cmdheight = l:display_width / &columns + 1

  if l:cmdheight < &cmdheight
    let l:cmdheight = &cmdheight
  elseif l:cmdheight > 1
    " Show the pum above the msgsep.
    let l:has_msgsep = stridx(&display, 'msgsep') >= 0

    if l:has_msgsep
      let l:cmdheight += 1
    endif
  endif

  return l:cmdheight
endfunction

function! wilder#renderer#pre_draw(components, ctx, result) abort
  let l:should_draw = 0

  for l:Component in a:components
    let l:should_draw += s:pre_draw(l:Component, a:ctx, a:result)
  endfor

  return l:should_draw
endfunction

function! s:pre_draw(component, ctx, result) abort
  if type(a:component) isnot v:t_dict
    return a:ctx.done
  endif

  if has_key(a:component, 'pre_draw')
    return a:component.pre_draw(a:ctx, a:result)
  endif

  return a:ctx.done || get(a:component, 'dynamic', 0)
endfunction

function! wilder#renderer#call_component_pre_hook(ctx, component) abort
  if type(a:component) is v:t_dict &&
        \ has_key(a:component, 'pre_hook')
    call a:component['pre_hook'](a:ctx)
  endif
endfunction

function! wilder#renderer#call_component_post_hook(ctx, component) abort
  if type(a:component) is v:t_dict &&
        \ has_key(a:component, 'post_hook')
    call a:component['post_hook'](a:ctx)
  endif
endfunction
