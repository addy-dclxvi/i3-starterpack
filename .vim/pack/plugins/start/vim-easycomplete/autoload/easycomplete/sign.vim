" params 信息的缓存
" key 是buf 绝对路径 /User/bachi/ttt...
let g:easycomplete_diagnostics_cache = {}
let g:easycomplete_diagnostics_hint = 1
let g:easycomplete_diagnostics_popup = 0
" 用作显示的单行文本，只是字符串
let g:easycomplete_diagnostics_last_msg= ""
" lint所需的全部完整文本，多行的话就是数组
let g:easycomplete_diagnostics_last_popup = ""
" 上一次 lint 所在的行号
let g:easycomplete_diagnostics_last_ln = 0
let s:lua_toolkit = g:env_is_nvim ? v:lua.require("easycomplete") : v:null

let s:error_text       = get(g:easycomplete_sign_text, "error", ">>")
let s:waring_text      = get(g:easycomplete_sign_text, "warning", ">>")
let s:infermation_text = get(g:easycomplete_sign_text, "information", "M")
let s:hint_text        = get(g:easycomplete_sign_text, "hint", "H")

let s:lint_popup_timer = 0

let g:easycomplete_diagnostics_config = {
      \ 'error':
      \ {'type': 1, 'prompt_text': s:error_text,      'fg_color': easycomplete#util#IsGui() ? easycomplete#ui#DiagColor("error") : 'red'   , "hl": 'ErrorMsg'},
      \ 'warning':
      \ {'type': 2, 'prompt_text': s:waring_text,     'fg_color': easycomplete#util#IsGui() ? easycomplete#ui#DiagColor("warning") : 'yellow', "hl": 'WarningMsg'},
      \ 'information':
      \ {'type': 3, 'prompt_text': s:infermation_text,'fg_color': easycomplete#util#IsGui() ? easycomplete#ui#DiagColor("information") : '85'    , "hl": 'Pmenu'},
      \ 'hint':
      \ {'type': 4, 'prompt_text': s:hint_text,       'fg_color': easycomplete#util#IsGui() ? easycomplete#ui#DiagColor("hint") : '99'    , "hl": 'Pmenu'}
      \ }

function! easycomplete#sign#test()
  let fn = easycomplete#util#TrimFileName(easycomplete#util#GetCurrentFullName())
  let res = {'method': 'textDocument/publishDiagnostics',
        \ 'jsonrpc': '2.0',
        \ 'params': {
        \    'uri': 'file://' . fn,
        \    'diagnostics': [
        \      {'source': 'vimlsp', 'message': 'E492: 1', 'severity': 1, 'sortNumber': 2001,
        \       'range': {
        \         'end': {'character': 1, 'line': 1},
        \          'start': {'character': 0, 'line': 1}
        \        },
        \      },
        \      {'source': 'vimlsp', 'message': 'E492: 1', 'severity': 2, 'sortNumber': 3001,
        \       'range': {
        \         'end': {'character': 1, 'line': 2},
        \          'start': {'character': 0, 'line': 2}
        \        },
        \      },
        \      {'source': 'vimlsp', 'message': 'E492: 1', 'severity': 3, 'sortNumber': 4001,
        \       'range': {
        \         'end': {'character': 1, 'line': 3},
        \          'start': {'character': 0, 'line': 3}
        \        },
        \      },
        \      {'source': 'vimlsp', 'message': 'E492: 1', 'severity': 4, 'sortNumber': 5001,
        \       'range': {
        \         'end': {'character': 1, 'line': 4},
        \          'start': {'character': 0, 'line': 4}
        \        },
        \      },
        \    ]
        \  }
        \ }
  call easycomplete#sign#flush()
  call easycomplete#sign#cache(res)
  call easycomplete#sign#render()
endfunction

function! easycomplete#sign#GetStyle(msg_type)
  return {
        \ 'TextStyle': toupper(a:msg_type[0]) . tolower(a:msg_type[1:]) . 'TextStyle',
        \ 'LineStyle': toupper(a:msg_type[0]) . tolower(a:msg_type[1:]) . 'LineStyle',
        \ }
endfunction

function! easycomplete#sign#DiagHoverFlush()
  if easycomplete#ok('g:easycomplete_diagnostics_hover')
    if g:easycomplete_diagnostics_popup == 1
      call easycomplete#popup#close("float")
      let g:easycomplete_diagnostics_popup = 0
    endif
  endif
  let g:easycomplete_diagnostics_last_ln = 0
  if exists("b:easycomplete_echo_lint_msg") && b:easycomplete_echo_lint_msg == 1
    " 有 lint msg 的残留则清空，否则不应该做动作
    echo ""
    let b:easycomplete_echo_lint_msg = 0
  endif
endfunction

" 只清空当前buf的diagnostics
function! easycomplete#sign#flush()
  " call easycomplete#sign#DiagHoverFlush()
  if !exists("g:easycomplete_diagnostics_cache")
    let g:easycomplete_diagnostics_cache = {}
  endif
  if empty(get(g:easycomplete_diagnostics_cache, easycomplete#util#GetCurrentFullName(), {}))
    let g:easycomplete_diagnostics_cache[easycomplete#util#GetCurrentFullName()] = {}
    return
  endif
  let server_info = easycomplete#util#FindLspServers()
  if get(g:, 'easycomplete_sources_ts', 0) != 1 && empty(server_info['server_names'])
    return
  endif
  let g:easycomplete_diagnostics_cache[easycomplete#util#GetCurrentFullName()] = {}
endfunction

function! easycomplete#sign#ClearSign()
  " let lsp_server = server_info['server_names'][0]
  " file:///...
  try
    exec "sign unplace * group=g999 file=" . expand("%:p")
  catch
  endtry
endfunction

function! easycomplete#sign#normalize(opt_config)
  let opt = a:opt_config
  for key in keys(opt)
    let styles = easycomplete#sign#GetStyle(key)
    call extend(opt[key], styles)
  endfor
  return opt
endfunction

function! easycomplete#sign#init()
  if !exists("g:easycomplete_diagnostics_cache")
    let g:easycomplete_diagnostics_cache = {}
    let g:easycomplete_diagnostics_cache[easycomplete#util#GetCurrentFullName()] = {}
  endif
  let opt = easycomplete#sign#normalize(g:easycomplete_diagnostics_config)
  let sign_column_bg = easycomplete#ui#GetBgColor('SignColumn')
  let normal_bg = easycomplete#ui#GetBgColor('Normal')
  for key in keys(opt)
    let sign_cmd = ['sign',
          \ 'define',
          \ key . '_holder',
          \ 'text=' . opt[key].prompt_text,
          \ 'texthl=' . opt[key].TextStyle,
          \ ]
          " fix for #117
          " \ 'linehl=' . opt[key].LineStyle
    exec join(sign_cmd, " ")
    call easycomplete#ui#hi(opt[key].TextStyle, opt[key]['fg_color'], sign_column_bg, "")
    if g:env_is_vim
      call easycomplete#ui#hi(opt[key].LineStyle, -1, normal_bg, "")
    endif
  endfor
  call execute('sign define place_holder text='. opt['error'].prompt_text . ' texthl=PlaceHolder')
  call easycomplete#ui#hi('PlaceHolder', sign_column_bg, sign_column_bg, "")
endfunction

function! easycomplete#sign#next()
  let origin_diagnostics = easycomplete#sign#GetCurrentDiagnostics()
  if easycomplete#sign#DiagnosticsIsEmpty(origin_diagnostics)
    return
  endif
  let diagnostics = easycomplete#sign#ValidDiagnostics(origin_diagnostics)
  let cursor_index_arr = easycomplete#sign#CursorIndex()
  let cursor_index = cursor_index_arr[0]
  let equal_flag = cursor_index_arr[1]
  if len(diagnostics) == 1
    call easycomplete#sign#jump(0)
    return
  endif
  if cursor_index + equal_flag >= len(diagnostics)
    call easycomplete#sign#jump(0)
    return
  endif
  call easycomplete#sign#jump(cursor_index + equal_flag)
endfunction

function! easycomplete#sign#previous()
  let origin_diagnostics = easycomplete#sign#GetCurrentDiagnostics()
  if easycomplete#sign#DiagnosticsIsEmpty(origin_diagnostics)
    return
  endif
  let diagnostics = easycomplete#sign#ValidDiagnostics(origin_diagnostics)
  let cursor_index_arr = easycomplete#sign#CursorIndex()
  let cursor_index = cursor_index_arr[0]
  let equal_flag = cursor_index_arr[1]
  if len(diagnostics) == 1
    call easycomplete#sign#jump(0)
    return
  endif
  if cursor_index == len(diagnostics)
    call easycomplete#sign#jump(len(diagnostics) - 1 - equal_flag)
    return
  endif
  if cursor_index == 0
    call easycomplete#sign#jump(len(diagnostics) - 1)
    return
  endif
  call easycomplete#sign#jump(cursor_index - 1)
endfunction

function! easycomplete#sign#CursorIndex()
  let origin_diagnostics = easycomplete#sign#GetCurrentDiagnostics()
  let diagnostics = easycomplete#sign#ValidDiagnostics(origin_diagnostics)
  let ctx = easycomplete#context()
  let current_line = ctx["lnum"]
  let current_col = ctx["col"]
  let cursor_index = len(diagnostics)
  let equal_flag = 0
  let l:count = 0
  while l:count < len(diagnostics)
    let item = diagnostics[l:count]
    let l:line = get(item, 'range')['start']['line'] + 1
    let l:col = get(item, 'range')['start']['character'] + 1
    if current_line < l:line
      let cursor_index = l:count
      break
    endif
    if current_line == l:line && current_col < l:col
      let cursor_index = l:count
      break
    endif
    if current_line == l:line && current_col  == l:col
      let cursor_index = l:count
      let equal_flag = 1
      break
    endif
    let l:count += 1
  endwhile
  " cursor_index 是光标位置在 diagnostics 里的位置
  return [cursor_index, equal_flag]
endfunction

function! easycomplete#sign#GetSortNumbers()
  let origin_diagnostics = easycomplete#sign#GetCurrentDiagnostics()
  let diagnostics = easycomplete#sign#ValidDiagnostics(origin_diagnostics)
  let arr = []
  let l:count = 0
  while l:count < len(diagnostics)
    call add(arr, diagnostics[l:count]["sortNumber"])
    let l:count += 1
  endwhile
  return arr
endfunction

function! easycomplete#sign#jump(diagnostics_index)
  let diagnostics = easycomplete#sign#GetCurrentDiagnostics()
  let item = diagnostics[a:diagnostics_index]
  let l:line = get(item, 'range')['start']['line'] + 1
  let l:col = get(item, 'range')['start']['character'] + 1
  call cursor(l:line, l:col)
  call easycomplete#sign#LintCurrentLine()
  call easycomplete#sign#DiagHoverFlush()
  call easycomplete#sign#LintPopup()
endfunction

" 返回当前文件所有合法的lint
function! easycomplete#sign#ValidDiagnostics(diagnostics)
  if empty(a:diagnostics)
    return []
  endif
  let bufline = len(getbufline(bufnr(''),1,'$'))
  if bufline == 0
    return []
  endif
  let arr = []
  let l:count = 0
  while l:count < len(a:diagnostics)
    let item = a:diagnostics[l:count]
    if item['range']['start']['line'] + 1 <= bufline
      call add(arr, item)
    endif
    let l:count += 1
  endwhile
  return arr
endfunction

function! easycomplete#sign#DiagnosticsIsEmpty(diagnostics)
  if empty(a:diagnostics)
    return v:true
  endif
  let bufline = len(getbufline(bufnr(''),1,'$'))
  if bufline == 0
    return v:true
  endif
  let flag = v:true
  let l:count = 0
  while l:count < len(a:diagnostics)
    let item = a:diagnostics[l:count]
    if item['range']['start']['line'] + 1 <= bufline
      let flag = v:false
      break
    endif
    let l:count += 1
  endwhile
  return flag
endfunction

function! easycomplete#sign#hold()
  let diagnostics = easycomplete#sign#GetCurrentDiagnostics()
  if easycomplete#sign#DiagnosticsIsEmpty(diagnostics)
    call easycomplete#sign#flush()
    call easycomplete#sign#ClearSign()
  else
    let cache = get(g:easycomplete_diagnostics_cache, easycomplete#util#GetCurrentFullName(), {})
    let uri = cache['params']['uri']
    let fn = easycomplete#util#TrimFileName(uri)
    let file_line_plus_one = len(getbufline(bufnr(''),1,'$')) + 1
    if get(g:, "easycomplete_place_holder", 0) == 0
      let cmd = "sign place 999 line=" . file_line_plus_one . " name=place_holder file=" . fn
      call execute(cmd)
      let g:easycomplete_place_holder = 1
    endif
  endif
endfunction

function! easycomplete#sign#unhold()
  let current_fn = easycomplete#util#GetCurrentFullName()
  if get(g:, "easycomplete_place_holder", 0) == 1
    try
      call execute("sign unplace 999 file=" . current_fn)
    catch
    endtry
  endif
  try
    let sign_placed_list = sign_getplaced(current_fn)
  catch /^Vim\%((\a\+)\)\=:E158/
    let sign_placed_list = []
  endtry
  if empty(sign_placed_list)
    return
  endif
  let sign_list = get(sign_placed_list[0],"signs", [])
  if empty(sign_list)
    return
  endif
  for item in sign_list
    if item['id'] == 999 && item['name'] == 'place_holder'
      call sign_unplace('', {'buffer': bufnr(), "id": 999})
    endif
  endfor
  let g:easycomplete_place_holder = 0
endfunction

" {
"   "method":"textDocument/publishDiagnostics",
"   "jsonrpc":"2.0",
"   "params":{
"     "uri":"file:///Users/bachi/ttt/python.vim",
"     "diagnostics":[
"       {
"         "source":"vimlsp",
"         "message":"E492: Not an editor command: oooo",
"         "severity":1,
"         "range": {
"           "end":{"character":1,"line":8},
"           "start":{"character":0,"line":8}
"         }
"       },
"       {...},
"       ...
"     ]
"   }
" }
function! easycomplete#sign#cache(response)
  let l:key = easycomplete#util#TrimFileName(a:response['params']['uri'])
  let g:easycomplete_diagnostics_cache[l:key] = a:response
  let diagnostics = easycomplete#sign#GetCurrentDiagnostics()
  let diagnostics_result = easycomplete#sign#SetDiagnosticsIndexes(diagnostics)
  " call easycomplete#sign#DiagHoverFlush()
  if !empty(diagnostics_result)
    call sort(diagnostics_result, 'easycomplete#sign#sort')
    let g:easycomplete_diagnostics_cache[l:key]['params']['diagnostics'] = diagnostics_result
    let tmp_diagnostics = g:easycomplete_diagnostics_cache[l:key]['params']['diagnostics']
    let l:tmp_diagnostics_l = g:env_is_nvim ?
          \ s:lua_toolkit.sign_distinct(tmp_diagnostics) : easycomplete#sign#distinct(tmp_diagnostics)
    let g:easycomplete_diagnostics_cache[l:key]['params']['diagnostics'] = l:tmp_diagnostics_l
  endif
endfunction

" param.range.start.line | param.range.start.character => sortNumber
function! easycomplete#sign#SetDiagnosticsIndexes(diagnostics)
  let ret = []
  for item in a:diagnostics
    let decimal_num = str2nr(item['range']['start']['character']) + 1
    let decimal_str = easycomplete#util#fullfill(string(decimal_num))
    let sort_number = join(
                        \ [
                        \ string(item['range']['start']['line'] + 1),
                        \ decimal_str
                        \ ],
                        \ ".")
    let item.sortNumber = float2nr(str2float(sort_number) * 1000)
    call add(ret, item)
  endfor
  return ret
endfunction

function! easycomplete#sign#distinct(diagnostics)
  if empty(a:diagnostics)
    return []
  endif
  let ret = []
  for item in a:diagnostics
    if easycomplete#sign#has(ret, item)
      continue
    else
      call add(ret, item)
    endif
  endfor
  return ret
endfunction

function! easycomplete#sign#has(diagnostics, item)
  let flag = v:false
  for elem in a:diagnostics
    if elem["sortNumber"] == a:item["sortNumber"]
      let flag = v:true
      break
    endif
  endfor
  return flag
endfunction

function! easycomplete#sign#sort(entry1, entry2)
  return get(a:entry1, "sortNumber", 0) - get(a:entry2, "sortNumber", 0)
endfunction

" pass diagnostics response object form lsp
function! easycomplete#sign#render(...)
  let buflinenr = len(getbufline(bufnr(''),1,'$'))
  if exists("a:1")
    call easycomplete#sign#cache(a:1)
  endif
  call easycomplete#sign#hold()
  call easycomplete#sign#ClearSign()
  let diagnostics = easycomplete#sign#GetCurrentDiagnostics()
  if easycomplete#sign#DiagnosticsIsEmpty(diagnostics)
    call easycomplete#sign#unhold()
    call easycomplete#sign#flush()
    call easycomplete#sign#DiagHoverFlush()
    return
  endif
  let current_cache = g:easycomplete_diagnostics_cache[easycomplete#util#GetCurrentFullName()]
  let uri = current_cache['params']['uri']
  let l:count = 1
  while l:count <= len(diagnostics)
    let item = diagnostics[l:count-1]
    let line = item['range']['start']['line'] + 1
    let severity = get(item, "severity", 4)
    if line > buflinenr
      " lsp 有时返回 buf 行数 + 1 行报错，比如提示缺少 endfunction，这里选择直
      " 接丢弃，目前没发现有严重超行显示的报错干扰编程的情况
      let l:count += 1
      continue
      let line = 1
    endif
    " sign place 1 line=10 name=error_holder file=/Users/bachi/ttt/ttt.vim
    let fn = easycomplete#util#TrimFileName(uri)
    let cmd = printf('sign place %s group=g999 line=%s name=%s file=%s',
          \ l:count,
          \ line,
          \ s:GetSignStyle(severity),
          \ fn
          \ )
    call execute(cmd)
    let l:count += 1
    if l:count > 500 | break | endif
  endwhile

  call easycomplete#sign#LintCurrentLine()
  call easycomplete#sign#LintPopup()
  call easycomplete#sign#unhold()
endfunction

function! s:GetSignStyle(severity)
  let style = "hint_holder"
  for k in keys(g:easycomplete_diagnostics_config)
    let item = g:easycomplete_diagnostics_config[k]
    if item["type"] == a:severity
      let style = k . "_holder"
      break
    endif
  endfor
  return style
endfunction

function! s:GetDiagnosticsLastPopup()
  if type(g:easycomplete_diagnostics_last_popup) == type([]) && !empty(g:easycomplete_diagnostics_last_popup)
    return g:easycomplete_diagnostics_last_popup[0]
  else
    return g:easycomplete_diagnostics_last_popup
  endif
endfunction

function! easycomplete#sign#LintPopup()
  if !easycomplete#ok('g:easycomplete_diagnostics_hover')
    call easycomplete#sign#DiagHoverFlush()
    return
  endif
  if easycomplete#util#InsertMode()
    call easycomplete#popup#CloseLintPopup()
    return
  endif
  " if easycomplete#popup#LintPopupVisible()
  "   call easycomplete#popup#CloseLintPopup()
  " endif
  let ctx = easycomplete#context()
  " 换行则先清空
  if g:easycomplete_diagnostics_last_ln != ctx["lnum"]
    call easycomplete#sign#DiagHoverFlush()
  endif
  " 如果当前行没有 lintinfo, 则清空后直接返回
  let diagnostics_info = easycomplete#sign#GetDiagnosticsInfo(ctx["lnum"], ctx["col"])
  if empty(diagnostics_info)
    let diagnostics_info = s:GetDiagnosticsInfoByLine(ctx["lnum"])
    if empty(diagnostics_info)
      call easycomplete#sign#DiagHoverFlush()
      return
    endif
  endif
  " 不是原有的 lintinfo 则先清空
  let g_easycomplete_diagnostics_last_popup = s:GetDiagnosticsLastPopup()
  if g:easycomplete_diagnostics_last_msg != g_easycomplete_diagnostics_last_popup
    call easycomplete#sign#DiagHoverFlush()
  endif
  " call s:StopAsyncRun()
  " call s:AsyncRun(function("s:PopupMsg"), [diagnostics_info], 50)
  if s:lint_popup_timer > 0
    call timer_stop(s:lint_popup_timer)
  endif
  let s:lint_popup_timer = timer_start(10,
        \ { -> easycomplete#util#call(function("s:PopupMsg"), [diagnostics_info, ctx["lnum"]]) })
endfunction

function! s:PopupMsg(diagnostics_info, lnum)
  let s:lint_popup_timer = 0
  if g:easycomplete_diagnostics_hint == 1 && g:easycomplete_diagnostics_popup == 1
    return
  endif
  if line('.') != a:lnum
    return
  endif
  let g:easycomplete_diagnostics_popup = 1
  let msg = get(a:diagnostics_info, 'message', '')
  let msg = split(msg, "\\n")
  let showing = s:LintMsgNormalize(a:diagnostics_info, msg)
  let g:easycomplete_diagnostics_last_popup = showing
  let g:easycomplete_diagnostics_last_ln = a:lnum
  let style = s:GetPopupStyle(a:diagnostics_info["severity"])
  call easycomplete#popup#float(showing, style, 0, "txt", [0,0], 'lint')
endfunction

function! s:GetPopupStyle(severity)
  let style = g:easycomplete_diagnostics_config["hint"]["hl"]
  for k in keys(g:easycomplete_diagnostics_config)
    let item = g:easycomplete_diagnostics_config[k]
    if item["type"] == a:severity
      let style = item["hl"]
      break
    endif
  endfor
  return style
endfunction

function! s:LintMsgNormalize(diagnostics_info, msg)
  " let tmsg = printf('[%s] (%s,%s) ',
  "       \ toupper(get(a:diagnostics_info, 'source', 'lsp')),
  "       \ get(a:diagnostics_info, 'range')['start']['line'] + 1,
  "       \ get(a:diagnostics_info, 'range')['start']['character'] + 1
  "       \ )
  " 语法检查的提示语放在行末，不用那么多冗余信息，格式简化
  let tmsg = "▪ "
  if type(a:msg) == type([])
    let tmsg = tmsg . a:msg[0]
    if len(a:msg) >= 2
      let showing = [tmsg] + a:msg[1:]
    else
      let showing = [tmsg]
    endif
    return showing
  endif
  if type(a:msg) == type('')
    return tmsg . a:msg
  endif
endfunction

" CursorMoved
function! easycomplete#sign#LintCurrentLine()
  if !easycomplete#ok('g:easycomplete_diagnostics_enable')
    call easycomplete#sign#unhold()
    call easycomplete#sign#flush()
    return
  endif
  let current_line = line('.')
  let diagnostics_info = s:GetDiagnosticsInfoByLine(current_line)
  if empty(diagnostics_info) && g:easycomplete_diagnostics_hint == 1
    if g:easycomplete_diagnostics_popup == 1
      call easycomplete#sign#DiagHoverFlush()
    endif
    call easycomplete#nill()
    if strlen(g:easycomplete_diagnostics_last_msg) != 0
      " 模拟 echo '' 的效果
      redraw
    endif
    return
  elseif empty(diagnostics_info)
    call easycomplete#sign#DiagHoverFlush()
    call easycomplete#nill()
    return
  else
    if current_line != g:easycomplete_diagnostics_last_ln
      call easycomplete#sign#DiagHoverFlush()
      call easycomplete#nill()
    endif
    " Use AsyncRun for #91 bugfix
    call s:StopAsyncRun()
    call s:AsyncRun("easycomplete#sign#ShowDiagMsg", [diagnostics_info], 10)
  endif
endfunction

function! easycomplete#sign#ShowDiagMsg(diagnostics_info)
  let g:easycomplete_diagnostics_hint = 1
  let msg = get(a:diagnostics_info, 'message', '')
  let msg = split(msg, "\\n")[0]
  let showing = s:LintMsgNormalize(a:diagnostics_info, msg)
  let g:easycomplete_diagnostics_last_msg = showing

  " offset 的目的是确保不折行
  let offset = 13
  if strlen(showing) > winwidth(winnr()) - offset
    let showing = showing[0:winwidth(winnr()) - offset - 3] . '...'
  endif
  " echo showing
  " echo ""
endfunction

function! easycomplete#sign#GetDiagnosticsInfo(line, colnr)
  let lint_list = easycomplete#sign#GetCurrentDiagnostics()
  let l:count = 0
  let ret = {}
  while l:count < len(lint_list)
    let item = lint_list[l:count]
    let info_line = item.range.start.line + 1
    let info_col_start = item.range.start.character + 1
    let info_col_end= item.range.end.character + 1
    if info_line == a:line && (a:colnr >= info_col_start && a:colnr <= info_col_end)
      let ret = item
      break
    endif
    let l:count += 1
  endwhile
  return ret
endfunction

function! s:GetDiagnosticsInfoByLine(line)
  let lint_list = easycomplete#sign#GetCurrentDiagnostics()
  let l:count = 0
  let ret = {}
  while l:count < len(lint_list)
    let item = lint_list[l:count]
    let info_line = item.range.start.line + 1
    if info_line == a:line
      let ret = item
      break
    endif
    let l:count += 1
  endwhile
  return ret
endfunction

function! easycomplete#sign#GetCurrentDiagnostics()
  if !exists("g:easycomplete_diagnostics_cache")
    return []
  endif
  let cache = get(g:easycomplete_diagnostics_cache, easycomplete#util#GetCurrentFullName(), {})
  if empty(cache)
    return []
  endif
  if len(cache.params.diagnostics) == 0
    return []
  endif
  return cache.params.diagnostics
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! s:AsyncRun(...)
  return call('easycomplete#util#AsyncRun', a:000)
endfunction

function! s:StopAsyncRun(...)
  return call('easycomplete#util#StopAsyncRun', a:000)
endfunction

function! s:trace(...)
  return call('easycomplete#util#trace', a:000)
endfunction
