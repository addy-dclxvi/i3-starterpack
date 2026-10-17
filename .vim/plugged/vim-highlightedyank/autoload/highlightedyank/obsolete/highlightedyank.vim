let s:NULLPOS = [0, 0, 0, 0]
let s:NULLREGION = {
  \ 'wise': '', 'blockwidth': 0,
  \ 'head': copy(s:NULLPOS), 'tail': copy(s:NULLPOS),
  \ }
let s:MAXCOL = 2147483647
let s:HAS_GUI_RUNNING = has('gui_running')
let s:HAS_TIMERS = has('timers')
let s:TYPE_NUM = type(0)
let s:ON = 1
let s:OFF = 0

let s:STATE = s:ON

" SID
function! s:SID() abort
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction
let s:SID = printf("\<SNR>%s_", s:SID())
delfunction s:SID

" intrinsic keymap
noremap <SID>(highlightedyank-y) y
noremap <SID>(highlightedyank-doublequote) "
noremap <SID>(highlightedyank-g@) g@
noremap <SID>(highlightedyank-gv) gv
let s:normal = {}
let s:normal['y']  = s:SID . '(highlightedyank-y)'
let s:normal['"']  = s:SID . '(highlightedyank-doublequote)'
let s:normal['g@'] = s:SID . '(highlightedyank-g@)'
let s:normal['gv'] = s:SID . '(highlightedyank-gv)'



function! highlightedyank#obsolete#highlightedyank#yank(mode) abort  "{{{
  let l:count = v:count ? v:count : ''
  let register = v:register ==# s:default_register() ? '' : s:normal['"'] . v:register
  if a:mode ==# 'n'
    call s:yank_normal(l:count, register)
  elseif a:mode ==# 'x'
    call s:yank_visual(register)
  endif
endfunction "}}}


function! highlightedyank#obsolete#highlightedyank#setoperatorfunc() abort "{{{
  set operatorfunc=highlightedyank#obsolete#highlightedyank#operatorfunc
  return ''
endfunction "}}}


function! highlightedyank#obsolete#highlightedyank#operatorfunc(motionwise, ...) abort "{{{
  let region = {'head': getpos("'["), 'tail': getpos("']"), 'wise': a:motionwise}
  if s:is_ahead(region.head, region.tail)
    return
  endif

  let register = v:register ==# s:default_register() ? '' : '"' . v:register
  execute printf('normal! `[%sy%s`]', register, s:motionwise2visualmode(a:motionwise))
  call s:highlight_yanked_region(region)
endfunction "}}}


function! highlightedyank#obsolete#highlightedyank#on() abort "{{{
  let s:STATE = s:ON
  if stridx(&cpoptions, 'y') < 0
    nnoremap <silent> <Plug>(highlightedyank) :<C-u>call highlightedyank#obsolete#highlightedyank#yank('n')<CR>
    xnoremap <silent> <Plug>(highlightedyank) :<C-u>call highlightedyank#obsolete#highlightedyank#yank('x')<CR>
    onoremap          <Plug>(highlightedyank) y
  else
    noremap  <expr>   <Plug>(highlightedyank-setoperatorfunc) highlightedyank#obsolete#highlightedyank#setoperatorfunc()
    nmap     <silent> <Plug>(highlightedyank) <Plug>(highlightedyank-setoperatorfunc)<Plug>(highlightedyank-g@)
    xmap     <silent> <Plug>(highlightedyank) <Plug>(highlightedyank-setoperatorfunc)<Plug>(highlightedyank-g@)
    onoremap          <Plug>(highlightedyank) g@
  endif
endfunction "}}}


function! highlightedyank#obsolete#highlightedyank#off() abort "{{{
  let s:STATE = s:OFF
  noremap <silent> <Plug>(highlightedyank) y
endfunction "}}}


function! highlightedyank#obsolete#highlightedyank#toggle() abort "{{{
  if s:STATE is s:ON
    call highlightedyank#obsolete#highlightedyank#off()
  else
    call highlightedyank#obsolete#highlightedyank#on()
  endif
endfunction "}}}


function! s:default_register() abort  "{{{
  if &clipboard =~# 'unnamedplus'
    let default_register = '+'
  elseif &clipboard =~# 'unnamed'
    let default_register = '*'
  else
    let default_register = '"'
  endif
  return default_register
endfunction "}}}


