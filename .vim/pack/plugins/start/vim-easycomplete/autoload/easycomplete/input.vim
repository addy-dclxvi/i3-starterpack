" for rename only
let s:input_winid = 0
let s:input_buf = 0
let s:tempfile = ""
let s:input_width = 50
let s:input_height = 3
let b:Callbag = v:null
let s:old_text = ""
let s:input_title = "New Name:"
let s:win_borderchars = ['─', '│', '─', '│', '┌', '┐', '┘', '└']
let s:current_winid = 0
let s:text_winid = 0 " for nvim only

function! s:InputCallback(...)
  call s:flush()
endfunction

function! s:ResetBuf(buf)
  let buf = a:buf
  call setbufvar(buf, '&signcolumn', 'no')
  call setbufvar(buf, '&filetype', 'none')
  call setbufvar(buf, '&buftype', "nofile")
  try
    call setbufvar(buf, '&bufhidden', 1)
  catch /474/
  endtry
  call setbufvar(buf, '&modifiable', 1)
  call setbufvar(buf, '&buflisted', 0)
  call setbufvar(buf, '&swapfile', 0)
  call setbufvar(buf, '&undolevels', -1)
  call setbufvar(buf, 'easycomplete_enable', 0)
endfunction

function! s:CreateNvimInputWindow(old_text, callback) abort
  let width = s:input_width
  let height = s:input_height
  let screen_pos_row= (win_screenpos(win_getid())[0] - 1)
  let screen_pos_col = (win_screenpos(win_getid())[1] - 1)
  let s:current_winid = win_getid()
  if winline() == winheight(win_getid()) - 1
    let bdr_row_offset = -2
    let txt_row_offset = 0
  elseif winline() == winheight(win_getid())
    let bdr_row_offset = 0
    let txt_row_offset = -0
    let screen_pos_row -= 2
  else
    let bdr_row_offset = 0
    let txt_row_offset = 0
  endif
  if wincol() + width > winwidth(win_getid())
    let bdr_col_offset = -1 * (wincol() + width - winwidth(win_getid()))
    let txt_col_offset = 0
  else
    let bdr_col_offset = 0
    let txt_col_offset = 0
  endif
  let opts = {
    \ 'relative':  'editor',
    \ 'row':       screen_pos_row + winline() + bdr_row_offset,
    \ 'col':       screen_pos_col + wincol() + bdr_col_offset,
    \ 'width':     width,
    \ 'height':    height,
    \ 'style':     'minimal',
    \ 'focusable': v:false
    \ }

  let title = s:input_title
  let top = "┌─" . title . repeat("─", width - strlen(title) - 3) . "┐"
  let mid = "│" . repeat(" ", width - 2) . "│"
  let bot = "└" . repeat("─", width - 2) . "┘"

  let lines = [top] + repeat([mid], height - 2) + [bot]
  let border_bufnr = nvim_create_buf(v:false, v:true)
  call nvim_buf_set_lines(border_bufnr, 0, -1, v:true, lines)
  let s:border_winid = nvim_open_win(border_bufnr, v:true, opts)
  let border_window_pos = nvim_win_get_position(s:border_winid)

  let opts.row += (1 + txt_row_offset)
  let opts.height -= 2
  let opts.col += (2 + txt_col_offset)
  let opts.width -= 4
  let opts.focusable = v:true

  let text_bufnr = nvim_create_buf(v:false, v:true)
  call s:ResetBuf(text_bufnr)
  let text_winid = nvim_open_win(text_bufnr, v:true, opts)
  let winhl = "Normal:Pmenu"
  call setwinvar(s:border_winid, '&winhl', winhl)
  call setwinvar(text_winid, '&winhl', winhl)
  call setwinvar(s:border_winid, '&list', 0)
  call setwinvar(s:border_winid, '&number', 0)
  call setwinvar(s:border_winid, '&relativenumber', 0)
  call setwinvar(s:border_winid, '&cursorcolumn', 0)
  call setwinvar(s:border_winid, '&colorcolumn', 0)
  call setwinvar(s:border_winid, '&wrap', 1)
  let s:text_winid = text_winid
  au WinClosed * ++once :q | call easycomplete#input#teardown()
  call easycomplete#util#execute(text_winid, [
        \ 'inoremap <buffer><expr> <CR> easycomplete#input#PromptHandlerCR()',
        \ 'inoremap <buffer><expr> <ESC> easycomplete#input#PromptHandlerESC()',
        \ 'call feedkeys("i","n")'
        \ ])
  return [text_bufnr, text_winid]
endfunction

