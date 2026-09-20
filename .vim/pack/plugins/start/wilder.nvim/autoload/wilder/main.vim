scriptencoding utf-8

" wilder is enabled
let s:enabled = 1
" _wilder_init() has been called
let s:init = 0
" wilder is active (enabled, after CmdlineEnter, before CmdlineLeave)
let s:active = 0
" wilder is hidden (v:true returned from pipeline)
let s:hidden = 0
" timer used when use_cmdlinechanged == 0
let s:timer = v:null
" number of CmdlineEnter triggered
let s:session_id = 0
" session_id of last result
let s:result_session_id = -1
" id of the current pipeline call
let s:run_id = 0
" run_id of the last result
let s:result_run_id = -1
" s:draw() was called (used to avoid drawing again when pipeline is sync)
let s:draw_done = 0
" whether wilder#next() should be called when result is gotten (used by
" next_when_available()
let s:select_next = 0

" current completion (the candidate which was selected)
let s:completion = v:null
" the cmdline from the previous CmdlineChanged
let s:previous_cmdline = v:null
" the cmdline replaced when wilder#next() was called (used to reset the
" cmdline back to the original one when selected goes back to -1)
let s:replaced_cmdline = v:null
" the result from the pipeline
let s:result = {'value': [], 'data': {}}
" the error returned from the pipeline, if any
let s:error = v:null
" the index of selection (-1 represents no selection)
let s:selected = -1
" flag to pass to renderer to clear state
let s:clear_previous_renderer_state = 0
" completion from reject_completion (set so that the new completion won't be
" treated as overriding the previous cmdline, which triggers a new pipeline)
let s:completion_from_reject_completion = v:null
" tracks if wilder#next() has been called (used by noselect == 0)
let s:selection_was_made = 0

" stack of cmdlines used by accept_completion and reject_completion
let s:completion_stack = []

let s:opts = wilder#options#get()

function! wilder#main#in_mode() abort
  return mode(1) ==# 'c' && index(s:opts.modes, getcmdtype()) >= 0
endfunction

function! wilder#main#in_context() abort
  return wilder#main#in_mode() && !s:hidden && s:enabled
endfunction

function! wilder#main#enable_cmdline_enter() abort
  if !exists('#WilderCmdlineEnter')
    augroup WilderCmdlineEnter
      autocmd!
      autocmd CmdlineEnter * call wilder#main#start()
    augroup END
  endif
endfunction

function! wilder#main#disable_cmdline_enter() abort
  if exists('#WilderCmdlineEnter')
    augroup WilderCmdlineEnter
      autocmd!
    augroup END
    augroup! WilderCmdlineEnter
  endif
endfunction

function! wilder#main#start() abort
  " Workaround for https://github.com/neovim/neovim/issues/15403
  if wilder#main#in_mode() && s:enabled
    " use timer_start so statusline does not flicker
    " when using mappings which performs a command
    call timer_start(0, {-> s:start()})
  endif
endfunction

function! wilder#main#start_from_normal_mode() abort
  call timer_start(0, {-> s:start()})

  return ''
endfunction

