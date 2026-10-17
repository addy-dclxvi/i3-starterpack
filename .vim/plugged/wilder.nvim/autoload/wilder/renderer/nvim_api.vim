let s:index = 0

function! wilder#renderer#nvim_api#() abort
  let l:state = {
        \ 'buf': -1,
        \ 'dummy_buf': -1,
        \ 'win': -1,
        \ 'ns_id': nvim_create_namespace(''),
        \ 'normal_highlight': 'Normal',
        \ 'pumblend': -1,
        \ 'zindex': 0,
        \ 'window_state': 'hidden',
        \ 'dimensions': -1,
        \ 'firstline': -1,
        \ 'options': {},
        \ }

  let l:api = {
        \ 'state': l:state,
        \ }

  for l:f in [
        \ 'new',
        \ 'show',
        \ 'hide',
        \ 'move',
        \ 'set_option',
        \ 'set_firstline',
        \ 'delete_all_lines',
        \ 'set_line',
        \ 'add_highlight',
        \ 'clear_all_highlights',
        \ 'need_timer',
        \ '_open_win',
        \ '_set_buf',
        \ ]
    execute 'let l:api.' . l:f . ' = funcref("s:' . l:f . '")'
  endfor

  return l:api
endfunction

function! s:new(opts) dict abort
  " If the buffer is somehow unloaded, bufload(self.state.buf) doesn't restore
  " it so we have to create a new one
  if !bufexists(self.state.buf) || !bufloaded(self.state.buf)
    let self.state.buf = s:new_buf()
  endif

  if !bufexists(self.state.dummy_buf) || !bufloaded(self.state.dummy_buf)
    let self.state.dummy_buf = s:new_buf()
  endif

  let self.state.normal_highlight = get(a:opts, 'normal_highlight', 'Normal')
  let self.state.pumblend = get(a:opts, 'pumblend', -1)
  let self.state.zindex = get(a:opts, 'zindex', 0)
endfunction

function! s:new_buf() abort
  let l:buf = nvim_create_buf(v:false, v:true)
  call nvim_buf_set_name(l:buf, '[Wilder Float ' . s:index . ']')
  let s:index += 1

  return l:buf
endfunction

function! s:show() dict abort
  if self.state.win != -1 ||
        \ self.state.window_state !=# 'hidden'
    return
  endif

  let self.state.window_state = 'pending'

  try
    call self._open_win()
  catch
    call timer_start(0, {-> self._open_win()})
  endtry
endfunction

function! s:_open_win() dict abort
  " window might have been open or closed already.
  if self.state.window_state !=# 'pending'
    return
  endif

  " Fix E5555 when re-showing wilder when inccommand is cancelled.
  let l:buf = has('nvim-0.6') && !has('nvim-0.7') ? 0 : self.state.buf

  let l:win_opts = {
        \ 'relative': 'editor',
        \ 'height': 1,
        \ 'width': 1,
        \ 'row': &lines - 1,
        \ 'col': 0,
        \ 'focusable': 0,
        \ }

  if has('nvim-0.5.1')
    let l:win_opts.zindex = self.state.zindex
  endif

  let self.state.win = nvim_open_win(l:buf, 0, l:win_opts)

  let self.state.window_state = 'showing'

  if has('nvim-0.6') && !has('nvim-0.7')
    try
      call self._set_buf()
    catch
      call timer_start(0, {-> self._set_buf()})
    endtry
  else
    call nvim_win_set_config(self.state.win, {
          \ 'style': 'minimal',
          \ })
  endif

  call self.set_option('winhighlight',
        \ 'Search:None,IncSearch:None,Normal:' . self.state.normal_highlight)
  if self.state.pumblend != -1
    call self.set_option('winblend', self.state.pumblend)
  else
    call self.set_option('winblend', &pumblend)
  endif

  if self.state.firstline isnot -1
    call nvim_win_set_cursor(self.state.win, [self.state.firstline, 0])
  endif

  if self.state.dimensions isnot -1
    let [l:row, l:col, l:height, l:width] = self.state.dimensions
    call nvim_win_set_config(self.state.win, {
          \ 'relative': 'editor',
          \ 'row': l:row,
          \ 'col': l:col,
          \ 'height': l:height,
          \ 'width': l:width,
          \ })
  endif

  for l:option in keys(self.state.options)
    let l:value = self.state.options[l:option]
    call nvim_win_set_option(self.state.win, l:option, l:value)
  endfor

  let self.state.firstline = -1
  let self.state.dimensions = -1
  let self.state.options = {}