function! easycomplete#input#teardown()
  call nvim_win_close(s:border_winid, v:true)
endfunction

function! s:CreateVimInputWindow(old_text, callback) abort
  let opt = {
        \ 'filetype':    "txt",
        \ 'col':         'cursor',
        \ 'border':      [1,1,1,1],
        \ 'borderchars': s:win_borderchars,
        \ 'cursorline':  0,
        \ 'maxwidth':    s:input_width,
        \ 'line':        'cursor+1',
        \ 'maxheight':   1,
        \ 'minwidth':    s:input_width,
        \ 'minheight':   1,
        \ 'title':       s:input_title,
        \ 'focusable':   v:true,
        \ 'firstline':   1,
        \ 'fixed':       1,
        \ 'padding':     [0,0,0,0],
        \ }
  let easycomplete_root = easycomplete#util#GetEasyCompleteRootDirectory()
  try
    let buf = term_start("tail -f " . s:CreateBlankFile(), {
            \ 'term_highlight' : 'Pmenu',
            \ 'hidden': 1,
            \ 'term_finish': 'close',
            \ 'exit_cb': function('s:InputCallback')
            \ })
  catch /475/
  endtry

  call s:ResetBuf(buf)
  noa let winid = popup_create(buf, opt)
  call setwinvar(winid, 'autohide', 1)
  call setwinvar(winid, 'float', 1)
  call setwinvar(winid, '&list', 0)
  call setwinvar(winid, '&number', 0)
  call setwinvar(winid, '&relativenumber', 0)
  call setwinvar(winid, '&cursorcolumn', 0)
  call setwinvar(winid, '&colorcolumn', 0)
  call setwinvar(winid, '&wrap', 1)
  call setwinvar(winid, '&linebreak', 1)
  call setwinvar(winid, '&conceallevel', 0)
  call easycomplete#util#execute(winid, [
        \ 'tnoremap <expr> <CR> easycomplete#input#PromptHandlerCR()',
        \ 'tnoremap <expr> <ESC> easycomplete#input#PromptHandlerESC()',
        \ ])

  return [buf, winid]
endfunction

function! easycomplete#input#pop(old_text, callbag)
  if has("nvim")
    let input_obj = s:CreateNvimInputWindow(a:old_text, a:callbag)
  else
    let input_obj = s:CreateVimInputWindow(a:old_text, a:callbag)
  endif
  let s:input_winid = input_obj[1]
  let s:input_buf = input_obj[0]
  let b:Callbag = a:callbag
  let s:old_text = a:old_text
endfunction

function! s:CreateBlankFile()
  let tmpfile = tempname()
  silent! call writefile([""], tmpfile, "a")
  let s:tempfile = tmpfile
  return tmpfile
endfunction

function! s:DeleteBlankFile()
  if empty(s:tempfile) | return | endif
  silent! call delete(s:tempfile)
  let s:tempfile = ""
endfunction

function! easycomplete#input#PromptHandlerCR()
  if has("nvim")
    let new_text_line = get(getbufline(s:input_buf, 1, 1), 0, "")
  else
    let new_text_line = term_getline(s:input_buf, '.',)
  endif
  if empty(new_text_line) || empty(trim(new_text_line))
    call s:log("New text is empty. Nothing will be changed.")
    call s:close()
    return ""
  endif
  let new_text = trim(new_text_line)
  if new_text =~ "\\s"
    call s:close()
    call timer_start(20, { -> s:log("New text should not contains space character.") })
    return ""
  endif
  let Callbag = b:Callbag
  let old_text = s:old_text
  call s:close()
  call timer_start(60, { -> easycomplete#util#call(Callbag, [old_text, new_text]) })
  return ""
endfunction

function! easycomplete#input#PromptHandlerESC()
  call s:close()
  call timer_start(20, { -> easycomplete#util#GotoWindow(s:current_winid) })
  return ""
endfunction

function! s:close()
  if s:input_winid
    if has('nvim')
      call easycomplete#util#execute(s:input_winid, [
            \ "silent noa call feedkeys('\<C-C>')",
            \ "silent noa call feedkeys(':silent! close!\<CR>', 'n')",
            \ ])
    else
      call easycomplete#util#execute(s:input_winid, ["silent noa call feedkeys('\<C-C>')"])
    endif
    let s:input_winid = 0
  endif
endfunction

function! s:flush()
  call s:close()
  call s:DeleteBlankFile()
  let s:input_winid = 0
  let s:input_buf = 0
  let s:old_text = ""
  let b:Callbag = v:null
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! s:get(...)
  return call('easycomplete#util#get', a:000)
endfunction
