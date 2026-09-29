let s:tn_job = v:null
let s:ctx = v:null
let s:opt = v:null
let s:tn_name = 'tn'
let s:tn_init_ready = v:false
" TabNine 第一次匹配需要大量算法运算，比较耗时，完成第一次之后速度比较快
let b:module_building = v:false
let s:tn_render_timer = 0
let b:tn_timer_start = 0
let b:tn_timer_end = 0
" tn 运算较慢，为了更快的跟指动作，这里加一个超时，TN返回超时后就直接丢弃结果了
let s:tn_timeout = 30
let s:version = ''
" 只用作空格、等号、逗号这些情况强制触发 Tabnine complete 的标志位
" 0: 触发条件一律遵循 easycomplete#condition() 条件，和 FirstComplete 混合在一
" 起返回结果
" 1：单独触发
let s:force_complete = 0

function! easycomplete#sources#tn#constructor(opt, ctx)
  let s:opt = a:opt
  let name = get(a:opt, "name", "")
  let s:tn_name = name
  if !easycomplete#installer#LspServerInstalled(name)
    return v:true
  endif
  if !easycomplete#ok('g:easycomplete_tabnine_enable')
    return v:true
  endif
  call s:StartTabNine()
  return v:true
endfunction

function! easycomplete#sources#tn#available()
  if easycomplete#ok('g:easycomplete_tabnine_enable') &&
        \ easycomplete#sources#tn#JobStatus() == "run"
    return s:tn_init_ready
  else
    return v:false
  endif
endfunction

function! s:flush()
  let global_opt = get(g:easycomplete_source, s:tn_name, {})
  let global_opt.complete_result = []
  let s:force_complete = 0
  if s:tn_render_timer > 0
    call timer_stop(s:tn_render_timer)
  endif
  let s:tn_render_timer = 0
endfunction

function! s:ResetForceCompleteFlag()
  let s:force_complete = 0
endfunction

" 只更新 g:easycomplete_sources['tn'].complete_result
" refresh(v:true), 强制给出匹配菜单
function! easycomplete#sources#tn#refresh(...)
  if !easycomplete#ok('g:easycomplete_tabnine_enable')
    return
  endif
  if exists("a:1") && a:1 == v:true
    let s:force_complete = 1
    call timer_start(100, { -> s:ResetForceCompleteFlag()})
  else
    let s:force_complete = 0
  endif
  call easycomplete#sources#tn#completor(s:opt, easycomplete#context())
endfunction

function! easycomplete#sources#tn#FireCondition()
  let l:ctx = easycomplete#context()
  let l:char = l:ctx["char"]
  let l:typed = l:ctx["typed"]
  if strlen(l:typed) >= 2
    if l:typed[-2:] == "' " || l:typed[-2:] == '" '
      return v:false
    endif
    if l:typed[strlen(l:typed) - 2] != " " && l:typed[strlen(l:typed) - 1] == " "
      return v:true
    endif
    let charset = [":","=",",",";",">", "'", '"']
    if index(charset, l:char) >= 0 &&
          \ index(charset, l:typed[strlen(l:typed) - 2]) < 0
      return v:true
    endif
    if easycomplete#sources#tn#VimColonTyping(l:typed)
      return v:false
    endif
    return v:false
  else
    return v:false
  endif
endfunction

function! easycomplete#sources#tn#VimColonTyping(typed)
  if !(&filetype == "vim")
    return v:false
  endif
  if a:typed =~ "\\W*\\(w\\|t\\|a\\|b\\|v\\|s\\|g\\):\[0-9a-zA-Z_\]*$"
    return v:true
  else
    return v:false
  endif

endfunction

function! easycomplete#sources#tn#GetGlobalSourceItems()
  return g:easycomplete_source[s:tn_name].complete_result
endfunction

function! easycomplete#sources#tn#SetGlobalSourceItems(items)
  if !has_key(g:easycomplete_source, s:tn_name)
    let g:easycomplete_source[s:tn_name] = {
          \ "complete_result" : []
          \ }
  endif
  let g:easycomplete_source[s:tn_name].complete_result = a:items
endfunction

