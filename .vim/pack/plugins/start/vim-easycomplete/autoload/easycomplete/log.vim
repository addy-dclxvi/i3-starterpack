" Log easycomplete#log#log() authored by jayli bachi@taobao.com
" Useage
"   - Command
"     - Log {stn} : show low at window
"     - CleanLog  : Clean the log window
"     - CloseLog  : Close the log window
"   - API
"     - log#log(...): print logs
"   - Global config
"     - g:vim_log_enabled = 1   enable log at side window
"     - g:vim_log_enabled = 0   disable log printing

function! easycomplete#log#init()
  call s:InitCommand()
endfunction

function! s:InitVars()
  if !exists("g:easycomplete_debugger")
    let g:easycomplete_debugger = {}
  endif
  let g:easycomplete_debugger = {}
  let g:easycomplete_debugger.log_bufinfo = 0
  let g:easycomplete_debugger.log_winid = 0
  let g:easycomplete_debugger.log_winnr = 0
  let g:easycomplete_debugger.log_bufnr = 0
  let g:easycomplete_debugger.log_term_winid = 0
  let g:easycomplete_debugger.status = 'stop'
endfunction

function! s:InitCommand()
  if exists("g:easycomplete_debugger")
    return
  endif
  if easycomplete#util#IsTerminal()
    return
  endif
  let g:easycomplete_debugger = {}
  let g:easycomplete_debugger.logfile = 0
  let g:easycomplete_debugger.status = 'stop'
  let g:easycomplete_debugger.original_winnr = winnr()
  let g:easycomplete_debugger.original_bufinfo = getbufinfo(bufnr(''))
  let g:easycomplete_debugger.original_winid = bufwinid(bufnr(""))
  let g:easycomplete_debugger.init_msg = [
        \ "  ┄┄┄┄┄┄┄  Log Window ┄┄┄┄┄┄┄",
        \ "┌────────────────────────────────────┐",
        \ "│   Use <C-C> to close log window.   │",
        \ "│ Authored by Jayli bachi@taobao.com │",
        \ "└────────────────────────────────────┘"]
  call s:flush()
  augroup easycomplete#logging
    autocmd!
    autocmd QuitPre * call easycomplete#log#quit()
  augroup END

  command! -nargs=? CleanLog call easycomplete#log#clean()
  command! -nargs=? CloseLog call easycomplete#log#close()
  command! -nargs=1 Log call easycomplete#log#log(<args>)
endfunction

" 多参数适配
function! easycomplete#log#log(...)
  if easycomplete#util#IsTerminal()
    return
  endif

  if !exists("g:easycomplete_debugger")
    call s:InitVars()
  endif

  " log debug 窗口改为了默认直接看文件了
  if easycomplete#log#running()
    " return call('easycomplete#log#log', a:000)
  else
    return call('easycomplete#util#debug', a:000)
  endif

  if !exists('g:vim_log_enabled')
    let g:vim_log_enabled = 1
  endif
  call s:InitCommand()
  if s:LogRunning()
    " do nothing
  else
    call s:flush()
  endif
  if g:vim_log_enabled != 1
    return
  endif
  let l:res = call('easycomplete#util#NormalizeLogMsg', a:000)
  if executable('tail')
    call s:InitLogFile()
    call s:InitLogWindow()
    call s:AppendLog(l:res)
    call s:GotoBottom()
  else
    call call(s:log, a:000)
  endif
  call s:GotoOriginalWindow()
  redraw
endfunction

function! s:GotoBottom()
  try
    let line_nr = getbufinfo(g:easycomplete_debugger.log_bufnr)[0]['linecount']
    call easycomplete#util#execute(g:easycomplete_debugger.log_winid, 'call cursor('.line_nr.',0)')
  catch
    echom v:exception
  endtry
endfunction

function! s:flush()
  let g:easycomplete_debugger.log_bufinfo = 0
  let g:easycomplete_debugger.log_winid = 0
  let g:easycomplete_debugger.log_winnr = 0
  let g:easycomplete_debugger.log_bufnr = 0
  let g:easycomplete_debugger.log_term_winid = 0
  let g:easycomplete_debugger.status = 'stop'
  let g:easycomplete_debugger.job_id = 0
endfunction

function! easycomplete#log#running()
  if g:easycomplete_debugger.log_winid == 0
    return v:false
  else
    return v:true
  endif
endfunction

function! s:LogRunning()
  let window_status = g:easycomplete_debugger.log_winid == 0 ? v:false : v:true
  let job_status = v:false
  if has('nvim')
    try
      let job_pid = jobpid(g:easycomplete_debugger.job_id)
    catch /E900/
      let job_pid = 0
    endtry
    let job_status = (job_pid != 0)
  else
    let job_status = (term_getstatus(g:easycomplete_debugger.log_bufnr) == "running")
  endif
  return job_status && window_status == v:true
endfunction

