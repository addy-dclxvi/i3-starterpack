function! wilder#renderer#mux#(opts) abort
  " convert from dict to list
  " e.g. {':': R1, '/': R2} to [[':', R1], ['/': R2]]
  if type(a:opts) is v:t_dict
    let l:rs = []

    for l:key in keys(a:opts)
      " put substitute check in front of : check
      " put ? check in front of / check since / covers both / and ?
      if l:key ==# 'substitute' || l:key ==# '?'
        call insert(l:rs, [l:key, a:opts[l:key]])
      else
        call add(l:rs, [l:key, a:opts[l:key]])
      endif
    endfor
  else
    let l:rs = a:opts
  endif

  " convert strings ':' to cmdtype checks
  let l:i = 0
  while l:i < len(l:rs)
    let l:r = l:rs[l:i]

    let l:Check = l:r[0]

    if type(l:Check) is v:t_string
      if l:Check ==# 'substitute'
        let l:r[0] = funcref('s:is_substitute_command')
      elseif l:Check ==# '/'
        let l:r[0] = {-> getcmdtype() ==# '/' || getcmdtype() ==# '?'}
      else
        let l:r[0] = s:cmdtype_check(l:Check)
      endif
    endif

    let l:i += 1
  endwhile

  let l:state = {
        \ 'current': 0,
        \ 'timer': -1,
        \ 'active': 0,
        \ 'renderers': l:rs
        \ }

  return {
        \ 'render': {ctx, result -> s:render(l:state, ctx, result)},
        \ 'pre_hook': {ctx -> s:pre_hook(l:state, ctx)},
        \ 'post_hook': {ctx -> s:post_hook(l:state, ctx)},
        \ }
endfunction

function! s:cmdtype_check(type)
  return {-> getcmdtype() ==# a:type}
endfunction

function! s:is_substitute_command(ctx) abort
  if getcmdtype() !=# ':'
    return 0
  endif

  let l:res = wilder#cmdline#parse(getcmdline())

  return wilder#cmdline#is_substitute_command(l:res.cmd)
endfunction

function! s:get_renderer(renderers) abort
  for [l:Check, l:renderer] in a:renderers
    if l:Check({})
      return l:renderer
    endif
  endfor

  return 0
endfunction

function! s:start_render(state, ctx, result)
  call timer_stop(a:state.timer)
  let a:state.timer = timer_start(0, {-> s:render(a:state, a:ctx, a:result)})
endfunction

function! s:render(state, ctx, result)
  if !a:state.active
    return
  endif

  let l:renderer = s:get_renderer(a:state.renderers)

  if l:renderer isnot a:state.current
    if a:state.current isnot 0 && has_key(a:state.current, 'post_hook')
      call a:state.current.post_hook({})
    endif

    if l:renderer isnot 0 && has_key(l:renderer, 'pre_hook')
      call l:renderer.pre_hook({})
    endif

    let a:state.current = l:renderer
  endif

  if l:renderer is 0
    return
  endif

  call l:renderer.render(a:ctx, a:result)
endfunction

function! s:pre_hook(state, ctx)
  let a:state.active = 1

  let l:renderer = s:get_renderer(a:state.renderers)

  let a:state.current = l:renderer

  if l:renderer is 0
    return
  endif

  if has_key(l:renderer, 'pre_hook')
    call l:renderer.pre_hook(a:ctx)
  endif
endfunction

function! s:post_hook(state, ctx)
  let a:state.active = 0

  let l:renderer = a:state.current

  if l:renderer is 0
    return
  endif

  let a:state.current = 0

  if has_key(l:renderer, 'post_hook')
    call l:renderer.post_hook(a:ctx)
  endif
endfunction