endfunction

function! s:_set_buf() dict abort
  if self.state.window_state !=# 'showing'
    return
  endif

  call nvim_win_set_buf(self.state.win, self.state.buf)
  call nvim_win_set_config(self.state.win, {
        \ 'style': 'minimal',
        \ })
endfunction

" Floating windows can't be hidden so we close the window.
function! s:hide() dict abort
  if self.state.win == -1 ||
        \ self.state.window_state ==# 'hidden'
    return
  endif

  if self.state.window_state ==# 'pending'
    let self.state.win = -1
    let self.state.window_state = 'hidden'
    return
  endif

  if getcmdwintype() ==# ''
    try
      call nvim_win_close(self.state.win, 1)
    catch
      let l:win = self.state.win
      call timer_start(0, {-> nvim_win_close(l:win, 1)})
    endtry
  else
    " cannot call nvim_win_close() while cmdline-window is open
    " make the window as small as possible and hide it with winblend = 100
    let l:win = self.state.win
    call self.delete_all_lines()
    call self.move(&lines, &columns, 1, 1)
    call self.set_option('winblend', 100)
    execute 'autocmd CmdWinLeave * ++once call timer_start(0, {-> nvim_win_close(' . l:win . ', 0)})'
  endif

  let self.state.win = -1
  let self.state.window_state = 'hidden'
endfunction

function! s:move(row, col, height, width) dict abort
  if self.state.window_state ==# 'hidden'
    return
  endif

  if self.state.window_state ==# 'pending'
    let self.state.dimensions = [a:row, a:col, a:height, a:width]
    return
  endif

  call nvim_win_set_config(self.state.win, {
        \ 'relative': 'editor',
        \ 'row': a:row,
        \ 'col': a:col,
        \ 'height': a:height,
        \ 'width': a:width,
        \ })
endfunction

function! s:set_firstline(line) dict abort
  if self.state.window_state ==# 'hidden'
    return
  endif

  if self.state.window_state ==# 'pending'
    let self.state.firstline = a:line
    return
  endif

  call nvim_win_set_cursor(self.state.win, [a:line, 0])
endfunction

function! s:set_option(option, value) dict abort
  if self.state.window_state ==# 'hidden'
    return
  endif

  if self.state.window_state ==# 'pending'
    let self.state.options[a:option] = a:value
    return
  endif

  call nvim_win_set_option(self.state.win, a:option, a:value)
endfunction

function! s:delete_all_lines() dict abort
  call nvim_buf_set_lines(self.state.buf, 0, -1, v:true, [])
endfunction

function! s:set_line(line, str) dict abort
  call nvim_buf_set_lines(self.state.buf, a:line, a:line, v:true, [a:str])
endfunction

function! s:add_highlight(hl, line, col_start, col_end) dict abort
  call nvim_buf_add_highlight(self.state.buf, self.state.ns_id, a:hl, a:line, a:col_start, a:col_end)
endfunction

function! s:clear_all_highlights() dict abort
  if !bufexists(self.state.buf)
    return
  endif

  call nvim_buf_clear_namespace(self.state.buf, self.state.ns_id, 0, -1)
endfunction

function! s:need_timer() dict abort
  if has('nvim-0.7')
    " See https://github.com/neovim/neovim/issues/17810.
    " Avoid calling nvim_buf_set_lines(), so assume timer is always needed.
    return 1
  endif

  try
    call nvim_buf_set_lines(self.state.dummy_buf, 0, -1, v:true, [])
  catch
    return 1
  endtry

  return 0
endfunction