function! s:yank_normal(count, register) abort "{{{
  let view = winsaveview()
  let options = s:shift_options()
  try
    let [input, region] = s:query(a:count)
    if region != s:NULLREGION
      call s:highlight_yanked_region(region)
      call winrestview(view)
      let keyseq = printf('%s%s%s%s', a:register, a:count, s:normal['y'], input)
      execute 'normal' keyseq
    endif
  finally
    call s:restore_options(options)
  endtry
endfunction "}}}


function! s:yank_visual(register) abort "{{{
  let view = winsaveview()
  let region = deepcopy(s:NULLREGION)
  let region.head = getpos("'<")
  let region.tail = getpos("'>")
  if s:is_ahead(region.head, region.tail)
    return
  endif

  let region.wise = s:visualmode2motionwise(visualmode())
  if region.wise ==# 'block'
    let region.blockwidth = s:is_extended() ? s:MAXCOL : virtcol(region.tail[1:2]) - virtcol(region.head[1:2]) + 1
  endif
  let options = s:shift_options()
  try
    call s:highlight_yanked_region(region)
    call winrestview(view)
    let keyseq = printf('%s%s%s', s:normal['gv'], a:register, s:normal['y'])
    execute 'normal' keyseq
  finally
    call s:restore_options(options)
  endtry
endfunction "}}}


function! s:query(count) abort "{{{
  let view = winsaveview()
  let curpos = getpos('.')
  let input = ''
  let region = deepcopy(s:NULLREGION)
  let motionwise = ''
  let dummycursor = {}
  try
    while 1
      let c = getchar(0)
      if empty(c)
        if empty(dummycursor)
          let dummycursor = s:put_dummy_cursor(curpos)
        endif
        sleep 20m
        continue
      endif

      let c = type(c) == s:TYPE_NUM ? nr2char(c) : c
      if c ==# "\<Esc>"
        break
      endif

      let input .= c
      let region = s:get_region(curpos, a:count, input)
      if region != s:NULLREGION
        break
      endif
    endwhile
  finally
    call s:clear_dummy_cursor(dummycursor)
    call winrestview(view)
  endtry
  return [input, region]
endfunction "}}}


function! s:get_region(curpos, count, input) abort  "{{{
  let s:region = deepcopy(s:NULLREGION)
  let opfunc = &operatorfunc
  let &operatorfunc = s:SID . 'operator_get_region'
  onoremap <Plug>(highlightedyank) g@
  call setpos('.', a:curpos)
  try
    execute printf("normal %s%s%s", a:count, s:normal['g@'], a:input)
  catch
    let verbose = get(g:, 'highlightedyank#verbose', 0)
    echohl ErrorMsg
    if verbose >= 2
      echomsg printf('highlightedyank: Motion error. [%s] %s', a:input, v:exception)
    elseif verbose == 1
      echomsg 'highlightedyank: Motion error.'
    endif
    echohl NONE
  finally
    onoremap <Plug>(highlightedyank) y
    let &operatorfunc = opfunc
    if s:region == s:NULLREGION
      return deepcopy(s:NULLREGION)
    endif
    return s:modify_region(s:region)
  endtry
endfunction "}}}


function! s:modify_region(region) abort "{{{
  " for multibyte characters
  if a:region.tail[2] != col([a:region.tail[1], '$']) && a:region.tail[3] == 0
    let cursor = getpos('.')
    call setpos('.', a:region.tail)
    call search('.', 'bc')
    let a:region.tail = getpos('.')
    call setpos('.', cursor)
  endif
  return a:region
endfunction "}}}


function! s:operator_get_region(motionwise) abort "{{{
  let head = getpos("'[")
  let tail = getpos("']")
  if s:is_ahead(head, tail)
    return
  endif

  let s:region.head = head
  let s:region.tail = tail
  let s:region.wise = a:motionwise
endfunction "}}}


function! s:put_dummy_cursor(curpos) abort "{{{
  if !hlexists('Cursor')
    return {}
  endif
  let pos = {'head': a:curpos, 'tail': a:curpos, 'wise': 'char'}
  let dummycursor = highlightedyank#obsolete#highlight#new(pos)
  call dummycursor.show('Cursor')
  redraw
  return dummycursor
endfunction "}}}


function! s:clear_dummy_cursor(dummycursor) abort  "{{{
  if empty(a:dummycursor)
    return
  endif
  call a:dummycursor.quench()