function! s:InitLogWindow()
  if s:LogRunning()
    return
  endif
  if g:easycomplete_debugger.original_winid != bufwinid(bufnr(""))
    return
  endif
  " 不加这一句进入新 buf 时会开一个新的 log 窗口
  call easycomplete#util#info("Log Window Checking...")
  let g:easycomplete_debugger.original_bufinfo = getbufinfo(bufnr(''))
  let g:easycomplete_debugger.original_winid = bufwinid(bufnr(""))
  if (getbufinfo(bufnr(''))[0]["name"] =~ "debuger=1")
    return
  endif
  vertical botright new filetype=help buftype=nofile debuger=1
  setlocal nonu
  let g:easycomplete_debugger.status = "running"
  if !has("nvim")
    let g:easycomplete_debugger.job_id = term_start("tail -n 100 -f " . get(g:easycomplete_debugger, 'logfile'),{
        \ 'term_finish': 'close',
        \ 'term_name':'log_debugger_window_name',
        \ 'vertical':'1',
        \ 'curwin':'1',
        \ 'exit_cb': function('s:LogCallback')
        \ })
  else
    let g:easycomplete_debugger.job_id = termopen("tail -n 100 -f " . get(g:easycomplete_debugger, 'logfile'),{
        \ 'term_finish': 'close',
        \ 'term_name':'log_debugger_window_name',
        \ 'vertical':'1',
        \ 'curwin':'1',
        \ 'exit_cb': function('s:LogCallback')
        \ })
  endif
  exec 'setl statusline=%1*\ Normal\ %*%5*\ Log\ Window\ %*\ %r%f[%M]%=Depth\ :\ %L\ '
  let g:easycomplete_debugger.log_term_winid = bufwinid('log_debugger_window_name')
  let g:easycomplete_debugger.log_winnr = winnr()
  let g:easycomplete_debugger.log_bufinfo = getbufinfo(bufnr(''))
  let g:easycomplete_debugger.log_bufnr = bufnr("")
  let g:easycomplete_debugger.log_winid = bufwinid(bufnr(""))
  call s:AppendLog(copy(get(g:easycomplete_debugger, 'init_msg')))
  call s:GotoOriginalWindow()
endfunction

function! s:LogCallback(...)
  call s:flush()
endfunction

function! s:EmptyLogWindow()
  call s:CloseLogWindow()
  call s:DelLogFile()
  call s:flush()
  call easycomplete#log#log()
endfunction

function! easycomplete#log#clean()
  if s:LogRunning()
    call s:EmptyLogWindow()
  endif
  cclose
endfunction

function! easycomplete#log#close()
  if s:LogRunning()
    call s:CloseLogWindow()
  endif
  cclose
endfunction

function! easycomplete#log#quit()
  if get(g:easycomplete_debugger, 'log_winid') == bufwinid(bufnr(""))
    if !has("nvim")
      call term_sendkeys("log_debugger_window_name","\<C-C>")
    else
      call feedkeys("\<C-C>", "t")
    endif
  endif
  if get(g:easycomplete_debugger, 'original_winid') == bufwinid(bufnr(""))
    if s:LogRunning()
      call s:CloseLogWindow()
      call feedkeys("\<S-ZZ>")
    endif
  endif
  call s:DelLogFile()
  call s:flush()
endfunction

function! s:CloseLogWindow()
  if s:LogRunning()
    call easycomplete#util#execute(g:easycomplete_debugger.log_winid, ["q!"])
    call s:flush()
  endif
endfunction

function! s:AppendLog(content)
  if empty(a:content)
    return
  endif

  if type(a:content) == type([])
    let l:content = a:content
  else
    let l:content = [a:content]
  endif
  let t_content = s:SplitContent(l:content)
  let l:content = t_content
  call map(l:content, { key, val -> key == 0 ? '>>> ' . val : val})
  if s:LogRunning()
    let l:logfile = get(g:easycomplete_debugger, "logfile")
    call writefile(l:content, l:logfile, "Sa")
  endif
endfunction

function! s:InitLogFile()
  let l:logfile = get(g:easycomplete_debugger, 'logfile')
  if !empty(l:logfile)
    return l:logfile
  endif
  let g:easycomplete_debugger.logfile = tempname()
  call writefile([""], g:easycomplete_debugger.logfile, "a")
  return g:easycomplete_debugger.logfile
endfunction

function! s:SplitContent(content)
  let res_arr = []
  if type(a:content) == type("")
    let res_arr = split(a:content, "\n")
    return res_arr
  endif
  if type(a:content) == type([])
    let res_arr = []
    for item in a:content
      let res_arr += s:SplitContent(item)
    endfor
    return res_arr
  endif
  return a:content
endfunction

function! s:DelLogFile()
  let l:logfile = get(g:easycomplete_debugger, 'logfile')
  if !empty(l:logfile)
    call delete(l:logfile)
    let g:easycomplete_debugger.logfile = 0
  endif
endfunction

function! s:GotoWindow(...)
  return call('easycomplete#util#GotoWindow', a:000)
endfunction

function! s:GotoOriginalWindow()
  call s:GotoWindow(g:easycomplete_debugger.original_winid)
endfunction

function! s:GotoLogWindow()
  call s:GotoWindow(g:easycomplete_debugger.log_term_winid)
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! s:AsyncRun(...)
  return call('easycomplete#util#AsyncRun', a:000)
endfunction