function! s:start() abort
  if !wilder#main#in_mode() || !s:enabled
    call wilder#main#stop()
    return
  endif

  if !s:init && wilder#options#get('use_python_remote_plugin')
    let s:init = 1

    try
      if !has('nvim')
        " set up yarp
        call wilder#yarp#init()
      endif

      call _wilder_init({'num_workers': s:opts.num_workers})
    catch
      echohl ErrorMsg
      echomsg 'wilder: Python initialization failed'
      echomsg v:exception
      echohl Normal
    endtry
  endif

  if s:opts.use_cmdlinechanged
    if !exists('#WilderCmdlineChanged')
      augroup WilderCmdlineChanged
        autocmd!
        " call from a timer so statusline does not change during mappings
        autocmd CmdlineChanged * call timer_start(0, {_ -> s:do(1)})
      augroup END
    endif
  elseif s:timer is v:null
      let s:timer = timer_start(s:opts.interval,
            \ {_ -> s:do(1)},
            \ {'repeat': -1})
  endif

  if !exists('#WilderCmdlineLeave')
    augroup WilderCmdlineLeave
      autocmd!
      autocmd CmdlineLeave * call wilder#main#stop()
      autocmd CmdwinEnter * call wilder#main#stop()
    augroup END
  endif

  if !exists('#WilderVimResized')
    augroup WilderVimResized
      autocmd!
        autocmd VimResized * call timer_start(0, {_ -> s:draw_resized()})
    augroup END
  endif

  let s:active = 1
  let s:hidden = 0

  if !has_key(s:opts, 'renderer')
    let s:opts.renderer = wilder#wildmenu_renderer()
  endif

  if !has_key(s:opts, 'pipeline')
    let s:opts.pipeline = [
          \ wilder#branch(
          \   wilder#cmdline_pipeline(),
          \   has('nvim') && has('python3')
          \     ? wilder#python_search_pipeline()
          \     : wilder#vim_search_pipeline(),
          \ ),
          \ ]
  endif

  let s:session_id += 1

  call s:pre_hook()

  call s:do(0)
endfunction

function! wilder#main#stop() abort
  let s:select_next = 0

  if !s:active
    return
  endif

  if exists('#WilderCmdlineChanged')
    augroup WilderCmdlineChanged
      autocmd!
    augroup END
    augroup! WilderCmdlineChanged
  endif

  if s:timer isnot v:null
    call timer_stop(s:timer)
    let s:timer = v:null
  endif

  if exists('#WilderCmdlineLeave')
    augroup WilderCmdlineLeave
      autocmd!
    augroup END
    augroup! WilderCmdlineLeave
  endif

  if exists('#WilderVimResized')
    augroup WilderVimResized
      autocmd!
    augroup END
    augroup! WilderVimResized
  endif

  let s:active = 0
  let s:result = {'value': [], 'data': {}}
  let s:selected = -1
  let s:selection_was_made = 0
  let s:clear_previous_renderer_state = 0
  let s:completion_stack = []
  let s:previous_cmdline = v:null
  let s:completion = v:null
  let s:error = v:null
  let s:replaced_cmdline = v:null
  let s:completion_from_reject_completion = v:null

  if !s:hidden
    call s:post_hook()
  endif

  let s:hidden = 0
endfunction

function! s:pre_hook() abort
  call wilder#highlight#init_hl()

  if has_key(s:opts, 'pre_hook')
    call s:opts.pre_hook({})
  endif

  if has_key(s:opts.renderer, 'pre_hook')
    call s:opts.renderer.pre_hook({})
  endif
endfunction

function! s:post_hook() abort
  call wilder#pipeline#clear_handlers()

  if has_key(s:opts.renderer, 'post_hook')
    call s:opts.renderer.post_hook({})
  endif

  if has_key(s:opts, 'post_hook')
    call s:opts.post_hook({})
  endif
endfunction

function! s:do(check) abort
  if !s:active || !s:enabled
    return
  endif

  if a:check && !wilder#main#in_mode()
    call wilder#main#stop()
    return
  endif

  let l:input = s:getcmdline()

  let l:has_completion = l:input ==# s:completion
  let l:is_new_input = s:previous_cmdline is v:null
  let l:input_changed = s:previous_cmdline isnot v:null && s:previous_cmdline !=# l:input
  let l:should_keep_completion = s:completion_from_reject_completion isnot v:null &&
        \ s:completion_from_reject_completion ==# l:input

  if !l:has_completion && !l:should_keep_completion
    let s:completion = v:null
    let s:replaced_cmdline = v:null
    let s:completion_stack = []
  endif

  if !l:should_keep_completion
    let s:completion_from_reject_completion = v:null
  endif

  if s:previous_cmdline is v:null || l:input_changed
    let s:previous_cmdline = l:input
  endif

  let s:draw_done = 0

  if !l:has_completion && (l:input_changed || l:is_new_input)
    call s:run_pipeline(l:input)

    if !s:draw_done
      call s:draw()
    endif
  endif

  let s:force = 0
endfunction

function! s:run_pipeline(input, ...) abort
  let s:run_id += 1

  let l:ctx = {
        \ 'input': a:input,
        \ 'run_id': s:run_id,
        \ 'session_id': s:session_id,
        \ }

  if a:0 > 0
    call extend(l:ctx, a:1)
  endif

  call wilder#pipeline#run(
        \ s:opts.pipeline,
        \ function('wilder#main#on_finish'),
        \ function('wilder#main#on_error'),
        \ l:ctx,
        \ a:input,
        \ )
endfunction

function! wilder#main#on_finish(ctx, x) abort
  if !s:active || !s:enabled
    return
  endif

  if a:ctx.run_id != s:run_id
    return
  endif

  let s:result_run_id = a:ctx.run_id
  let s:result_session_id = a:ctx.session_id

  let l:result = (a:x is v:false || a:x is v:true)
        \ ? {'value': []}
        \ : a:x
  if type(l:result) isnot v:t_dict
    let s:result = {'value': l:result}
  else
    let s:result = l:result
  endif

  if !has_key(s:result, 'data')
    let s:result.data = {}
  endif

  if !has_key(s:result.data, 'query')
    let s:result.data.query = a:ctx.input
  endif

  " When a new result arrives, the previous results are cleared. If there is a
  " selection, treat the current cmdline as being replaced.
  if s:selected >= 0
    let s:replaced_cmdline = getcmdline()
  endif

  let s:selected = -1
  let s:selection_was_made = 0
  let s:clear_previous_renderer_state = 1
  " keep previous completion

  let s:error = v:null

  if a:x is v:true
    if !s:hidden
      let s:hidden = 1

      call s:post_hook()
    endif

    return
  endif

  if s:hidden
    let s:hidden = 0

    call s:pre_hook()
  endif

  if s:select_next
    call wilder#main#next()

    let s:select_next = 0
    return
  endif

  if !empty(s:completion_stack) && get(a:ctx, 'auto_select', 0)
    " removing previous_cmdline causes this to be treated as a new input
    let s:previous_cmdline = v:null

    call wilder#main#next()
    return
  endif

  call s:draw()
endfunction

function! wilder#main#on_error(ctx, x) abort
  if !s:active || !s:enabled
    return
  endif

  if a:ctx.run_id != s:run_id
    return
  endif

  let s:result_run_id = a:ctx.run_id

  let s:result = {'value': [], 'data': {}}
  let s:selected = -1
  let s:selection_was_made = 0
  " keep previous completion

  let s:error = a:x

  call s:draw()
endfunction

function! wilder#main#draw() abort
  if !s:active || !s:enabled
    return 0
  endif

  call s:draw()
  return 1
endfunction

function! s:draw_resized() abort
  if !s:active || !s:enabled
    return
  endif

  call s:draw(0)
endfunction

function! s:draw(...) abort
  if s:hidden
    return
  endif

  try
      let l:direction = a:0 >= 1 ? a:1 : 0

      if s:selected == -1 &&
            \ !s:opts.noselect &&
            \ !s:selection_was_made &&
            \ !empty(s:result.value)
        let l:selected = 0
      else
        let l:selected = s:selected
      endif

      let l:ctx = {
            \ 'clear_previous': get(s:, 'clear_previous_renderer_state', 0),
            \ 'selected': l:selected,
            \ 'direction': l:direction,
            \ 'run_id': s:result_run_id,
            \ 'done': s:run_id == s:result_run_id,
            \ 'session_id': s:result_session_id,
            \ }
      let s:clear_previous_renderer_state = 0

      let l:has_error = s:error isnot v:null

      if l:has_error
        let l:ctx.error = s:error
        let l:value = {'value': []}
      else
        let l:value = s:result
      endif

      call s:opts.renderer.render(l:ctx, l:value)
  catch
    echohl ErrorMsg
    echomsg 'wilder: draw: ' . v:exception
    echohl Normal
  finally
    let s:draw_done = 1
  endtry
endfunction

function! wilder#main#next() abort
  return wilder#main#step(1)
endfunction

