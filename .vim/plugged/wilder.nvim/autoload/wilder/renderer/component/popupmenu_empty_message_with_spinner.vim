function! wilder#renderer#component#popupmenu_empty_message_with_spinner#(opts) abort
  let l:frames = get(a:opts, 'frames', [' -', ' \', ' |', ' /'])
  if type(l:frames) is v:t_string
    let l:frames = split(l:frames, '\zs')
  endif

  let l:Message = get(a:opts, 'message', ' No candidates found ')

  if type(l:Message) is v:t_string
    let l:message = l:Message
    let l:Message = {ctx, result, spinner_char, spinner_hl ->
          \ s:make_empty_message(ctx, l:message, spinner_char, spinner_hl)}
  endif

  let l:Spinner = wilder#renderer#component#spinner#({
        \ 'num_frames': len(l:frames),
        \ 'delay': get(a:opts, 'delay', 100),
        \ 'interval': get(a:opts, 'interval', 100),
        \ })

  let l:state = {
        \ 'frames': l:frames,
        \ 'done': get(a:opts, 'done', ' ·'),
        \ 'message': l:Message,
        \ 'spinner': l:Spinner,
        \ 'timer': -1,
        \ }

  if has_key(a:opts, 'spinner_hl')
    let l:state.spinner_hl = a:opts.spinner_hl
  endif

  let l:opts = copy(a:opts)
  let l:opts.message = {ctx, result -> s:message(l:state, ctx, result)}

  return wilder#popupmenu_empty_message(l:opts)
endfunction

function s:message(state, ctx, result) abort
  call timer_stop(a:state.timer)

  let [l:frame_number, l:wait_time] = a:state.spinner(a:ctx.done)

  if l:wait_time >= 0
    let a:state.timer = timer_start(l:wait_time, {-> wilder#main#draw()})
  endif

  if l:frame_number == -1
    let l:frame = a:state.done
  else
    let l:frame = a:state.frames[l:frame_number]
  endif

  let l:spinner_hl = get(a:state, 'spinner_hl', a:ctx.highlights.empty_message)

  return a:state.message(a:ctx, a:result, l:frame, l:spinner_hl)
endfunction

function! s:make_empty_message(ctx, message, spinner_char, spinner_hl) abort
  let l:max_width = a:ctx.max_width
  let l:spinner_width = strdisplaywidth(a:spinner_char)

  let l:max_width -= l:spinner_width
  let l:message = wilder#render#truncate(l:max_width, a:message)

  return [[a:spinner_char, a:spinner_hl], [l:message, a:ctx.highlights.empty_message]]
endfunction