function! easycomplete#sources#tn#completor(opt, ctx) abort
  if !s:tn_init_ready
    call easycomplete#complete(a:opt['name'], a:ctx, a:ctx['startcol'], [])
    return v:true
  endif
  if !exists('b:module_building') | let b:module_building = v:false | endif
  if b:module_building == v:false && len(easycomplete#GetStuntMenuItems()) == 0
    " 防止 tabnine 初始模型构建时的 UI 阻塞
    call easycomplete#complete(a:opt['name'], a:ctx, a:ctx['startcol'], [])
  endif
  if easycomplete#sources#tn#JobStatus() == "run"
    call easycomplete#sources#tn#SimpleTabNineRequest(a:ctx)
  else
    call easycomplete#complete(a:opt['name'], a:ctx, a:ctx['startcol'], [])
    call timer_start(1000, {
          \  -> s:StartTabNine()
          \ })
    let s:tn_init_ready = v:false
  endif
  return v:true
endfunction

function! s:GetTabNineParams()
  let l:line_limit = get(g:easycomplete_tabnine_config, 'line_limit', 700)
  let l:max_num_result = get(g:easycomplete_tabnine_config, 'max_num_result', 3)
  let l:pos = getpos('.')
  let l:last_line = line('$')
  let l:before_line = max([1, l:pos[1] - l:line_limit])
  let l:before_lines = getline(l:before_line, l:pos[1])
  if !empty(l:before_lines)
    let l:before_lines[-1] = l:before_lines[-1][:l:pos[2]-2]
  endif
  let l:after_line = min([l:last_line, l:pos[1] + l:line_limit])
  let l:after_lines = getline(l:pos[1], l:after_line)
  if !empty(l:after_lines)
    let l:after_lines[0] = l:after_lines[0][l:pos[2]:]
  endif

  let l:region_includes_beginning = v:false
  if l:before_line == 1
    let l:region_includes_beginning = v:true
  endif

  let l:region_includes_end = v:false
  if l:after_line == l:last_line
    let l:region_includes_end = v:true
  endif

  " 有可能返回的结果里面会是一个代码片段"completion_kind":"Snippet"
  " 如果是complete的话，代码片段类型应该为"completion_kind":"Classic"
  let l:params = {
     \   'filename': expand('%:p'),
     \   'before': join(l:before_lines, "\n"),
     \   'after': join(l:after_lines, "\n"),
     \   'region_includes_beginning': l:region_includes_beginning,
     \   'region_includes_end': l:region_includes_end,
     \   'max_num_result': l:max_num_result,
     \   'net_length':1000
     \ }
  return l:params
endfunction

function! easycomplete#sources#tn#GetTabNineVersion()
  if empty(s:version)
    let l:tabnine_cmd = easycomplete#installer#GetCommand(s:tn_name)
    let l:tabnine_dir = fnameescape(fnamemodify(l:tabnine_cmd, ':p:h'))
    let l:version_file = l:tabnine_dir . '/version'

    for line in readfile(l:version_file, '', 10)
      if trim(line) =~ "^\\d\\{-}.\\d\\{-}.\\d\\{-}$"
        let s:version = trim(line)
        break
      endif
    endfor
  endif
  return s:version
endfunction

" 返回 complete_kind: snippet 或者 classic
" 返回 nothing 说明匹配内容是空的
" 根据这里的返回来决定处理方式，是 suggest 还是 complete
function! s:TabNineCompleteKind(res_array)
  if empty(a:res_array)
    return "nothing"
  endif
  let results = get(a:res_array, "results", [])
  if empty(results)
    return 'nothing'
  endif
  let first_item = results[0]
  if has_key(first_item, 'completion_metadata')
    let metadata = get(first_item, 'completion_metadata', {})
    if empty(metadata)
      return 'nothing'
    endif
    let completion_kind = get(metadata, 'completion_kind', '')
    return tolower(completion_kind)
  else
    return "classic"
  endif
endfunction

function! s:TabNineRequest(name, param, ctx) abort
  if s:tn_job == v:null || !s:tn_init_ready
    return
  endif
  let l:req = {
        \ 'version': easycomplete#sources#tn#GetTabNineVersion(),
        \ 'request': {
        \     a:name : a:param
        \   },
        \ }
  try
    let l:buffer = json_encode(l:req) . "\n"
  catch /474/
    return
  endtry
  let s:ctx = a:ctx
  if s:tn_render_timer > 0
    call timer_stop(s:tn_render_timer)
    let s:tn_render_timer = 0
  endif
  let s:tn_render_timer = timer_start(s:tn_timeout, { -> s:timeout() })
  call easycomplete#job#send(s:tn_job, l:buffer)
endfunction

function! s:timeout()
  let s:tn_render_timer = 0
endfunction

" 可以传参 ctx, 也可以留空
function! easycomplete#sources#tn#SimpleTabNineRequest(...)
  let l:ctx = exists('a:1') ? a:1 : easycomplete#context()
  let l:params = s:GetTabNineParams()
  " ['{"error":"Worker error: unknown variant `AutocompleteArgs`, expected one of
  " `Autocomplete`, `AutocompleteV4471`, `AutocompleteV4451`, `AutocompleteV4448`, 
  " `AutocompleteV4121`, `AutocompleteV4057`, `AutocompleteV3534`, `AutocompleteV3271`,
  " `AutocompleteV3253`, `AutocompleteV21`, `AutocompleteV20`, `AutocompleteV10`, `AutocompleteV6`,
  " `AutocompleteV4`, `AutocompleteV3`, `AutocompleteV2`, `Inform`, `ListIndexedFiles`, 
  " `Metadata`, `State`, `SetState`, `SetStateV20`, `Features`, `Prefetch`, `GetIdentifierRegex`, 
  " `Configuration`, `Deactivate`, `Uninstalling`, `Restart`, `Notifications`, `NotificationAction`,
  " `StatusBar`, `StatusBarAction`, `Hover`, `HoverAction`, `StartupActions`, `Event`, `HubStructure`,
  " `Login`, `LoginWithCustomToken`, `LoginWithCustomTokenUrl`, `Logout`, `NotifyWorkspaceChanged`,
  " `OpenUrl`, `SaveSnippet`, `SuggestionShown`, `SuggestionDropped`, `About`, `FileMetadata`,"
  " `RefreshRemoteProperties`, `StartLoginServer`, `ChatCommunicatorAddress`, `Workspace`"}', '']
  call s:TabNineRequest("Autocomplete", l:params, l:ctx)
  if easycomplete#tabnine#TypingType() == "suggest"
    call easycomplete#tabnine#LoadingStart()
  endif