function! wilder#main#next_when_available() abort
  let s:select_next = 1
  return ''
endfunction

function! wilder#main#trigger_change() abort
  let s:previous_cmdline = v:null
  let s:completion = v:null

  call s:do(1)
  return "\<Insert>\<Insert>"
endfunction

function! wilder#main#previous() abort
  return wilder#main#step(-1)
endfunction

function! wilder#main#step(num_steps) abort
  if !s:enabled
    " returning '' seems to prevent async completions from finishing
    " or prevent redrawing
    return "\<Insert>\<Insert>"
  endif

  if !s:active
    call s:start()
    return "\<Insert>\<Insert>"
  endif

  if s:hidden
    return "\<Insert>\<Insert>"
  endif

  " If replaced_cmdline is null, this is the first wilder#next() call for the
  " current result
  if s:replaced_cmdline is v:null
    " Original cmdline
    let s:replaced_cmdline = s:getcmdline()
  endif

  let l:previous_selected = s:selected

  let l:len = len(s:result.value)

  if s:selected == -1 &&
        \ !s:opts.noselect &&
        \ !s:selection_was_made
    let s:selected = 0
  endif

  let s:selection_was_made = 1

  if a:num_steps == 0
    " pass
  elseif l:len == 0
    let s:selected = -1
  else
    if s:selected < 0
      if a:num_steps > 0
        let l:selected = a:num_steps - 1
      else
        let l:selected = a:num_steps
      endif

      while l:selected < 0
        let l:selected += l:len
      endwhile
    else
      let l:selected = s:selected + a:num_steps

      while l:selected < -1
        let l:selected += l:len
      endwhile
    endif

    while l:selected > l:len
      let l:selected -= l:len
    endwhile

    let s:selected = l:selected == l:len ? -1 : l:selected
  endif

  if s:selected >= -1
    if s:selected >= 0
      " add the entry to the completion stack if there was no previous selection
      if l:previous_selected == -1
        call s:push_completion_stack(s:replaced_cmdline)
      endif

      let l:new_cmdline = s:get_cmdline_from_candidate(s:selected)
    else
      " selected == -1 here
      " Go back to original cmdline
      let l:new_cmdline = s:replaced_cmdline

      " if previous_selected != -1, an entry was added to completion_stack
      " remove it here
      if l:previous_selected != -1
        call s:pop_completion_stack()
      endif
    endif

    let s:completion = l:new_cmdline
    call s:feedkeys_cmdline(l:new_cmdline)
  else
    " No completion
    let s:completion = v:null

    " if previous_selected != -1, an entry was added to completion_stack
    " remove it here
    if l:previous_selected != -1
      call s:pop_completion_stack()
    endif
  endif

  call s:draw(a:num_steps)

  return "\<Insert>\<Insert>"
endfunction

function! wilder#main#get_candidate(ctx, result, index) abort
  return a:result.value[a:index]
endfunction

function! s:get_cmdline_from_candidate(index) abort
  let l:candidate = wilder#main#get_candidate({}, s:result, a:index)

  let l:output = l:candidate

  if has_key(s:result, 'output')
    for l:F in s:result.output
      if type(l:F) isnot v:t_func
        let l:F = function(l:F)
      endif

      let l:output = l:F({}, l:output, s:result.data)
    endfor
  endif

  let l:cmdline = l:output
  if has_key(s:result, 'replace')
    for l:F in s:result.replace
      if type(l:F) isnot v:t_func
        let l:F = function(l:F)
      endif

      let l:cmdline = l:F({
            \ 'cmdline': s:replaced_cmdline,
            \ }, l:cmdline, s:result.data)
    endfor
  endif

  return l:cmdline
endfunction

function! s:getcmdline(...) abort
  if s:opts.use_cmdlinechanged || !s:opts.before_cursor
    return getcmdline()
  endif

  if a:0
    let l:cmdline = a:1
    let l:cmdpos = a:2
  else
    let l:cmdline = getcmdline()
    let l:cmdpos = getcmdpos()
  endif

  if l:cmdpos <= 1
    return ''
  else
    return l:cmdline[: l:cmdpos - 2]
  endif
