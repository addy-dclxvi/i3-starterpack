let s:Schedule = vital#highlightedyank#new().import('Schedule')
                  \.augroup('highlightedyank-highlight')
let s:NULLPOS = [0, 0, 0, 0]
let s:MAXCOL = 2147483647
let s:ON = 1
let s:OFF = 0


" Return a new highlight object
" Return a empty dictionary if the assigned region is empty
function! highlightedyank#highlight#new(hi_group, start, end, type) abort  "{{{
  let order_list = []
  if a:type is# 'char' || a:type is# 'v'
    let order_list += s:get_order_charwise(a:start, a:end)
  elseif a:type is# 'line' || a:type is# 'V'
    let order_list += s:get_order_linewise(a:start, a:end)
  elseif a:type is# 'block' || a:type[0] is# "\<C-v>"
    let blockwidth = s:get_blockwidth(a:start, a:end, a:type)
    let order_list += s:get_order_blockwise(a:start, a:end, blockwidth)
  endif
  if empty(order_list)
    return {}
  endif

  let highlight = deepcopy(s:highlight)
  let highlight.group = a:hi_group
  let highlight.order_list = order_list
  let highlight.quenchtask = s:Schedule.Task()
  let highlight.switchtask = s:Schedule.Task()
  return highlight
endfunction "}}}


" Add a highlight on the current buffer
function! highlightedyank#highlight#add(hi_group, start, end, type, duration) abort "{{{
  let new_highlight = highlightedyank#highlight#new(a:hi_group, a:start,
                                                  \ a:end, a:type)
  if empty(new_highlight)
    return
  endif

  call s:current_highlight.delete()
  call new_highlight.add(a:duration)
  if new_highlight.status is s:OFF
    return
  endif
  let s:current_highlight = new_highlight
endfunction "}}}


" Delete the current highlight
function! highlightedyank#highlight#delete() abort "{{{
  call s:current_highlight.delete()
endfunction "}}}


function! s:get_order_charwise(start, end) abort  "{{{
  if a:start == s:NULLPOS || a:end == s:NULLPOS || s:is_ahead(a:start, a:end)
    return []
  endif
  if a:start[1] == a:end[1]
    let order = [a:start[1:2] + [a:end[2] - a:start[2] + 1]]
    return [order]
  endif

  let order = []
  let order_list = []
  let n = 0
  for lnum in range(a:start[1], a:end[1])
    if lnum == a:start[1]
      let order += [a:start[1:2] + [col([a:start[1], '$']) - a:start[2] + 1]]
    elseif lnum == a:end[1]
      let order += [[a:end[1], 1] + [a:end[2]]]
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


function! s:get_order_linewise(start, end) abort  "{{{
  if a:start == s:NULLPOS || a:end == s:NULLPOS || a:start[1] > a:end[1]
    return []
  endif

  let order = []
  let order_list = []
  let n = 0
  for lnum in range(a:start[1], a:end[1])
    let order += [lnum]
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


function! s:get_order_blockwise(start, end, blockwidth) abort "{{{
  if a:start == s:NULLPOS || a:end == s:NULLPOS || s:is_ahead(a:start, a:end)
    return []
  endif

  let view = winsaveview()
  let vcol_head = virtcol(a:start[1:2])
  if a:blockwidth == s:MAXCOL
    let vcol_tail = a:blockwidth
  else
    let vcol_tail = vcol_head + a:blockwidth - 1
  endif
  let order = []
  let order_list = []
  let n = 0
  for lnum in range(a:start[1], a:end[1])
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


function! s:get_blockwidth(start, end, type) abort "{{{
  if a:type[0] is# "\<C-v>" && a:type[1:] =~# '\d\+'
    return str2nr(a:type[1:])
  endif
  return virtcol(a:end[1:2]) - virtcol(a:start[1:2]) + 1
endfunction "}}}


function! s:is_ahead(pos1, pos2) abort  "{{{
  return a:pos1[1] > a:pos2[1] || (a:pos1[1] == a:pos2[1] && a:pos1[2] > a:pos2[2])
endfunction "}}}


" Highlight object {{{
let s:highlight = {
  \   'status': s:OFF,
  \   'group': '',
  \   'id': [],
  \   'order_list': [],
  \   'bufnr': 0,
  \   'winid': 0,
  \   'quenchtask': {},
  \   'switchtask': {},
  \ }