endfunction "}}}


function! s:highlight_yanked_region(region) abort "{{{
  let maxlinenumber = s:get('max_lines', 10000)
  if a:region.tail[1] - a:region.head[1] + 1 > maxlinenumber
    return
  endif

  let keyseq = ''
  let hi_group = 'HighlightedyankRegion'
  let hi_duration = s:get('highlight_duration', 1000)
  let highlight = highlightedyank#obsolete#highlight#new(a:region)
  if highlight.empty()
    return
  endif
  if hi_duration < 0
    call s:persist(highlight, hi_group)
  elseif hi_duration > 0
    if s:HAS_TIMERS
      call s:glow(highlight, hi_group, hi_duration)
    else
      let keyseq = s:blink(highlight, hi_group, hi_duration)
      call feedkeys(keyseq, 'it')
    endif
  endif
endfunction "}}}


function! s:persist(highlight, hi_group) abort  "{{{
  " highlight off: limit the number of highlighting region to one explicitly
  call highlightedyank#obsolete#highlight#cancel()

  if a:highlight.show(a:hi_group)
    call a:highlight.persist()
  endif
endfunction "}}}


function! s:blink(highlight, hi_group, duration) abort "{{{
  let key = ''
  if a:highlight.show(a:hi_group)
    redraw
    let key = s:wait_for_input(a:highlight, a:duration)
  endif
  return key
endfunction "}}}


function! s:glow(highlight, hi_group, duration) abort "{{{
  " highlight off: limit the number of highlighting region to one explicitly
  call highlightedyank#obsolete#highlight#cancel()
  if a:highlight.show(a:hi_group)
    call a:highlight.quench_timer(a:duration)
  endif
endfunction "}}}


function! s:wait_for_input(highlight, duration) abort  "{{{
  let clock = highlightedyank#obsolete#clock#new()
  try
    let c = 0
    call clock.start()
    while empty(c)
      let c = getchar(0)
      if clock.started && clock.elapsed() > a:duration
        break
      endif
      sleep 20m
    endwhile
  finally
    call a:highlight.quench()
    call clock.stop()
  endtry

  if c == 0
    let c = ''
  else
    let c = type(c) == s:TYPE_NUM ? nr2char(c) : c
  endif

  return c
endfunction "}}}


function! s:shift_options() abort "{{{
  let options = {}

  """ tweak appearance
  " hide_cursor
  if s:HAS_GUI_RUNNING
    let options.cursor = &guicursor
    set guicursor+=a:block-NONE
  else
    let options.cursor = &t_ve
    set t_ve=
  endif

  return options
endfunction "}}}


function! s:restore_options(options) abort "{{{
  if s:HAS_GUI_RUNNING
    set guicursor&
    let &guicursor = a:options.cursor
  else
    let &t_ve = a:options.cursor
  endif
endfunction "}}}


function! s:get(name, default) abort  "{{{
  let identifier = 'highlightedyank_' . a:name
  return get(b:, identifier, get(g:, identifier, a:default))
endfunction "}}}


function! s:is_ahead(pos1, pos2) abort  "{{{
  return a:pos1[1] > a:pos2[1] || (a:pos1[1] == a:pos2[1] && a:pos1[2] > a:pos2[2])
endfunction "}}}


function! s:is_extended() abort "{{{
  " NOTE: This function should be used only when you are sure that the
  "       keymapping is used in visual mode.
  normal! gv
  let extended = winsaveview().curswant == s:MAXCOL
  execute "normal! \<Esc>"
  return extended
endfunction "}}}


function! s:visualmode2motionwise(visualmode) abort "{{{
  if a:visualmode ==# 'v'
    let motionwise = 'char'
  elseif a:visualmode ==# 'V'
    let motionwise = 'line'
  elseif a:visualmode[0] ==# "\<C-v>"
    let motionwise = 'block'
  else
    let motionwise = a:visualmode
  endif
  return motionwise
endfunction "}}}


function! s:motionwise2visualmode(motionwise) abort "{{{
  if a:motionwise ==# 'char'
    let visualmode = 'v'
  elseif a:motionwise ==# 'line'
    let visualmode = 'V'
  elseif a:motionwise[0] ==# 'block'
    let visualmode = "\<C-v>"
  else
    let visualmode = a:motionwise
  endif
  return visualmode
endfunction "}}}

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