endfunction

" 删除指定目录下除 "0.0.1" 和 "4.251.0" 以外的所有子目录
function! s:DeleteAllDirsExceptTow(dir) abort
  let l:items = split(glob(a:dir . '/*', 0, 0, 1), "\n")
  for item in l:items
    let l:dir_name = fnamemodify(item, ':t')
    if l:dir_name ==# "0.0.1" || l:dir_name ==# "4.251.0"
      continue
    endif
    if isdirectory(item)
      call s:DD(item)
    endif
  endfor
endfunction

" 递归删除目录中的文件和空目录
function! s:DD(dir) abort
  " 获取所有子项（文件 + 目录）
  let items = split(glob(a:dir . '/*', 0, 0, 1), "\n")
  for item in items
    if isdirectory(item)
      " 如果是目录，递归处理
      call s:DD(item)
    else
      " 如果是文件，直接删除
      call delete(item)
    endif
  endfor
  " 最后删除当前目录（此时应为空）
  call delete(a:dir, 'd')
endfunction

function! s:StartTabNine()
  if empty(s:tn_name)
    return
  endif
  let name = s:tn_name
  let l:tabnine_path = easycomplete#installer#GetCommand(name)
  let l:tabnine_root_path = fnameescape(fnamemodify(l:tabnine_path, ':p:h'))
  call s:DeleteAllDirsExceptTow(l:tabnine_root_path . "/binaries")
  let l:log_file = fnameescape(fnamemodify(l:tabnine_path, ':p:h')) . '/tabnine.log'
  let l:cmd = [
        \   l:tabnine_path,
        \   '--client',
        \   'vim-easycomplete',
        \   '--log-file-path',
        \   l:log_file,
        \ ]
  let s:tn_job = easycomplete#job#start(l:cmd,
        \ {
        \    'on_stdout': function('s:TabnineJobCallback'),
        \    'on_stderr': function('s:TabnineJobErr'),
        \    'on_exit':   function('s:TabnineExit')
        \ })
  if s:tn_job <= 0
    call s:errlog("[TabNine Error]:", "TabNine job start failed", expand("%:m:p"))
  else
    let s:tn_init_ready = v:true
  endif
  call timer_start(700, { -> easycomplete#sources#tn#GetTabNineVersion()})
endfunction

function! s:TabnineJobErr(job_id, data, event)
  " call s:log(a:job_id, a:data, a:event)
endfunction

function! s:TabnineExit(job_id, data, event)
  if a:event == "exit"
    " call s:log('Restart Tabnine server')
    call s:errlog("[TabNine Error]:", "TabNine exit", expand("%:m:p"))
    " call s:StartTabNine()
  endif
endfunction

function! easycomplete#sources#tn#JobStatus()
  if s:tn_job == v:null
    return "v:null"
  endif
  try
    let l:job_status = easycomplete#job#status(s:tn_job)
  catch /900/
    let l:job_status = "dead"
  endtry
  return l:job_status
endfunction

function! s:TabnineJobCallback(job_id, data, event)
  call easycomplete#tabnine#LoadingStop()
  let l:ctx = easycomplete#context()
  if a:event != 'stdout'
    call easycomplete#complete(s:tn_name, s:ctx, s:ctx['startcol'], [])
    return
  endif
  if !exists('b:module_building') | let b:module_building = v:false | endif
  let b:module_building = v:true
  if !easycomplete#CheckContextSequence(s:ctx)
    call easycomplete#sources#tn#refresh()
    return
  endif
  " a:data is a list
  let res_array = s:ArrayParse(a:data)
  let t9_cmp_kind = s:TabNineCompleteKind(res_array)
  if t9_cmp_kind == "nothing"
    call s:CompleteHandler([])
    return
  endif
  " ----------------- 过滤 vim 的 g: 之类的输入  -----------------
  if easycomplete#sources#tn#VimColonTyping(l:ctx["typed"])
    call s:CompleteHandler([])
    return
  endif
  " ----------------- pum 不存在时执行回调 -----------------
  if g:env_is_vim && !pumvisible() && t9_cmp_kind == "snippet"
    call s:SuggestHandler(res_array)
    return
  endif
  if g:env_is_nvim && !easycomplete#pum#visible() && t9_cmp_kind == "snippet"
    call s:SuggestHandler(res_array)
    return
  endif
  " ---- 当snippet结果返回时，已经存在匹配菜单了，则丢弃 -----
  if g:env_is_vim && pumvisible() && t9_cmp_kind == "snippet"
    call s:CompleteHandler([])
    return
  endif
  if g:env_is_nvim && easycomplete#pum#visible() && t9_cmp_kind == "snippet"
    call s:CompleteHandler([])
    return
  endif
  " 如果有标志位，等同认为是 suggest
  if g:env_is_vim && !pumvisible() && easycomplete#tabnine#SuggestFlagCheck()
    call s:SuggestHandler(res_array)
  elseif g:env_is_nvim && !easycomplete#pum#visible() && easycomplete#tabnine#SuggestFlagCheck()
    call s:SuggestHandler(res_array)
  else " 配合pum显示tabnine提示词s
    let result_items = s:NormalizeCompleteResult(a:data)
    call s:CompleteHandler(result_items)
  endif
endfunction

function! s:SuggestHandler(res_array)
  if g:env_is_vim && pumvisible()
    return
  elseif g:env_is_nvim && easycomplete#pum#visible()
    return
  endif
  if easycomplete#ok("g:easycomplete_tabnine_suggestion")
    call easycomplete#tabnine#Callback(a:res_array)
  endif
endfunction

function! s:CompleteHandler(res)
  let result = a:res
  if empty(result)
    call s:flush()
  endif
  try
    for item in result
      let l:word = get(item, "word")
      let l:info = get(item, "info")
      let l:menu = get(item, "menu")
      let sha256_str = strpart(easycomplete#util#Sha256(l:word), 0, 15)
      let user_data_json = extend(easycomplete#util#GetUserData(item), {
            \   'plugin_name': "tn",
            \   'sha256': sha256_str
            \ })
      let item["user_data"] = json_encode(user_data_json)
      let item["user_data_json"] = user_data_json
    endfor
    if s:force_complete
      call easycomplete#util#call(function("s:UpdateRendering"), [result])
    else
      if len(easycomplete#GetStuntMenuItems()) == 0 && g:easycomplete_first_complete_hit == 0
        " First Complete
        if s:tn_render_timer == 0
          call easycomplete#complete(s:tn_name, s:ctx, s:ctx['startcol'], [])
          " tn 的返回已经超时了，为了防止pum抖动，结果直接丢弃
        else
          call easycomplete#complete(s:tn_name, s:ctx, s:ctx['startcol'], result)
          let s:tn_render_timer = 0
        endif
      else
        " Second Complete
        if !easycomplete#CompleteCursored() && &completeopt =~ "noselect"
          call easycomplete#util#call(function("s:UpdateRendering"), [result])
        endif
        if easycomplete#CompleteCursored()  && !(&completeopt =~ "noselect")
              \ && easycomplete#pum#CompleteInfo()["selected"] == 0
          call easycomplete#util#call(function("s:UpdateRendering"), [result])
          " call s:UpdateRendering(result)
        endif
        " if s:tn_render_timer > 0
        "   call timer_stop(s:tn_render_timer)
        "   let s:tn_render_timer = 0
        " endif
        " let s:tn_render_timer = timer_start(60,
        "       \ { -> easycomplete#util#call(function("s:UpdateRendering"), [result])
        "       \ })
      endif
    endif
  catch
    call s:log("[TabNine Error]:", "CompleteHandler", v:exception)
    let l:ctx = easycomplete#context()
    call easycomplete#complete(s:tn_name, l:ctx, l:ctx['startcol'], [])
  endtry
endfunction

function! s:UpdateRendering(result)
  if easycomplete#sources#path#pum()
    return
  endif
  call easycomplete#StoreCompleteSourceItems(s:tn_name, a:result)
  call easycomplete#TabNineCompleteRendering()
endfunction

function! s:ArrayParse(data)
  if type(a:data) == type([]) && len(a:data) >= 1
    let l:data = a:data[0]
    if l:data == ""
      return []
    endif
    let l:response = json_decode(l:data)
  elseif type(a:data) == type({})
    let l:response = a:data
  else
    let l:response = json_decode(a:data)
  endif
  return l:response
endfunction

function! s:NormalizeCompleteResult(data)
  let l:col = s:ctx['col']
  let l:typed = s:ctx['typed']

  let l:kw = matchstr(l:typed, '\w\+$')
  let l:lwlen = len(l:kw)

  let l:startcol = l:col - l:lwlen
  let l:response = s:ArrayParse(a:data)
  let old_prefix = get(l:response, 'old_prefix', "")
  if old_prefix !=# s:ctx["typing"]
    let tn_prefix = substitute(s:ctx['typing'], old_prefix . "$","","g")
  else
    let tn_prefix = ""
  endif
  let l:words = []
  for l:result in l:response['results']
    let l:word = {}

    let l:new_prefix = get(l:result, 'new_prefix')
    if l:new_prefix == ''
      continue
    endif
    let l:word['word'] = l:new_prefix

    if get(l:result, 'old_suffix', '') != '' || get(l:result, 'new_suffix', '') != ''
      let l:user_data = {
            \   'old_suffix': get(l:result, 'old_suffix', ''),
            \   'new_suffix': get(l:result, 'new_suffix', ''),
            \ }
      let l:word['user_data'] = json_encode(l:user_data)
    endif

    if !empty(g:easycomplete_kindflag_tabnine)
      let l:word["kind"] = g:easycomplete_kindflag_tabnine
    endif
    if !empty(g:easycomplete_menuflag_tabnine)
      let l:word["menu"] = g:easycomplete_menuflag_tabnine
    else
      let l:word['menu'] = '[TN]'
    endif
    let percent_str = ""
    if get(l:result, 'detail')
      let percent_str = s:fullfill(l:result['detail'])
    endif
    let tmp_detail = easycomplete#util#get(l:result, 'completion_metadata', 'detail')
    if !empty(tmp_detail)
      let percent_str = s:fullfill(tmp_detail)
    endif
    let l:word["menu"] .= percent_str
    let l:full_abbr = l:word['word']
    let l:word["sort_number"] = matchstr(percent_str, "\\d\\+","g")
    let l:word['abbr'] = easycomplete#util#parseAbbr(l:word['word'])
    let l:word['word'] = tn_prefix . l:word['word']
    let complete_kind = easycomplete#util#get(l:result, 'completion_metadata', 'completion_kind')
    let complete_origin = easycomplete#util#get(l:result, 'completion_metadata', 'origin')
    let l:word['info'] = join(["TabNine Suggestion:", l:full_abbr], "\n")
    call add(l:words, l:word)
  endfor
  call sort(l:words, {a, b -> str2nr(a["sort_number"]) < str2nr(b["sort_number"])})
  " 最多只输出百分比最靠前的三个匹配结果
  return l:words[0:2]
endfunction

" ' 4%' -> ' 4%'
" '22%' -> ' 22%'
function! s:fullfill(percent)
  if a:percent[0] == " "
    return a:percent
  else
    return " " . a:percent
  endif
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
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

function! s:errlog(...)
  return call('easycomplete#util#errlog', a:000)
endfunction