endfunction

function! s:feedkeys_cmdline(cmdline) abort
  let l:chars = split(a:cmdline, '\zs')

  if s:opts.use_cmdlinechanged || !s:opts.before_cursor
    let l:keys = "\<C-E>\<C-U>"
  else
    let l:keys = "\<C-U>"
  endif

  for l:char in l:chars
    " control characters
    if l:char <# ' '
      let l:keys .= "\<C-Q>"
    endif

    let l:keys .= l:char
  endfor

  call feedkeys(l:keys, 'n')
endfunction

function! wilder#main#can_accept_completion() abort
  return wilder#main#in_context() &&
        \ (s:selected >= 0 ||
        \ (!s:opts.noselect &&
        \ s:selected == -1 &&
        \ !s:selection_was_made &&
        \ !empty(s:result.value)))
endfunction

function! wilder#main#accept_completion(auto_select) abort
  " previous_cmdline can be null since feedkeys is not synchronous
  " this can occur when accept_completion is triggered in quick succession
  " in this case, ignore the command
  if s:selected >= 0
        \ && s:previous_cmdline isnot v:null
    let l:cmdline = getcmdline()

    let s:previous_cmdline = l:cmdline

    " Reset state as we are running a new pipeline
    let s:completion = v:null
    let s:replaced_cmdline = v:null
    let s:result = {'value': [], 'data': {}}
    let s:selected = -1
    let s:selection_was_made = 0
    let s:clear_previous_renderer_state = 1

    " add the entry to the completion stack
    call s:push_completion_stack(l:cmdline)

    let l:auto_select = s:opts.noselect ? a:auto_select : 0
    call s:run_pipeline(l:cmdline, {'auto_select': l:auto_select})
  elseif !s:opts.noselect &&
        \ s:selected == -1 &&
        \ !s:selection_was_made &&
        \ !empty(s:result.value)
    " simulate wilder#next()
    " can perhaps be generalised to handle a noinsert == 1 option
    let l:cmdline = getcmdline()

    if s:replaced_cmdline is v:null
      let s:replaced_cmdline = l:cmdline
    endif

    call s:push_completion_stack(l:cmdline)

    let l:new_cmdline = s:get_cmdline_from_candidate(0)

    let s:selected = 0
    let s:completion = l:new_cmdline
    call s:feedkeys_cmdline(l:new_cmdline)
  endif

  return "\<Insert>\<Insert>"
endfunction

function! wilder#main#can_reject_completion() abort
  return wilder#main#in_context() && !empty(s:completion_stack)
endfunction

function! wilder#main#reject_completion() abort
  if !empty(s:completion_stack)
    let l:cmdline = s:completion_stack[0]
    call  s:pop_completion_stack()

    let s:completion = v:null
    let s:replaced_cmdline = v:null

    let s:previous_cmdline = l:cmdline
    let s:completion_from_reject_completion = l:cmdline
    let s:result = {'value': [], 'data': {}}
    let s:selected = -1
    let s:selection_was_made = 0
    let s:clear_previous_renderer_state = 1

    call s:feedkeys_cmdline(l:cmdline)
    call s:run_pipeline(l:cmdline)
  endif

  return "\<Insert>\<Insert>"
endfunction

function! s:push_completion_stack(cmdline) abort
  " double-check that the last added entry is not the same value
  " this can happen when the argument exactly matches the completion
  if !empty(s:completion_stack) &&
        \ s:completion_stack[0] ==# a:cmdline
    return
  endif

  let s:completion_stack = [a:cmdline] + s:completion_stack
endfunction

function! s:pop_completion_stack() abort
  let s:completion_stack = s:completion_stack[1:]
endfunction

function! wilder#main#enable() abort
  let s:enabled = 1

  return ''
endfunction

function! wilder#main#disable() abort
  let s:enabled = 0

  call wilder#main#stop()

  return ''
endfunction

function! wilder#main#toggle() abort
  if s:enabled
    return wilder#main#disable()
  endif

  return wilder#main#enable()
endfunction
