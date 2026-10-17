" highlight object - managing highlight on a buffer
let s:HAS_GUI_RUNNING = has('gui_running')
let s:TYPE_LIST = type([])
let s:NULLPOS = [0, 0, 0, 0]
let s:MAXCOL = 2147483647
let s:ON = 1
let s:OFF = 0

" SID
function! s:SID() abort
  return matchstr(expand('<sfile>'), '<SNR>\zs\d\+\ze_SID$')
endfunction
let s:SID = printf("\<SNR>%s_", s:SID())
delfunction s:SID



function! highlightedyank#obsolete#highlight#new(region) abort  "{{{
  let highlight = deepcopy(s:highlight)
  if a:region.wise ==# 'char' || a:region.wise ==# 'v'
    let highlight.order_list = s:highlight_order_charwise(a:region)
  elseif a:region.wise ==# 'line' || a:region.wise ==# 'V'
    let highlight.order_list = s:highlight_order_linewise(a:region)
  elseif a:region.wise ==# 'block' || a:region.wise[0] ==# "\<C-v>"
    let highlight.order_list = s:highlight_order_blockwise(a:region)
  endif
  return highlight
endfunction "}}}


" Highlight class "{{{
let s:highlight = {
  \   'status': s:OFF,
  \   'group': '',
  \   'id': [],
  \   'order_list': [],
  \   'bufnr': 0,
  \   'winid': 0,
  \ }


function! s:highlight.show(...) dict abort "{{{
  if empty(self.order_list)
    return 0
  endif

  if a:0 < 1
    if empty(self.group)
      return 0
    else
      let hi_group = self.group
    endif
  else
    let hi_group = a:1
  endif

  if self.status is s:ON
    if hi_group ==# self.group
      return 0
    else
      call self.quench()
    endif
  endif

  for order in self.order_list
    let self.id += s:matchaddpos(hi_group, order)
  endfor
  call filter(self.id, 'v:val > 0')
  let self.status = s:ON
  let self.group = hi_group
  let self.bufnr = bufnr('%')
  let self.winid = s:win_getid()
  return 1
endfunction "}}}


function! s:highlight.quench() dict abort "{{{
  if self.status is s:OFF
    return 0
  endif

  let winid = s:win_getid()
  let view = winsaveview()
  if s:win_getid() == self.winid
    call map(self.id, 'matchdelete(v:val)')
    call filter(self.id, 'v:val > 0')
    let succeeded = 1
  else
    if s:is_in_cmdline_window()
      let s:paused += [self]
      augroup highlightedyank-pause-quenching
        autocmd!
        autocmd CmdWinLeave * call s:got_out_of_cmdwindow()
      augroup END
      let succeeded = 0
    else
      let reached = s:win_gotoid(self.winid)
      if reached
        call map(self.id, 'matchdelete(v:val)')
        call filter(self.id, 'v:val > 0')
      else
        call filter(self.id, 0)
      endif
      let succeeded = 1
      call s:win_gotoid(winid)
      call winrestview(view)
    endif
  endif

  if succeeded
    let self.status = s:OFF
  endif
  return succeeded
endfunction "}}}


function! s:highlight.quench_timer(time) dict abort "{{{
  let id = timer_start(a:time, s:SID . 'quench')
  let s:quench_table[id] = self
  call s:set_autocmds(id)
  return id
endfunction "}}}


function! s:highlight.persist() dict abort  "{{{
  let id = s:get_pid()
  call s:set_autocmds(id)
  let s:quench_table[id] = self
  return id
endfunction "}}}


function! s:highlight.empty() abort "{{{
  return empty(self.order_list)
endfunction "}}}


" for scheduled-quench "{{{
let s:quench_table = {}
function! s:quench(id) abort  "{{{
  let options = s:shift_options()
  let highlight = s:get(a:id)
  if highlight != {}
    call highlight.quench()
  endif
  unlet s:quench_table[a:id]
  call timer_stop(a:id)
  call s:restore_options(options)
  call s:clear_autocmds()
  redraw
endfunction "}}}


function! highlightedyank#obsolete#highlight#cancel(...) abort "{{{
  if a:0 > 0
    let id_list = type(a:1) == s:TYPE_LIST ? a:1 : a:000
  else
    let id_list = map(keys(s:quench_table), 'str2nr(v:val)')
  endif

  for id in id_list
    call s:quench(id)
  endfor
endfunction "}}}


function! s:get(id) abort "{{{
  return get(s:quench_table, a:id, {})
endfunction "}}}


let s:paused = []
function! s:quench_paused(...) abort "{{{
  if s:is_in_cmdline_window()
    return
  endif

  for highlight in s:paused
    call highlight.quench()
  endfor
  let s:paused = []
  augroup highlightedyank-pause-quenching
    autocmd!
  augroup END
endfunction "}}}


function! s:got_out_of_cmdwindow() abort "{{{
  augroup highlightedyank-pause-quenching
    autocmd!
    autocmd CursorMoved * call s:quench_paused()
  augroup END
endfunction "}}}


" ID for persistent highlights
let s:pid = 0
function! s:get_pid() abort "{{{
  if s:pid != -1/0
    let s:pid -= 1
  else
    let s:pid = -1
  endif
  return s:pid
endfunction "}}}


function! s:set_autocmds(id) abort "{{{
  augroup highlightedyank-highlight
    autocmd!
    execute printf('autocmd TextChanged <buffer> call s:cancel_highlight(%s, "TextChanged")', a:id)
    execute printf('autocmd InsertEnter <buffer> call s:cancel_highlight(%s, "InsertEnter")', a:id)
    execute printf('autocmd BufUnload <buffer> call s:cancel_highlight(%s, "BufUnload")', a:id)
    execute printf('autocmd BufEnter * call s:switch_highlight(%s)', a:id)
  augroup END
endfunction "}}}


function! s:clear_autocmds() abort "{{{
  augroup highlightedyank-highlight
    autocmd!
  augroup END
endfunction "}}}


function! s:cancel_highlight(id, event) abort  "{{{
  let highlight = s:get(a:id)
  if highlight != {}
    call s:quench(a:id)
  endif
endfunction "}}}


function! s:switch_highlight(id) abort "{{{
  let highlight = s:get(a:id)
  if highlight != {} && highlight.winid == s:win_getid()
    if highlight.bufnr == bufnr('%')
      call highlight.show()
    else
      call highlight.quench()
    endif
  endif
endfunction "}}}
"}}}
"}}}



" private functions
function! s:highlight_order_charwise(region) abort  "{{{
  if a:region.head == s:NULLPOS || a:region.tail == s:NULLPOS || s:is_ahead(a:region.head, a:region.tail)
    return []
  endif
  if a:region.head[1] == a:region.tail[1]
    let order = [a:region.head[1:2] + [a:region.tail[2] - a:region.head[2] + 1]]
    return [order]
  endif

  let order = []
  let order_list = []
  let n = 0
  for lnum in range(a:region.head[1], a:region.tail[1])
    if lnum == a:region.head[1]
      let order += [a:region.head[1:2] + [col([a:region.head[1], '$']) - a:region.head[2] + 1]]
    elseif lnum == a:region.tail[1]
      let order += [[a:region.tail[1], 1] + [a:region.tail[2]]]
    else
      let order += [[lnum]]
    endif

    if n == 7
      let order_list += [order]
      let order = []
      let n = 0
    else
      let n += 1
    endif
  endfor
  if order != []
    let order_list += [order]
  endif
  return order_list
endfunction "}}}


function! s:highlight_order_linewise(region) abort  "{{{
  if a:region.head == s:NULLPOS || a:region.tail == s:NULLPOS || a:region.head[1] > a:region.tail[1]
    return []
  endif

  let order = []
  let order_list = []
  let n = 0
  for lnum in range(a:region.head[1], a:region.tail[1])
    let order += [[lnum]]
    if n == 7
      let order_list += [order]
      let order = []
      let n = 0
    else
      let n += 1
    endif
  endfor
  if order != []
    let order_list += [order]
  endif
  return order_list
endfunction "}}}


function! s:highlight_order_blockwise(region) abort "{{{
  if a:region.head == s:NULLPOS || a:region.tail == s:NULLPOS || s:is_ahead(a:region.head, a:region.tail)
    return []
  endif

  let view = winsaveview()
  let vcol_head = virtcol(a:region.head[1:2])
  if a:region.blockwidth == s:MAXCOL
    let vcol_tail = a:region.blockwidth
  else
    let vcol_tail = vcol_head + a:region.blockwidth - 1
  endif
  let order = []
  let order_list = []
  let n = 0
  for lnum in range(a:region.head[1], a:region.tail[1])
    call cursor(lnum, 1)
    execute printf('normal! %s|', vcol_head)
    let head = getpos('.')
    execute printf('normal! %s|', vcol_tail)
    let tail = getpos('.')
    let col = head[2]
    let len = tail[2] - head[2] + 1
    let order += [[lnum, col, len]]

    if n == 7
      let order_list += [order]
      let order = []
      let n = 0
    else
      let n += 1
    endif
  endfor
  if order != []
    let order_list += [order]
  endif
  call winrestview(view)
  return order_list
endfunction "}}}


" function! s:matchaddpos(group, pos) abort "{{{
if exists('*matchaddpos')
  function! s:matchaddpos(group, pos) abort
    return [matchaddpos(a:group, a:pos)]
  endfunction
else
  function! s:matchaddpos(group, pos) abort
    let id_list = []
    for pos in a:pos
      if len(pos) == 1
        let id_list += [matchadd(a:group, printf('\%%%dl', pos[0]))]
      else
        let id_list += [matchadd(a:group, printf('\%%%dl\%%>%dc.*\%%<%dc', pos[0], pos[1]-1, pos[1]+pos[2]))]
      endif
    endfor
    return id_list
  endfunction
endif
"}}}


function! s:is_ahead(pos1, pos2) abort  "{{{
  return a:pos1[1] > a:pos2[1] || (a:pos1[1] == a:pos2[1] && a:pos1[2] > a:pos2[2])
endfunction "}}}


" function! s:is_in_cmdline_window() abort  "{{{
if exists('*getcmdwintype')
  function! s:is_in_cmdline_window() abort
    return getcmdwintype() !=# ''
  endfunction
else
  function! s:is_in_cmdline_window() abort
    let is_in_cmdline_window = 0
    try
      execute 'tabnext ' . tabpagenr()
    catch /^Vim\%((\a\+)\)\=:E11/
      let is_in_cmdline_window = 1
    catch
    finally
      return is_in_cmdline_window
    endtry
  endfunction
endif
"}}}


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



" for compatibility
" function! s:win_getid(...) abort{{{
if exists('*win_getid')
  let s:win_getid = function('win_getid')
else
  function! s:win_getid(...) abort
    let winnr = get(a:000, 0, winnr())
    let tabnr = get(a:000, 1, tabpagenr())
  endfunction
endif
"}}}


" function! s:win_gotoid(id) abort{{{
if exists('*win_gotoid')
  function! s:win_gotoid(id) abort
    noautocmd let ret = win_gotoid(a:id)
    return ret
  endfunction
else
  function! s:win_gotoid(id) abort
    let [winnr, tabnr] = a:id

    if tabnr != tabpagenr()
      execute 'noautocmd tabnext ' . tabnr
      if tabpagenr() != tabnr
        return 0
      endif
    endif

    try
      if winnr != winnr()
        execute printf('noautocmd %swincmd w', winnr)
      endif
    catch /^Vim\%((\a\+)\)\=:E16/
      return 0
    endtry
    return 1
  endfunction
endif
"}}}

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