" Start to show the highlight
function! s:highlight.add(...) dict abort "{{{
  let duration = get(a:000, 0, -1)
  if duration == 0
    return
  end
  if empty(self.order_list)
    return
  endif

  call self.delete()
  for order in self.order_list
    let self.id += [matchaddpos(self.group, order)]
  endfor
  call filter(self.id, 'v:val > 0')
  let self.status = s:ON
  let self.bufnr = bufnr('%')
  let self.winid = win_getid()
  call self.switchtask.call(self.switch, [], self)
                     \.repeat(1)
                     \.waitfor(['BufEnter'])
  let triggers = [['BufUnload', '<buffer>'], ['CmdwinLeave', '<buffer>'],
               \  ['TextChanged', '*'], ['InsertEnter', '*'],
               \  ['TabLeave', '*']]
  if duration > 0
    call add(triggers, duration)
  endif
  call self.quenchtask.call(self.delete, [], self)
                     \.repeat(1)
                     \.waitfor(triggers)

  if !has('patch-8.0.1476') && has('patch-8.0.1449')
    redraw
  endif
endfunction "}}}


" Delete the highlight
function! s:highlight.delete() dict abort "{{{
  if self.status is s:OFF
    return 0
  endif
  if !self.is_in_highlight_window()
    if s:is_in_cmdline_window() || s:is_in_popup_terminal_window()
      " NOTE: cannot move out from commandline-window
      " NOTE: cannot move out from popup terminal window
      call self._quench_by_event('WinEnter')
      return 0
    endif
  endif

  call self._quench_now()
  let self.status = s:OFF
  let self.bufnr = 0
  let self.winid = 0
  call self.switchtask.cancel()
  call self.quenchtask.cancel()
  if !has('patch-8.0.1476') && has('patch-8.0.1449')
    redraw
  endif
  return 1
endfunction "}}}


function! s:highlight.is_in_highlight_window() abort "{{{
  return win_getid() == self.winid
endfunction "}}}


function! s:highlight._quench_now() abort "{{{
  if self.is_in_highlight_window()
    " current window
    call s:matchdelete_all(self.id)
  else
    " move to another window
    let original_winid = win_getid()
    let view = winsaveview()

    noautocmd let reached = win_gotoid(self.winid)
    if reached
      " reached to the highlighted buffer
      call s:matchdelete_all(self.id)
    else
      " highlighted buffer does not exist
      call filter(self.id, 0)
    endif
    noautocmd call win_gotoid(original_winid)
    call winrestview(view)
  endif
endfunction "}}}


function! s:highlight._quench_by_event(event) abort "{{{
  let quenchtask = s:Schedule.TaskChain()
  call quenchtask.hook([a:event])
  call quenchtask.hook([1]).call(self.delete, [], self)
  call quenchtask.waitfor()
endfunction "}}}


function! s:is_in_cmdline_window() abort "{{{
  return getcmdwintype() isnot# ''
endfunction "}}}


" function! s:is_in_popup_terminal_window() abort   {{{
if exists('*popup_list')
  function! s:is_in_popup_terminal_window() abort
    return &buftype is# 'terminal' && count(popup_list(), win_getid())
  endfunction
else
  function! s:is_in_popup_terminal_window() abort
    return 0
  endfunction
endif
" }}}


" Quench if buffer is switched in the same window
function! s:highlight.switch() abort "{{{
  if win_getid() != self.winid
    return
  endif
  if bufnr('%') == self.bufnr
    return
  endif
  call self.delete()
endfunction "}}}


function! s:matchdelete_all(ids) abort "{{{
  if empty(a:ids)
    return
  endif

  let alive_ids = map(getmatches(), 'v:val.id')
  " Return if another plugin called clearmatches() which clears *ALL*
  " highlights including others set.
  if empty(alive_ids)
    return
  endif
  if !count(alive_ids, a:ids[0])
    return
  endif

  for id in a:ids
    try
      call matchdelete(id)
    catch
    endtry
  endfor
  call filter(a:ids, 0)
endfunction "}}}
"}}}


let s:current_highlight = highlightedyank#highlight#new('None', [0, 1, 1, 0],
                                                      \ [0, 1, 1, 0], 'V')


" vim:set foldmethod=marker:
" vim:set commentstring="%s:
" vim:set ts=2 sts=2 sw=2:
