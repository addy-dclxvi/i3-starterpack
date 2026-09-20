""" 常用的工具函数
scriptencoding utf-8
let s:easycomplete_toolkit = has('nvim') ? v:lua.require("easycomplete") : v:null
let s:tabnine_toolkit = has('nvim') ? v:lua.require("easycomplete.tabnine") : v:null
let s:util_toolkit = has('nvim') ? v:lua.require("easycomplete.util") : v:null

function! easycomplete#util#ShowHint(text) " {{{
  if g:env_is_vim | return | endif
  call s:tabnine_toolkit.show_hint([a:text])
endfunction " }}}

function! easycomplete#util#DeleteHint() " {{{
  if g:env_is_vim | return | endif
  call s:tabnine_toolkit.delete_hint()
endfunction " }}}

" get file extention {{{
function! easycomplete#util#extention()
  let filename = fnameescape(fnamemodify(bufname('%'),':p'))
  let ext_part = substitute(filename,"^.\\+[\\.]","","g")
  return ext_part
endfunction " }}}

" get all plugins {{{
" buffer number
function! easycomplete#util#GetAttachedPlugins(...)
  let all_plugins = easycomplete#GetAllPlugins()
  let buf_nr = empty(a:000) ? bufnr('%') : str2nr(a:1)
  let ft = getbufvar(buf_nr, "&filetype")
  let attached_plugins = []
  for name in keys(all_plugins)
    let plugin = get(all_plugins, name)
    if empty(plugin) | continue | endif
    let whitelist = get(plugin, 'whitelist', [])
    if empty(whitelist)
      continue
    endif
    if index(whitelist, ft) >= 0
      call add(attached_plugins, plugin)
    endif
  endfor
  return attached_plugins
endfunction " }}}

" AsyncRun {{{
" 参数：method, args, delay
" method 必须是一个全局方法,
" timer 为空则默认为0
function! easycomplete#util#AsyncRun(...)
  let Method = a:1
  let args = exists('a:2') ? a:2 : []
  let delay = exists('a:3') ? a:3 : 0
  if g:env_is_nvim
    " Method 如果是字符串的话不能是 s:xxx 这类临时函数
    let g:easycomplete_popup_timer = s:util_toolkit.async_run(Method, args, delay)
  else
    let g:easycomplete_popup_timer = timer_start(delay, { -> easycomplete#util#call(Method, args)})
  endif
  return g:easycomplete_popup_timer
endfunction " }}}

function! easycomplete#util#SideOpenQFWindow() " {{{
  let current_winid = bufwinid(bufnr(""))
  copen
  call easycomplete#ui#qfhl()
  call easycomplete#util#GotoWindow(current_winid)
endfunction " }}}

" StopAsyncRun {{{
function! easycomplete#util#StopAsyncRun()
  if exists('g:easycomplete_popup_timer') && g:easycomplete_popup_timer > 0
    if g:env_is_nvim
      call s:util_toolkit.stop_async_run()
    else
      call timer_stop(g:easycomplete_popup_timer)
    endif
  endif
  let g:easycomplete_popup_timer = 0
endfunction " }}}

" function calling {{{
function! easycomplete#util#call(method, args) abort
  try
    if type(a:method) == 2 " 是函数
      let TmpCallback = function(a:method, a:args)
      return TmpCallback()
    endif
    let res = 0
    if type(a:method) == type("string") " 是字符串
      let res = call(a:method, a:args)
    endif
    let g:easycomplete_popup_timer = -1
    return res
  catch /.*/
    return 0
  endtry
endfunction " }}}

" complete menu uniq {{{
" 性能很差，谨慎使用
function! easycomplete#util#uniq(menu_list)
  let tmp_list = deepcopy(a:menu_list)
  let result_list = []
  for item in tmp_list
    if !s:HasItem(result_list, item)
      call add(result_list, item)
    endif
  endfor
  return result_list
endfunction

function! s:HasItem(list,item)
  let flag = v:false
  for item in a:list
    if s:SameItem(item,a:item)
      let flag = v:true
      break
    endif
  endfor
  return flag
endfunction

function! s:SameItem(item1,item2)
  let l:item1 = a:item1
  let l:item2 = a:item2
  if get(l:item1, "word") ==# get(l:item2, "word")
        \ && get(l:item1, "menu") ==# get(l:item2, "menu")
        \ && get(l:item1, "kind") ==# get(l:item2, "kind")
        \ && get(l:item1, "abbr") ==# get(l:item2, "abbr")
        \ && get(l:item1, "info") ==# get(l:item2, "info")
    return v:true
  else
    return v:false
  endif
endfunction
" }}}

function! easycomplete#util#SameItem(item1, item2) " {{{
  return s:SameItem(a:item1, a:item2)
endfunction " }}}

" goto location {{{
function! easycomplete#util#location(path, line, col, ...) abort
  normal! m'
  let l:mods = a:0 ? a:1 : ''
  let l:buffer = bufnr(a:path)
  if l:mods ==# '' && &modified && !&hidden && l:buffer != bufnr('%')
    let l:mods = &splitbelow ? 'rightbelow' : 'leftabove'
  endif
  if l:mods ==# ''
    if l:buffer == bufnr('%')
      let l:cmd = ''
    else
      let l:cmd = (l:buffer !=# -1 ? 'b ' . l:buffer : 'edit ' . fnameescape(a:path)) . ' | '
    endif
  else
    let l:cmd = l:mods . ' ' . (l:buffer !=# -1 ? 'sb ' . l:buffer : 'split ' . fnameescape(a:path)) . ' | '
  endif
  let full_cmd = l:cmd . 'call cursor('.a:line.','.a:col.')'
  execute full_cmd
endfunction " }}}

" normalize buf name {{{
function! easycomplete#util#normalize(buf_name)
  return substitute(a:buf_name, '\\', '/', 'g')
endfunction " }}}

" UpdateTagStack {{{
function! easycomplete#util#UpdateTagStack() abort
  let l:bufnr = bufnr('%')
  let l:item = {'bufnr': l:bufnr, 'from': [l:bufnr, line('.'), col('.'), 0], 'tagname': expand('<cword>')}
  let l:winid = win_getid()

  let l:stack = gettagstack(l:winid)
  if l:stack['length'] == l:stack['curidx']
    " Replace the last items with item.
    let l:action = 'r'
    let l:stack['items'][l:stack['curidx']-1] = l:item
  elseif l:stack['length'] > l:stack['curidx']
    " Replace items after used items with item.
    let l:action = 'r'
    if l:stack['curidx'] > 1
      let l:stack['items'] = add(l:stack['items'][:l:stack['curidx']-2], l:item)
    else
      let l:stack['items'] = [l:item]
    endif
  else
    " Append item.
    let l:action = 'a'
    let l:stack['items'] = [l:item]
  endif
  let l:stack['curidx'] += 1

  call settagstack(l:winid, l:stack, l:action)
endfunction " }}}

" trim {{{
function! easycomplete#util#trim(str)
  if !empty(a:str)
    " 删除头部空格
    let a1 = substitute(a:str, "^\\s\\+\\(.\\{\-}\\)$","\\1","g")
    " 删除尾部空格
    let a1 = substitute(a:str, "^\\(.\\{\-}\\)\\s\\+$","\\1","g")
    return a1
  endif
  return ""
endfunction " }}}

function! easycomplete#util#GetArch()
  if exists("s:easycomplete_arch")
    return s:easycomplete_arch
  else
    let s:easycomplete_arch = easycomplete#python#GetArch()
    return s:easycomplete_arch
  endif
endfunction

function! easycomplete#util#IsMacOS()
  if exists("s:easycomplete_ismacos")
    return s:easycomplete_ismacos
  else
    let s:easycomplete_ismacos = easycomplete#python#IsMacOS()
    return s:easycomplete_ismacos
  endif
endfunction

function! easycomplete#util#GetPluginNameFromUserData(item) " {{{
  return s:GetPluginNameFromUserData(a:item)
endfunction " }}}

function! s:GetPluginNameFromUserData(item) " {{{
  if has_key(a:item, "plugin_name")
    return get(a:item, "plugin_name", "")
  endif
  let user_data = easycomplete#util#GetUserData(a:item)
  let plugin_name = get(user_data, "plugin_name", "")
  return plugin_name
endfunction " }}}

function! easycomplete#util#GetSha256(item) " {{{
  let user_data = easycomplete#util#GetUserData(a:item)
  let sha_code = get(user_data, "sha256", "")
  return sha_code
endfunction " }}}

function! easycomplete#util#GetUserData(item) " {{{
  " let ret = get(a:item, "user_data_json", {})
  if has_key(a:item, "user_data_json")
    let ret = a:item["user_data_json"]
  else
    let ret = {}
  endif
  if !empty(ret)
    return ret
  endif
  if has_key(a:item, 'user_data')
    let user_data_str = a:item["user_data"]
  else
    let user_data_str = ""
  endif
  if empty(user_data_str)
    return {}
  endif
  try
    let user_data = json_decode(user_data_str)
    if empty(user_data)
      return {}
    else
      return user_data
    endif
  catch /^Vim\%((\a\+)\)\=:\(E474\|E491\)/
    return {}
  endtry
endfunction " }}}

" GetInfoByCompleteItem {{{
function! easycomplete#util#GetInfoByCompleteItem(item, all_menu)
  let t_plugin_name = s:GetPluginNameFromUserData(a:item)
  if t_plugin_name == "tn"
    let l:info = s:GetTabNineItemInfo(a:item)
    return l:info
  endif
  let t_sha = easycomplete#util#GetSha256(a:item)
  let info = ""
  for item in a:all_menu
    if type(item) != type({})
      continue
    endif
    let i_plugin_name = get(item, 'plugin_name', '')
    let i_plugin_name = s:GetPluginNameFromUserData(item)
    let i_sha = easycomplete#util#GetSha256(item)
    if i_sha ==# t_sha && i_plugin_name ==# t_plugin_name
      if has_key(item, "info")
        let info = get(item, "info", [])
      endif
      break
    endif
  endfor
  let max_height = 50
  if type(info) == type("")
    let info = [info]
  endif
  if len(info) > max_height
    let info = info[0:50] + ["..."]
  endif
  return info
endfunction

" 一般在 item 的 word 过长被隐藏显示时（或者是 buffers）
" 如果 lsp 没有返回 info，最好显示一下完整的label
" 通常在 lsp 返回后调用，所以这里不用考虑延迟的问题
function! easycomplete#util#ShowDefaultInfo(item)
  let whole_info = get(a:item, "word", "")
  let menu_flag = get(a:item, "menu", "")
  call easycomplete#ShowCompleteInfo(whole_info)
  call easycomplete#SetMenuInfo(whole_info, whole_info, menu_flag)
endfunction

function! s:GetTabNineItemInfo(item)
  " 这里的 info 是一个字符串，不是数组
  let l:info = get(a:item, "info", "")
  if empty(l:info)
    return []
  endif
  return split(l:info, "\n")
endfunction

function! s:TrimWavyLine(str)
  return substitute(a:str, "\\(\\w\\)\\@<=\\~$", "", "g")
endfunction
" }}}

" TrimWavyLine {{{
function! easycomplete#util#TrimWavyLine(...)
  return call("s:TrimWavyLine", a:000)
endfunction " }}}

" deletebufline {{{
function! util#deletebufline(bn, fl, ll)
  " vim version <= 801 deletebufline dos not exists
  if exists("deletebufline")
    call deletebufline(a:bn, a:fl, a:ll)
  else
    let current_winid = bufwinid(bufnr(""))
    call easycomplete#util#GotoWindow(bufwinid(a:bn))
    call execute(string(a:fl) . 'd ' . string(a:ll - a:fl), 'silent!')
    call easycomplete#util#GotoWindow(current_winid)
  endif
endfunction " }}}

" EnvCHecking {{{
function! easycomplete#util#EnvReady()
  let wininfo = getwininfo(bufwinid(bufnr("")))[0]
  if empty(wininfo) | return v:false | endif
  if wininfo['quickfix'] == 1 | return v:false | endif
  if wininfo['terminal'] == 1 | return v:false | endif
  if &buftype == "terminal" | return v:false | endif
  if (getbufinfo(bufnr(''))[0]["name"] =~ "debuger=1")
    return v:false
  endif
  return v:true
endfunction " }}}

" IsTerminal {{{
function! easycomplete#util#IsTerminal()
  let wininfo = getwininfo(bufwinid(bufnr("")))[0]
  if wininfo['terminal'] == 1 | return v:true | endif
  return v:false
endfunction " }}}

" str2list {{{
function! easycomplete#util#str2list(expr)
  if exists("*str2list")
    return str2list(a:expr)
  endif
  if type(a:expr) ==# v:t_list
    return a:expr
  endif
  let l:index = 0
  let l:arr = []
  while l:index < strlen(a:expr)
    call add(l:arr, char2nr(a:expr[l:index]))
    let l:index += 1
  endwhile
  return l:arr
endfunction " }}}

" isjson {{{
function! easycomplete#util#IsJson(str)
  let flag = v:true
  if a:str == "\r" || a:str == "\n"
    let flag = v:false
  else
    try
      call json_decode(a:str)
    catch /^Vim\%((\a\+)\)\=:\(E474\|E491\)/
      let flag = v:false
    endtry
  endif
  return flag
endfunction " }}}

" GetFullName {{{
function! easycomplete#util#GetFullName(fname)
  return fnameescape(fnamemodify(a:fname,':p'))
endfunction " }}}

" GetCurrentFullName {{{
function! easycomplete#util#GetCurrentFullName()
  if exists("b:easycomplete_buf_fullname")
    return b:easycomplete_buf_fullname
  else
    let b:easycomplete_buf_fullname = easycomplete#util#GetFullName(bufname("%"))
    return b:easycomplete_buf_fullname
  endif
endfunction " }}}

" TagBarExists {{{
function! easycomplete#util#TagBarExists()
  return easycomplete#util#FuncExists("tagbar#StopAutoUpdate")
endfunction " }}}

" FuncExists {{{
function! easycomplete#util#FuncExists(func_name)
  try
    call funcref(a:func_name)
  catch /^Vim\%((\a\+)\)\=:E700/
    return v:false
  endtry
  return v:true
endfunction " }}}

" RestoreCtx {{{
" 存储ctx，异步返回时取出
function! easycomplete#util#RestoreCtx(ctx, request_seq)
  " 删除多余的 ctx
  let arr = []
  if !exists("s:ctx_list")
    let s:ctx_list = {}
  endif
  for item in keys(s:ctx_list)
    call add(arr, str2nr(item))
  endfor
  let sorted_arr = reverse(sort(arr, "s:nSort"))
  let new_dict = {}
  let index = 0
  while index < 10 && index < len(sorted_arr)
    let t_index = string(sorted_arr[index])
    let new_dict[t_index] = get(s:ctx_list, t_index)
    let index = index + 1
  endwhile
  let s:ctx_list = new_dict
  let s:ctx_list[string(a:request_seq)] = a:ctx
endfunction

function! s:nSort(a, b)
    return a:a == a:b ? 0 : a:a > a:b ? 1 : -1
endfunction
" }}}

" GetCtxByRequestSeq {{{
function! easycomplete#util#GetCtxByRequestSeq(seq)
  if !exists("s:ctx_list")
    let s:ctx_list = {}
  endif
  return get(s:ctx_list, string(a:seq))
endfunction " }}}

" FuzzySearch {{{
function! easycomplete#util#FuzzySearch(needle, haystack)
  " 性能测试：
  "  - s:FuzzySearchRegx 速度最快
  "  - s:FuzzySearchCustom 速度次之
  "  - s:FuzzySearchSpeedUp 速度再次之
  "  - s:FuzzySearchPy 速度最差
  " 同等条件测试结果：
  " 564   0.033410   0.030417  <SNR>98_FuzzySearchRegx()
  " 564   0.033523   0.030683  <SNR>98_FuzzySearchRegx()
  " 604   0.043402   0.039086  <SNR>98_FuzzySearchCustom()
  " 604   0.059750   0.053755  <SNR>98_FuzzySearchCustom()
  " 604   0.042826   0.038499  <SNR>98_FuzzySearchSpeedUp()
  " 604   0.052077   0.046813  <SNR>98_FuzzySearchSpeedUp()
  " 604   0.369052   0.367013  easycomplete#python#FuzzySearchPy()
  " 604   0.349416   0.347424  easycomplete#python#FuzzySearchPy()
  return s:FuzzySearchRegx(a:needle, a:haystack)
  return s:FuzzySearchCustom(a:needle, a:haystack)
  return s:FuzzySearchSpeedUp(a:needle, a:haystack)
  return s:FuzzySearchPy(a:needle, a:haystack)
endfunction

function! s:FuzzySearchRegx(needle, haystack)
  " Lua 和 VIM 的实现 matchfuzzy 做性能对比：
  "
  " lua 和 vim 的只做 matchfuzzy 速度对比，vim 更快
  "    单词数→匹配出的结果个数
  " lua 53377→9748   0.028384
  " vim 53377→9748   0.010808
  "
  " vim 中 matchfuzzy 和 filter 的速度对比，filter 比 matchfuzzy 更慢
  "            单词数→匹配出的结果个数
  "  matchfuzzy 58422→21372 0.018895
  "  filter，   21372→15633 0.027022
  "
  " lua 和 vim 做 matchfuzzy 和 filter 一起的速度对比
  " lua 中两个函数放一起不影响时间复杂度，基本上和单个 matchfuzzy 性能一致
  " vim 中必须把 matchfuzzy 和 filter 分开写，多一次全局遍历，表现更慢
  "                          单词数→匹配出的结果个数
  " lua matchfuzzy_and_filter 58422→18010   0.024128
  " vim matchfuzzy_and_filter 58422→18010   0.040463
  "
  " 结论：如果需要同时使用 filter 和 matchfuzzy 的时候优先使用 lua 做 matchfuzzy
  "
  " if easycomplete#util#HasLua()
  "   let s:easycomplete_toolkit = v:lua.require("easycomplete")
  "   return s:easycomplete_toolkit.fuzzy_search(a:needle, a:haystack)
  " else
  let tlen = strlen(a:haystack)
  let qlen = strlen(a:needle)
  if qlen > tlen
    return v:false
  endif
  if qlen == tlen
    return a:needle ==? a:haystack ? v:true : v:false
  endif
  let constraint = &filetype == 'vim' ? "\\{,14}" : "\\{-}"

  let needle_list = easycomplete#util#str2list(a:needle)
  let needle_ls = map(needle_list, { _, val -> nr2char(val)})
  let needle_ls_regx = join(needle_ls, "[a-zA-Z0-9_#:\.]" . constraint)
  if index(["vim", "nim"], &filetype) >= 0
    let needle_ls_regx = "^[a-zA-Z0-9]\\{,4}" . needle_ls_regx
  endif
  let matching = (a:haystack =~ needle_ls_regx)
  return matching ? v:true : v:false
  " endif
endfunction

function! s:FuzzySearchSpeedUp(needle, haystack)
  let tlen = strlen(a:haystack)
  let qlen = strlen(a:needle)
  if qlen > tlen
    return v:false
  endif
  if qlen == tlen
    return a:needle ==? a:haystack ? v:true : v:false
  endif

  let needle_ls = easycomplete#util#str2list(tolower(a:needle))
  let haystack_ls = easycomplete#util#str2list(tolower(a:haystack))

  let cursor_n = 0
  let cursor_h = 0
  let matched = v:false

  while cursor_h < len(haystack_ls)
    if haystack_ls[cursor_h] == needle_ls[cursor_n]
      if cursor_n == len(needle_ls) - 1
        let matched = v:true
        break
      endif
      let cursor_n += 1
    endif
    let cursor_h += 1
  endwhile
  return matched
endfunction

function! s:FuzzySearchCustom(needle, haystack)
  let tlen = strlen(a:haystack)
  let qlen = strlen(a:needle)
  if qlen > tlen
    return v:false
  endif
  if qlen == tlen
    return a:needle ==? a:haystack ? v:true : v:false
  endif

  let needle_ls = easycomplete#util#str2list(tolower(a:needle))
  let haystack_ls = easycomplete#util#str2list(tolower(a:haystack))

  let i = 0
  let j = 0
  let fallback = 0
  while i < qlen
    let nch = needle_ls[i]
    let i += 1
    let fallback = 0
    while j < tlen
      if haystack_ls[j] == nch
        let j += 1
        let fallback = 1
        break
      else
        let j += 1
      endif
    endwhile
    if fallback == 1
      continue
    endif
    return v:false
  endwhile
  return v:true
endfunction

function! s:FuzzySearchPy(...)
  return call("easycomplete#python#FuzzySearchPy", a:000)
endfunction
" }}}

" ModifyInfoByMaxwidth {{{
function! easycomplete#util#ModifyInfoByMaxwidth(info, maxwidth)
  let border = " "
  let maxwidth = a:maxwidth - 2

  if type(a:info) == type("")
    if strlen(a:info) == 0
      return ""
    endif
    if trim(a:info) =~ "^-\\+$"
      return a:info
    endif
    " 字符串长度小于 maxwidth
    if strlen(a:info) <= maxwidth
      return border . a:info . border
    endif
    let span = maxwidth
    let cursor = 0
    let t_info = []
    let t_line = ""

    " 字符串长度大于 maxwidth
    while cursor <= (strlen(a:info) - 1)
      let t_line = t_line . a:info[cursor]
      if (cursor) % (span) == 0 && cursor != 0
        call add(t_info, border . t_line . border)
        let t_line = ""
      endif
      let cursor += 1
    endwhile
    if !empty(t_line)
      call add(t_info, border . t_line . border)
    endif
    " t_info is Array
    return t_info
  endif

  let t_maxwidth = 0 " 实际最大宽度
  if type(a:info) == type([])
    let t_info = []
    for item in a:info
      let modified_info_item = easycomplete#util#ModifyInfoByMaxwidth(item, maxwidth)
      if type(modified_info_item) == type("")
        if strlen(modified_info_item) > t_maxwidth
          let t_maxwidth = strlen(modified_info_item)
        endif
        call add(t_info, modified_info_item)
      endif
      if type(modified_info_item) == type([])
        let t_maxwidth = maxwidth
        let t_info = t_info + modified_info_item
      endif
    endfor

    " 构造分割线
    for i in range(len(t_info))
      let item = t_info[i]
      " 构造分割线
      if trim(item) =~ "^-\\+$"
        if t_maxwidth < maxwidth
          let t_maxwidth += 1
        elseif t_maxwidth == maxwidth
          let t_maxwidth += 2
        endif
        let t_info[i] = repeat("─", t_maxwidth)
        break
      endif
    endfor

    " hack for vim popup menu scrollbar
    if len(t_info) >= 2
      if t_info[-1] ==# ""
        unlet t_info[len(t_info)-1]
      endif
    endif
    return t_info
  endif
endfunction
" }}}

" normal mod checking {{{
function! easycomplete#util#InsertMode()
  return !easycomplete#util#NotInsertMode()
endfunction

function! easycomplete#util#NormalMode()
  if g:env_is_vim
    return mode()[0] == 'n' ? v:true : v:false
  endif
  if g:env_is_nvim
    return mode() == 'n' ? v:true : v:false
  endif
endfunction

function! easycomplete#util#NotInsertMode()
  if g:env_is_vim
    return mode()[0] != 'i' ? v:true : v:false
  endif
  if g:env_is_nvim
    return mode() == 'i' ? v:false : v:true
  endif
endfunction
" }}}

" sendkeys {{{
function! easycomplete#util#Sendkeys(keys)
  call feedkeys( a:keys, 'in' )
endfunction " }}}

" GetTypingWord {{{
function! easycomplete#util#GetTypingWord()
  if exists("g:easycomplete_cmdline_typing") && g:easycomplete_cmdline_typing == 1
    let start = getcmdpos() - 1
    let line = getcmdline()
  else
    let start = col('.') - 1
    let line = getline('.')
  endif
  let width = 0
  " 正常情况这里取普通单词逻辑不应当变化
  " 如果不同语言对单词组成字符界定不一，在主流程中处理
  " 比如 vim 把 'g:abc' 对待为一个完整单词
  if exists("g:easycomplete_cmdline_typing") && g:easycomplete_cmdline_typing == 1
    let regx = '[a-zA-Z0-9_#:@]'
  elseif exists("b:is_path_complete") && b:is_path_complete == 1
    let regx = '[$a-zA-Z0-9_#-.]'
  elseif index(["php", "javascript", "typescript"], &filetype) >= 0
    let regx = '[$a-zA-Z0-9_#]'
  elseif index(["lua"], &filetype) >= 0
    let regx = '[$a-zA-Z0-9_]'
  else
    let regx = '[a-zA-Z0-9_#]'
  endif
  while start > 0 && line[start - 1] =~ regx
    let start = start - 1
    let width = width + 1
  endwhile
  let word = strpart(line, start, width)
  return word
endfunction " }}}

" log {{{
function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! easycomplete#util#once(...)
  if get(g:, 'easycomplete_log_once')
    return
  endif
  let g:easycomplete_log_once = 1
  return call('easycomplete#util#log', a:000)
endfunction

function! easycomplete#util#log(...)
  let l:res = call('s:NormalizeLogMsg', a:000)
  call s:MsgLog(l:res, 'WarningMsg')
endfunction

function! easycomplete#util#info(...)
  let l:res = call('s:NormalizeLogMsg', a:000)
  call s:MsgLog(l:res, 'MoreMsg')
endfunction

function! easycomplete#util#NormalizeLogMsg(...)
  return call("s:NormalizeLogMsg", a:000)
endfunction

function! s:NormalizeLogMsg(...)
  let l:args = a:000
  let l:res = ""
  if empty(a:000)
    let l:res = ""
  elseif len(a:000) == 1
    if type(a:1) == type("")
      let l:res = a:1
    elseif index([2,7,0], type(a:000))
      let l:res = string(a:1)
    else
      let l:res = a:1
    endif
  else
    for item in l:args
      if type(item) == type("")
        let l:res = l:res . " " . item
      elseif type(item) == type(1)
        let l:res = l:res . " " . string(item)
      else
        let l:res = l:res . " " . json_encode(item)
      endif
    endfor
  endif
  return l:res
endfunction

function! s:MsgLog(res, style)
  redraw
  exec 'echohl ' . a:style
  echom printf('>>> %s', a:res)
  echohl NONE
endfunction
" }}}

" GotoWindow {{{
function! easycomplete#util#GotoWindow(winid) abort
  if a:winid == bufwinid(bufnr(""))
    return
  endif
  for window in range(1, winnr('$'))
    call s:GotoWinnr(window)
    if a:winid == bufwinid(bufnr(""))
      break
    endif
  endfor
endfunction

function! s:GotoWinnr(winnr) abort
  let cmd = type(a:winnr) == type(0) ? a:winnr . 'wincmd w'
        \ : 'wincmd ' . a:winnr
  noautocmd execute cmd
  call execute('redraw','silent!')
endfunction
" }}}

" NormalizeDetail {{{
function! easycomplete#util#NormalizeDetail(item, parts)
  return s:NormalizeDetail(a:item, a:parts)
endfunction " }}}

" NormalizeSignatureDetail {{{
function! easycomplete#util#NormalizeSignatureDetail(item, hl_index)
  " 后缀
  let suffix = s:NormalizeDetail(a:item, "suffixDisplayParts")
  " 前缀
  let prefix = s:NormalizeDetail(a:item, "prefixDisplayParts")
  " 分隔符
  let sepato = s:NormalizeDetail(a:item, "separatorDisplayParts")
  " 文档正文
  let docume = s:NormalizeDetail(a:item, "documentation")
  " 参数列表
  let params = []
  let l:count = 0
  for item in a:item["parameters"]
    let wrapping = ""
    if l:count == a:hl_index
      let wrapping = "`"
    endif
    call add(params, wrapping . s:NormalizeDetail(item, "displayParts")[0] . wrapping)
    let l:count += 1
  endfor
  let param_arr= prefix + [join(params, get(sepato, 0 ," "))] + suffix
  let param_line = join(param_arr, "")
  let res = [param_line]
  if !empty(docume)
    let res = res + ['--------'] + split(docume[0],"\n")
  endif
  return res
endfunction " }}}

" NormalizeDetail {{{
function! s:NormalizeDetail(item, parts)
  if !empty(get(a:item, a:parts)) && len(get(a:item, a:parts)) > 0
    let l:desp_list = []
    for dis_item in get(a:item, a:parts)
      if dis_item.text =~ "^\\(\\r\\|\\n\\)$"
        call add(l:desp_list, "")
      else
        let line_arr = split(dis_item.text, "\\n")
        if len(line_arr) == 1
          if len(l:desp_list) == 0
            let t_line = ""
          else
            let t_line = l:desp_list[-1]
          endif
          let t_line = t_line . line_arr[0]
          if len(l:desp_list) == 0
            call add(l:desp_list, t_line)
          else
            let l:desp_list[-1] = t_line
          endif
        else
          call extend(l:desp_list, line_arr)
        endif
      endif
    endfor
    return l:desp_list
  else
    return []
  endif
endfunction " }}}

" Exec cmd in window {{{
function! easycomplete#util#execute(winid, command, ...) abort
  if exists('*win_execute')
    if type(a:command) == v:t_string
      keepalt call win_execute(a:winid, a:command, get(a:, 1, ''))
    elseif type(a:command) == v:t_list
      keepalt call win_execute(a:winid, join(a:command, "\n"), get(a:, 1, ''))
    endif
  elseif has('nvim')
    if !nvim_win_is_valid(a:winid)
      return
    endif
    let curr = nvim_get_current_win()
    noa keepalt call nvim_set_current_win(a:winid)
    if type(a:command) == v:t_string
      exe get(a:, 1, '').' '.a:command
    elseif type(a:command) == v:t_list
      for cmd in a:command
        exe get(a:, 1, '').' '.cmd
      endfor
    endif
    noa keepalt call nvim_set_current_win(curr)
  else
    call s:log("Your VIM version is old. Please update your vim")
  endif
endfunction " }}}

" NormalizeEntryDetail for tsserver only {{{
function! easycomplete#util#NormalizeEntryDetail(item)
  let l:title = ""
  let l:desp_list = []
  let l:doc_list = []

  let l:title = join([
        \ get(a:item, 'kindModifiers'),
        \ get(a:item, 'name'),
        \ get(a:item, 'kind'),
        \ get(a:item, 'name')], " ")

  let l:desp_list = s:NormalizeDetail(a:item, "displayParts")
  if !empty(get(a:item, "documentation")) && len(get(a:item, "documentation")) > 0
    let l:doc_list = ["------------"] " 任意长度即可, 显示的时候回重新计算分割线宽度
    call extend(doc_list, s:NormalizeDetail(a:item, "documentation"))
  else
    let l:doc_list = []
  endif

  return [l:title] + l:desp_list + l:doc_list
endfunction
" }}}

" contains {{{
" b 字符在 a 中出现的次数
function! easycomplete#util#contains(a, b)
  let l:count = 0
  for item in easycomplete#util#str2list(a:a)
    if item == char2nr(a:b)
      let l:count += 1
    endif
  endfor
  return l:count
endfunction " }}}

" Profile {{{
function! easycomplete#util#ProfileStart()
  exec "profile start profile.log"
  exec "profile func *"
  exec "profile file *"
endfunction

function! easycomplete#util#ProfileStop()
  exec "profile pause"
endfunction
" }}}

" distinct {{{
"popup 菜单内关键词去重，只做buff、dict和lsp里的keyword去重
"snippet 不去重
function! easycomplete#util#distinct(menu_list)
  if g:env_is_nvim
    let result_items = s:easycomplete_toolkit.distinct_keywords(a:menu_list)
  else
    let result_items = s:distinct_keywords(a:menu_list)
  endif
  return result_items
endfunction

function! s:distinct_keywords(menu_list)
  if empty(a:menu_list) || len(a:menu_list) == 0
    return []
  endif
  let result_items = a:menu_list
  let buf_list = []
  for item in a:menu_list
    " if item.menu == g:easycomplete_menuflag_buf || item.menu == g:easycomplete_menuflag_dict
    if index(['buf'], get(item, 'plugin_name', '')) >= 0
      call add(buf_list, item.word)
    endif
  endfor
  for item in a:menu_list
    if index(['buf','snips'], get(item, 'plugin_name', '')) >= 0
      continue
    endif
    let word = s:GetItemWord(item)
    if index(buf_list, word) >= 0
      call filter(result_items,
            \ '!((get(v:val, "plugin_name", "") == "buf") && v:val.word ==# "' . word . '")')
    endif
  endfor
  return result_items
endfunction

" 判断 items 列表中是否包含 keyname 的项
function! easycomplete#util#HasKey(obj,keyname)
  for item in a:obj
    if (empty(item.abbr) ? item.word : item.abbr) ==# a:keyname
      return v:true
    endif
  endfor
  return v:false
endfunction
" }}}

""" {{{ BufJob Handler
function! easycomplete#util#GetCurrentPluginName(...)
  return call('easycomplete#util#GetLspPluginName', a:000)
endfunction

" g:easycomplete_jobs.vim = {
"   1:  100,
"   2:  101,
"   3:  102
"   ...
" }
function! easycomplete#util#SetBufJob(buf_nr, job_id)
  if !exists('g:easycomplete_jobs')
    let g:easycomplete_jobs = {}
  endif
  let plugin_name = easycomplete#util#GetLspPluginName(a:buf_nr)
  if !has_key(g:easycomplete_jobs, plugin_name)
    let g:easycomplete_jobs[plugin_name] = {}
  endif
  let l:jobs_holder = g:easycomplete_jobs[plugin_name]
  let l:jobs_holder[a:buf_nr] = a:job_id
endfunction

function! easycomplete#util#SetCurrentBufJob(job_id)
  call easycomplete#util#SetBufJob(bufnr(), a:job_id)
endfunction

function! easycomplete#util#DeleteBufJob(buf_nr)
  let buf_nr = a:buf_nr
  let plugin_name = easycomplete#util#GetLspPluginName(buf_nr)
  if empty(plugin_name)
    return
  endif
  if !has_key(g:easycomplete_jobs, plugin_name)
    return
  endif
  if has_key(g:easycomplete_jobs[plugin_name], buf_nr)
    unlet g:easycomplete_jobs[plugin_name][buf_nr]
  endif
endfunction

function! easycomplete#util#DelCurrentBufJob()
  call easycomplete#util#DeleteBufJob(bufnr('%'))
endfunction

function! easycomplete#util#GetBufJob(buf_nr)
  let plugin_name = easycomplete#util#GetLspPluginName(a:buf_nr)
  if !has_key(g:easycomplete_jobs, plugin_name)
    return 0
  endif
  let l:jobs_holder = g:easycomplete_jobs[plugin_name]
  return get(l:jobs_holder, a:buf_nr, 0)
endfunction

function! easycomplete#util#GetCurrentBufJob()
  return easycomplete#util#GetBufJob(bufnr())
endfunction

function! easycomplete#util#GetAllJobs()
  return g:easycomplete_jobs
endfunction
""" }}}

" AutoLoadDict {{{
function! easycomplete#util#AutoLoadDict()
  let plug_name = get(easycomplete#GetCurrentLspContext(), "name", "")
  let es_path = easycomplete#util#GetEasyCompleteRootDirectory()
  let path =  globpath(es_path, 'dict/' . plug_name. '.txt')
  if len(path) != 0 && strridx(&dictionary, path) < 0
    silent noa execute 'setlocal dictionary+='.fnameescape(path)
  endif
endfunction " }}}

" 获得插件根目录
function! easycomplete#util#GetEasyCompleteRootDirectory() "{{{
  let plugin_root = substitute(expand('<script>'), "^\\(.\\+vim-easycomplete\\)\\(.\\{\-}\\)$","\\1","g")
  let plugin_root = substitute(plugin_root, "^\\(.\\+script\\s\\)\\(.\\{\-}\\)$", "\\2", "g")
  return plugin_root
endfunction "}}}

" SnipMap {{{
function! s:get(...)
  return call('easycomplete#util#get', a:000)
endfunction

function! easycomplete#util#SnipMap(key, val)
  if !easycomplete#util#expandable(a:val)
    return a:val
  endif
  let user_data = easycomplete#util#GetUserData(a:val)
  let lsp_item = s:get(user_data, "lsp_item")
  let new_text = s:get(lsp_item, "textEdit", "newText")
  let a:val['word'] = split(new_text, "\n")[0]
  let lsp_item["insertText"] = new_text
  let new_user_data = json_encode(extend(user_data, {
        \   'lsp_item': lsp_item
        \ }))
  let a:val['user_data'] = new_user_data
  return a:val
endfunction " }}}

" TODO by jayli 2023-12-12
" This function need to be updated
" matchfuzzy is not aviable in nvim(<= 0.5.0)
" This Custom empletation is lack of sorting by matching score
" Custom MatchFuzzy {{{
function! easycomplete#util#MatchFuzzy(array, word, ...)
  let dict = exists('a:1') ? a:1 : {}
  if exists('*matchfuzzy')
    if has_key(dict, "key")
      return matchfuzzy(a:array, a:word, dict)
    else
      return matchfuzzy(a:array, a:word)
    endif
  else
    let b:easycomplete_temp_word = a:word
    if has_key(dict, "key")
      let b:easycomplete_temp_key = get(dict, "key", "")
      let ret = filter(copy(a:array),
            \ 's:FuzzySearchRegx(b:easycomplete_temp_word, get(v:val, b:easycomplete_temp_key))')
    else
      let ret = filter(copy(a:array), 's:FuzzySearchRegx(b:easycomplete_temp_word, v:val)')
    endif
    return ret
  endif
endfunction " }}}

" function_name 必须是一个全局函数字符串
" 保持和 AscynRun 参数顺序一致
function! easycomplete#util#timer_start(function_name, args, timeout) " {{{
  if g:env_is_nvim
    call s:util_toolkit.defer_fn(a:function_name, a:args, a:timeout)
  else
    call timer_start(a:timeout, {
          \ -> call(function(a:function_name), a:args)
          \ })
  endif
endfunction " }}}

function! s:ReplaceMent(abbr, positions, wrap_char) " {{{
  if g:env_is_nvim
    return s:easycomplete_toolkit.replacement(a:abbr, a:positions,  a:wrap_char)
  else
    " let letters = map(str2list(a:abbr), { _, val -> nr2char(val)})
    " 字符串形式的 lamda 表达式速度比内联函快接近一倍
    let letters = map(str2list(a:abbr), "nr2char(v:val)")
    for item in a:positions
      let fuzzy_index = item
      let letters[fuzzy_index] = a:wrap_char . letters[fuzzy_index] . a:wrap_char
    endfor
    let res_o = join(letters, "")
    let res_r = substitute(res_o, repeat(a:wrap_char, 2), "", 'g')
    return res_r
  endif
endfunction " }}}

" 把过长的字符删掉，如果不能完全匹配的情况，尽可能匹配短单词，放弃长单词
" arr: 原始 items 列表
" n: item 列表的长度，把word最长的item删除，直到符合n的长度
function! s:TrimArrayToLength(arr, n) abort
  " 如果数组长度小于等于 n，直接返回原数组
  if len(a:arr) <= a:n
    return a:arr
  endif
  let l:arr_length_arr = []
  let l:count = 0
  for item in a:arr
    call add(l:arr_length_arr, { "idx": l:count, "length" : strlen(item["word"]) })
    let l:count += 1
  endfor
  call sort(l:arr_length_arr, {a, b -> a["length"] == b["length"] ? 0 : (a["length"] > b["length"] ? 1 : -1)})
  let l:new_arr_length_arr = l:arr_length_arr[0 : a:n - 1]
  let l:ret = []
  for item in l:new_arr_length_arr
    call add(l:ret, a:arr[item["idx"]])
  endfor
  return l:ret
endfunction

" CompleteMenuFilter {{{
" 这是 Typing 过程中耗时最多的函数，决定整体性能瓶颈
" maxlength: 针对 all_menu 的一定数量的前排元素做过滤，超过的元素就丢弃，牺牲
" 匹配精度保障性能，防止 all_menu 过大时过滤耗时太久，一般设在 500
function! easycomplete#util#CompleteMenuFilter(all_menu, word, maxlength)
  let word = a:word
  if strlen(word) == 0
    let l:result_menu = a:all_menu[0 : a:maxlength]
    call sort(l:result_menu, "easycomplete#util#SortTextComparatorByLength")
    for item in l:result_menu
      let item.abbr = easycomplete#util#parseAbbr(item.abbr)
    endfor
    return l:result_menu
  endif
  if index(easycomplete#util#str2list(word), char2nr('.')) >= 0
    if exists("b:is_path_complete") && b:is_path_complete == 1
    else
      let word = substitute(word, "\\.", "\\\\\\\\.", "g")
    endif
  endif
  if exists('*matchfuzzy')
    let tt = reltime()
    " TODO here vim 里针对 g: 的匹配有 hack，word 前面减了两个字符，导致abbr
    " 和 word 不是一一对应的，通过word fuzzy 匹配的位置无法正确应用在 abbr 上
    " 这里只 hack 了 vim，其他类型的文件未测试
    let key_name = (&filetype == "vim") ? "abbr" : "word"
    if g:env_is_nvim
      " 性能：576 个元素，n 是 550, rust 耗时 8ms, lua 耗时 10ms
      " complete_menu_fuzzy_filter --------------{
      let l:ret = s:util_toolkit.complete_menu_fuzzy_filter(a:all_menu, word, key_name, a:maxlength)
      return l:ret
      " complete_menu_fuzzy_filter --------------}
    else
      " 性能：576 个元素，n 是 550  耗时 15ms
      " complete_menu_fuzzy_filter --------------{
      let all_items = s:TrimArrayToLength(a:all_menu, a:maxlength + 130)
      let matching_res = all_items->matchfuzzypos(word, {'key': key_name, 'matchseq': 1, "limit": a:maxlength})
      return s:CompleteMenuFilterVim(matching_res, word)
      " complete_menu_fuzzy_filter --------------}
    endif
  else " for nvim(<=0.5.0)
    " 完整匹配
    let original_matching_menu = []
    " 非完整匹配
    let otherwise_matching_menu = []
    " 模糊匹配结果
    let otherwise_fuzzymatching = []

    " dam: 性能均衡参数，用来控制完整匹配和模糊匹配的次数均衡
    " 通常情况下 dam 越大，完整匹配次数越多，模糊匹配次数就越少，速度越快
    " 精度越好，但下面这两种情况往往会大面积存在
    " - 大量同样前缀的单词拥挤在一起的情况，dam 越大越好
    " - 相同前缀词较少的情况，完整匹配成功概率较小，尽早结束完整匹配性能
    "   最好，这时 dam 越小越好
    " 折中设置 dam 为 100, 时间复杂度控制在O(n)
    let dam = 100
    let regx_com_times = 0
    let count_index = 0
    let all_items = a:all_menu
    let all_items_length = len(all_items)
    let word_length = strlen(a:word)

    " 先找到全部匹配的列表
    let l:count = 0
    while count_index < dam && l:count < all_items_length
      let item = all_items[l:count]
      let item_word = get(item, 'matching_word', s:GetItemWord(item))
      if a:word[0] != "_" && item_word[0] == "_"
        let item_word = substitute(item_word, "_\\+", "", "")
      endif
      let l:count += 1
      if strlen(item_word) < word_length | continue | endif
      let regx_com_times += 1
      if stridx(toupper(item_word), toupper(word)) == 0
        call add(original_matching_menu, item)
        let count_index += 1
      elseif s:FuzzySearchRegx(word, item_word)
        call add(otherwise_fuzzymatching, item)
      else
        call add(otherwise_matching_menu, item)
      endif
    endwhile

    if l:count + len(otherwise_fuzzymatching) > a:maxlength
      let maxlength = l:count + len(otherwise_fuzzymatching)
    else
      let maxlength = a:maxlength
    endif
    " 再把模糊匹配的结果找出来
    while l:count < all_items_length
      let item = all_items[l:count]
      let item_word = get(item, 'matching_word', s:GetItemWord(item))
      if a:word[0] != "_" && item_word[0] == "_"
        let item_word = substitute(item_word, "_\\+", "", "")
      endif
      let l:count += 1
      if strlen(item_word) < word_length | continue | endif
      if count_index > maxlength | break | endif
      if s:FuzzySearchRegx(word, item_word)
        call add(otherwise_fuzzymatching, item)
        let count_index += 1
      else
        call add(otherwise_matching_menu, item)
      endif
    endwhile
    if len(easycomplete#GetStuntMenuItems()) == 0
      call sort(original_matching_menu, "easycomplete#util#SortTextComparatorByLength")
    endif
    let result = original_matching_menu + otherwise_fuzzymatching
    let filtered_menu = result
    return filtered_menu
  endif
endfunction

function! s:CompleteMenuFilterVim(matching_res, word)
  let matching_res = a:matching_res
  let word = a:word
  let fullmatch_result = [] " 完全匹配
  let firstchar_result = [] " 首字母匹配
  let fuzzymatching = []
  let fuzzymatching = matching_res[0]
  let fuzzy_position = matching_res[1]
  let fuzzy_scores = matching_res[2]
  let fuzzymatch_result = []
  if g:env_is_nvim && has("nvim-0.6.1")
    let count_i = 0
    while count_i < len(fuzzymatching)
      let abbr = get(fuzzymatching[count_i], "abbr", "")
      if empty(abbr)
        let fuzzymatching[count_i]["abbr"] = fuzzymatching[count_i]["word"]
        let abbr = fuzzymatching[count_i]["word"]
      endif
      let abbr = easycomplete#util#parseAbbr(abbr)
      let fuzzymatching[count_i]["abbr"] = abbr
      let p = fuzzy_position[count_i]
      let fuzzymatching[count_i]["abbr_marked"] = s:ReplaceMent(abbr, p, "§")
      let fuzzymatching[count_i]["marked_position"] = p
      let fuzzymatching[count_i]["score"] = fuzzy_scores[count_i]

      " 进行初步分检
      if stridx(toupper(fuzzymatching[count_i]["word"]), toupper(word)) == 0
        " 完全匹配，放在fullmatch_result
        call add(fullmatch_result, fuzzymatching[count_i])
      elseif fuzzymatching[count_i]["word"][0] == word[0]
        " 首字母匹配，放在firstchar_result
        call add(firstchar_result, fuzzymatching[count_i])
      else
        " 否则就是fuzzymatch的结果，放在 fuzzymatch_result 中
        call add(fuzzymatch_result, fuzzymatching[count_i])
      endif
      let count_i += 1
    endwhile
  endif
  if len(easycomplete#GetStuntMenuItems()) == 0 && g:easycomplete_first_complete_hit == 1
    " 对fuzzymatch_result 进行长度排序
    call sort(fuzzymatch_result, "easycomplete#util#SortTextComparatorByLength")
  endif
  if g:env_is_nvim
    let filtered_menu = fullmatch_result + firstchar_result + fuzzymatch_result
  else
    let filtered_menu = fuzzymatching
  endif
  return filtered_menu
endfunction

function! easycomplete#util#ls(path)
  let result_list = []
  let is_win = has('win32') || has('win64')
  if has("python3")
    let result_list = easycomplete#python#ListDir(a:path)
  elseif !is_win && executable("ls")
    let result_list = systemlist('ls '. a:path . " 2>/dev/null")
  else
    let result_list = []
  endif
  return result_list
endfunction

function! easycomplete#util#trace(...)
  let name = exists('a:1') ? a:1 : ""
  let stack = expand('<stack>')
  let stack_list = split(stack, "\\.\\.")
  if len(stack_list) <= 2
    call s:console('easycomplete#util#trace', expand('<stack>'))
    return
  endif
  let ret = stack_list[-2]
  call s:console(name, ret, "|", expand('<stack>'))
endfunction

function! s:GetItemWord(item)
  if has_key(a:item, "matching_word")
    return a:item["matching_word"]
  endif
  let abbr = get(a:item, 'abbr', '')
  let word = get(a:item, 'word', '')
  " let t_str = empty(abbr) ? word : abbr
  let t_str = word
  let t_str = s:TrimWavyLine(t_str)
  let a:item['matching_word'] = t_str
  return t_str
endfunction

function! s:GetItemAbbr(item)
  let abbr = get(a:item, 'abbr', '')
  let word = get(a:item, 'word', '')
  let t_str = empty(abbr) ? word : abbr
  return t_str
endfunction

" GetItemAbbr {{{
function! easycomplete#util#GetItemAbbr(...)
  return call("s:GetItemAbbr", a:000)
endfunction " }}}

function! easycomplete#util#SortTextComparatorByLength(entry1, entry2)
  " 这里的比较应该基于 word
  " 这个sort只在模糊匹配时起作用，排序在前的应该是首字母匹配
  " 首字母不匹配才用得着这里的排序
  let l1 = get(a:entry1, "item_length", 0)
  let l2 = get(a:entry2, "item_length", 0)
  if empty(l1)
    let k1 = get(a:entry1,"word", "")
    if empty(k1)
      let k1 = get(a:entry1,"abbr", "")
    endif
    let l1 = strlen(k1)
    let a:entry1["item_length"] = l1
  endif
  if empty(l2)
    let k2 = get(a:entry2,"word", "")
    if empty(k2)
      let k2 = get(a:entry2,"abbr", "")
    endif
    let l2 = strlen(k2)
    let a:entry2["item_length"] = l2
  endif
  return l1 > l2
endfunction

function! easycomplete#util#PrepareInfoPlaceHolder(key, val)
  if !(has_key(a:val, "info") && type(a:val.info) == type("") && !empty(a:val.info))
    let a:val.info = ""
  endif
  let a:val.equal = 1
  return a:val
endfunction

" TODO 性能优化，4 次调用 0.09 s
function! easycomplete#util#SortTextComparatorByAlphabet(entry1, entry2)
  let k1 = has_key(a:entry1, "abbr") && !empty(a:entry1.abbr) ?
        \ a:entry1.abbr : get(a:entry1, "word","")
  let k2 = has_key(a:entry2, "abbr") && !empty(a:entry2.abbr) ?
        \ a:entry2.abbr : get(a:entry2, "word","")
  if match(k1, "_") == 0
    return v:true
  endif
  if k1 > k2
    return v:true
  else
    return v:false
  endif
  return v:false
endfunction
" }}}

" GetItemWord {{{
function! easycomplete#util#GetItemWord(...)
  return call("s:GetItemWord", a:000)
endfunction " }}}

" GetSnippetsCodeInfo {{{
" Same as easycomplete#python#GetSnippetsCodeInfo
" 实测 vim 性能比 python 快五倍
" 27 次调用，py 用时 0.012392
" 27 次调用，vim 用时0.002804
function! easycomplete#util#GetSnippetsCodeInfo(snip_object)
  let filepath = a:snip_object.filepath
  let line_number = a:snip_object.line_number

  if !exists('g:easycomplete_snip_files')
    let g:easycomplete_snip_files = {}
  endif
  if has_key(g:easycomplete_snip_files, filepath)
    let snip_ctx = get(g:easycomplete_snip_files, filepath)
  else
    let snip_ctx = readfile(filepath)
    let g:easycomplete_snip_files[filepath] = snip_ctx
  endif

  let cursor_line = line_number

  while cursor_line + 1 < len(snip_ctx)
    if match(snip_ctx[cursor_line + 1], '\(snippet\|endsnippet\)') == 0
      break
    else
      let cursor_line += 1
    endif
  endwhile
  let start_line_index = line_number
  let end_line_index = cursor_line

  return snip_ctx[start_line_index:end_line_index]
endfunction " }}}

" HasNL {{{
function! easycomplete#util#HasNL(insertText)
  let arr = easycomplete#util#str2list(a:insertText)
  return index(arr, 10) >= 0
endfunction " }}}

" expandable {{{
function! easycomplete#util#expandable(item)
  if has_key(a:item, 'user_data') && !empty(get(a:item, 'user_data', ''))
    let user_data_str = get(a:item, 'user_data', '')
    if !easycomplete#util#IsJson(user_data_str)
      return v:false
    endif

    let l:data = json_decode(user_data_str)
    if get(l:data, 'plugin_name', '') == "snips"
      return v:true
    elseif has_key(l:data, 'expandable') && get(l:data, 'expandable', 0) == 1
      return v:true
    else
      return v:false
    endif
  else
    return v:false
  endif
endfunction " }}}

" TrimFileName {{{
" 去掉前缀 file://...
function! easycomplete#util#TrimFileName(str)
  return substitute(a:str, "^file:\/\/", "", "i")
endfunction " }}}

function! easycomplete#util#GetFileName(path) " {{{
  let path  = simplify(a:path)
  let fname = fnamemodify(path, ":t")
  return fname
endfunction " }}}

" GetLspPlugin {{{
" 一个补全插件可以携带多个 LSP Server 为其工作，比如 typescript 中可以有 ts 和
" tss 两个 LSP 实现，而且可以同时生效。但实际应用中要杜绝这种情况，所以我们约
" 定一个语言当前只注册一个 LSP Server，GetLspPlugin() 即返回当前携带 LSP
" Server 的补全 Plugin 对象，而不返回一个数组
function! easycomplete#util#GetLspPlugin(...)
  let attached_plugins = call("easycomplete#util#GetAttachedPlugins", a:000)
  let ret_plugin = {}
  for plugin in attached_plugins
    if has_key(plugin, 'gotodefinition') && has_key(plugin, 'command')
      let ret_plugin = plugin
      break
    endif
  endfor
  return ret_plugin
endfunction
" }}}

" LspType {{{
" c_type is number
" return → {
"   'symble':'o',
"   'fullname':  'method',
"   'shortname': 'm'
" }
function! easycomplete#util#LspType(c_type)
  if string(a:c_type) =~ "^\\d\\{0,2}$"
    if !exists("s:easycomplete_kinds")
      let s:easycomplete_kinds = [
            \ '',
            \ 'text',
            \ 'method',
            \ 'function',
            \ 'constructor',
            \ 'field',
            \ 'variable',
            \ 'class',
            \ 'interface',
            \ 'module',
            \ 'property',
            \ 'unit',
            \ 'value',
            \ 'enum',
            \ 'keyword',
            \ 'snippet',
            \ 'color',
            \ 'file',
            \ 'reference',
            \ 'folder',
            \ 'enummember',
            \ 'constant',
            \ 'struct',
            \ 'event',
            \ 'operator',
            \ 'typeparameter',
            \ 'const'
            \ ]
    endif
    let l:kinds = s:easycomplete_kinds
    try
      let l:type_fullname = l:kinds[str2nr(a:c_type)]
      let l:type_shortname = l:type_fullname[0]
    catch
      let l:type_fullname = ""
      let l:type_shortname = ""
    endtry
  else
    let l:type_fullname = a:c_type
    if l:type_fullname == "var"
      let l:type_fullname = "variable"
    endif
    let l:type_shortname = l:type_fullname[0]
  endif
  if has_key(g:easycomplete_lsp_type_font, l:type_fullname)
    let symble = g:easycomplete_lsp_type_font[l:type_fullname]
  else
    let symble = get(g:easycomplete_lsp_type_font, l:type_shortname, l:type_shortname)
  endif
  return {
        \ 'symble': symble,
        \ 'fullname': l:type_fullname,
        \ 'shortname': l:type_shortname
        \ }
endfunction
" }}}

" FunctionSurffixMap {{{
function! easycomplete#util#FunctionSurffixMap(key, val)
  let is_func = (get(a:val,'kind_number') == 3 || get(a:val,'kind_number') == 2)
  let kind = exists('a:val.kind') ? a:val.kind : ""
  let word = exists('a:val.word') ? a:val.word : ""
  let menu = exists('a:val.menu') ? a:val.menu : ""
  let abbr = exists('a:val.abbr') ? a:val.abbr : ""
  let info = exists('a:val.info') ? a:val.info : ""
  let kind_number = exists('a:val.kind_number') ? a:val.kind_number : 0
  let user_data = exists('a:val.user_data') ? a:val.user_data : ""
  let user_data_json = exists('a:val.user_data_json') ? a:val.user_data_json : {}
  let next_to_left_paren = easycomplete#util#IsCursorNextToLeftParen()
  let ret = {
        \ "abbr":      abbr,
        \ "dup":       1,
        \ "icase":     1,
        \ "kind":      kind,
        \ "menu":      menu,
        \ "word":      word,
        \ "info":      info,
        \ "equal":     1,
        \ "user_data": user_data,
        \ "kind_number": kind_number,
        \ "user_data_json": user_data_json
        \ }
  if is_func
    if stridx(word,"(") <= 0
      " 不包含括号时，自动加上括号，考虑到右侧是否挨着左括号
      " 没括号就没有需要展开的结构，还需要简单展开即可
      let ret["word"] = word . (next_to_left_paren ? "" : "()")
      let ret['abbr'] = word . "~"
      let user_data_json_f = extend(easycomplete#util#GetUserData(a:val), {
            \ 'expandable': (next_to_left_paren ? 0 : 1),
            \ 'custom_expand': (next_to_left_paren ? 0 : 1),
            \ 'placeholder_position': (next_to_left_paren ? strlen(word) : strlen(word) + 1),
            \ 'cursor_backing_steps': (next_to_left_paren ? 0 : 1)
            \ })
      let ret['user_data'] = json_encode(user_data_json_f)
      let ret['user_data_json'] = user_data_json_f
    elseif next_to_left_paren && word[-2:] == "()"
      " 右侧挨着左括号
      let ret["word"] = word[0:-3]
      let ret['abbr'] = ret["abbr"]
      let user_data_json_f = extend(easycomplete#util#GetUserData(a:val), {
            \ 'expandable': 0,
            \ 'custom_expand': 0,
            \ 'placeholder_position': strlen(word),
            \ 'cursor_backing_steps': 0
            \ })
      let ret['user_data'] = json_encode(user_data_json_f)
      let ret['user_data_json'] = user_data_json_f
    elseif !next_to_left_paren && stridx(word,"(") > 0
      " 右侧没挨着左括号，且包含()
      " 保持原样，需要判断snip展开
      let ret["word"] = word
      let ret['abbr'] = ret['abbr']
      let user_data_json_f = extend(easycomplete#util#GetUserData(a:val), {
            \ 'expandable': 1,
            \ 'placeholder_position': strlen(word) - 1,
            \ 'cursor_backing_steps':1
            \ })
      if easycomplete#SnipExpandSupport()
        let user_data_json_f["custom_expand"] = 0
      else
        let user_data_json_f["custom_expand"] = 1
      endif
      let ret['user_data'] = json_encode(user_data_json_f)
      let ret['user_data_json'] = user_data_json_f
    endif
  endif
  return ret
endfunction " }}}

" easycomplete#util#ItemIsFromLSP()  {{{
" 判断 item 是否由 languageServer 给出
function easycomplete#util#ItemIsFromLS(item)
  let menu_str = get(a:item, "menu", "")
  if !exists("b:easycomplete_lsp_plugin")
    return v:false
  endif
  let plugin_name = get(b:easycomplete_lsp_plugin, "name", "")
  if plugin_name == "tn" | return v:false | endif
  let item_lsp_name = get(a:item, "plugin_name", "")
  if toupper(item_lsp_name) == toupper(plugin_name)
    return v:true
  else
    return v:false
  endif
endfunction " }}}

function! easycomplete#util#RemoveBracket(word)
  return substitute(a:word, '(.*)$', '', '')
endfunction

" easycomplete#util#GetLspPluginName {{{
function! easycomplete#util#GetLspPluginName(...)
  let plugin = call("easycomplete#util#GetLspPlugin", a:000)
  let plugin_name = get(plugin, 'name', "")
  return plugin_name
endfunction " }}}

" easycomplete#util#GetKindNumber(item) {{{
function! easycomplete#util#GetKindNumber(item)
  let kind_number = 0
  if !exists("g:easycomplete_stunt_menuitems") | return 0 | endif
  for item in g:easycomplete_stunt_menuitems
    if get(item, "word") ==# get(a:item, "word")
          \ && get(item, "menu") ==# get(a:item, "menu")
          \ && get(item, "kind") ==# get(a:item, "kind")
          \ && get(item, "abbr") ==# get(a:item, "abbr")
      let kind_number = get(item, 'kind_number', 0)
      break
    endif
  endfor
  return kind_number
endfunction " }}}

" easycomplete#util#GetLspItem(vim_item) {{{
" 从 vim 格式的 complete item 反查出 lsp 返回的 item 格式
function! easycomplete#util#GetLspItem(vim_item)
  let lsp_item = {}
  if !exists("g:easycomplete_stunt_menuitems") | return {} | endif
  for item in g:easycomplete_stunt_menuitems
    if get(item, "word") ==# get(a:vim_item, "word")
          \ && get(item, "menu") ==# get(a:vim_item, "menu")
          \ && get(item, "kind") ==# get(a:vim_item, "kind")
          \ && get(item, "abbr") ==# get(a:vim_item, "abbr")
      let lsp_item = get(easycomplete#util#GetUserData(item), 'lsp_item', {})
      break
    endif
  endfor
  return lsp_item
endfunction " }}}

function! s:filetype() " {{{
  return getbufvar(bufnr(), "&filetype")
endfunction " }}}

" {{{ BadBoy
" 对 lsp response 的过滤，这个过滤本来应该 lsp 给做掉，但实际 lsp
" 偷懒都给过来了, 导致渲染很慢, v:true === isBad
function! easycomplete#util#BadBoy_Nim(item, typing_word)
  return s:BadBoy.Nim(a:item, a:typing_word)
endfunction

function! easycomplete#util#BadBoy_Vim(item, typing_word)
  return s:BadBoy.Vim(a:item, a:typing_word)
endfunction

function! easycomplete#util#BadBoy_Dart(item, typing_word)
  return s:BadBoy.Dart(a:item, a:typing_word)
endfunction

let s:BadBoy = {}
function! s:BadBoy.Nim(item, typing_word)
  if &filetype != "nim" | return v:false | endif
  let word = get(a:item, "label", "")
  if empty(word) | return v:true | endif
  if len(a:typing_word) == 1
    let pos = stridx(word, a:typing_word)
    if pos >= 0 && pos <= 3
      return v:false
    else
      return v:true
    endif
  else
    if s:FuzzySearchRegx(a:typing_word, word)
      return v:false
    else
      return v:true
    endif
  endif
endfunction

" 有对应的 lua 实现 util.badboy_vim()
function! s:BadBoy.Vim(item, typing_word)
  if &filetype != "vim" | return v:false | endif
  let word = get(a:item, "label", "")
  if empty(word) | return v:true | endif
  if len(a:typing_word) == 1
    let pos = stridx(word, a:typing_word)
    if pos >= 0 && pos <= 5
      return v:false
    else
      return v:true
    endif
  else
    if s:FuzzySearchRegx(a:typing_word, word)
      return v:false
    else
      return v:true
    endif
  endif
endfunction

function! s:BadBoy.Dart(item, typing_word)
  if &filetype != "dart" | return v:false | endif
  let word = get(a:item, "label", "")
  if empty(word) | return v:true | endif
  let pos = stridx(word, a:typing_word)
  " dart e suggestion is very slow
  if a:typing_word == "e"
    if word[0] == a:typing_word
      return v:false
    else
      return v:true
    endif
  elseif len(a:typing_word) == 1
    if pos >= 0 && pos <= 3
      return v:false
    else
      return v:true
    endif
  else
    if s:FuzzySearchRegx(a:typing_word, word)
      return v:false
    else
      return v:true
    endif
  endif
endfunction
" }}}

" 判断当前文件类型是否适应当前lsp-server支持的filetype
" 用以判断lsp的行为是否执行
function! easycomplete#util#FitLspFiletype()
  let ft = s:filetype()
  let plugin_name = easycomplete#util#GetCurrentPluginName()
  let support_fts = s:get(g:easycomplete_source, plugin_name, "whitelist")
  if type(support_fts) == type([]) && index(support_fts, ft) >= 0
    return v:true
  else
    return v:false
  endif
endfunction

function! easycomplete#util#IsCursorNextToLeftParen() " {{{
  let line = getline('.')
  let col = col('.')
  if col > strlen(line)
    return v:false
  endif
  let next_char = line[col - 1]
  return next_char == '('
endfunction " }}}

" foo(aaa, bbb) → foo(${1:aaa}, ${2:bbb})
" foo(void *base, size_t nel, int (* _Nonnull compar)(const void *, const void *))
" → 
" foo(${1:void *base}, size_t nel, int (* _Nonnull compar)(const void *, const void *))
function! s:NormalizeFunctionalSnip(insertText)
  let insertText = a:insertText
  " 替换第一个参数
  " foo(aaa,bbb,ccc) → foo(${^:aaa},bbb,ccc)
  let insertText = substitute(insertText,  "\\([^()]\\{-}(\\)\\@<=\\([^,()]\\{-}\\)\\(,\\)\\@=","${`:\\2}","g")
  " 替换中间所有的参数
  " "foo(aaa,bbb,ccc,ddd) → foo(aaa,${^:bbb},${^:ccc},ddd)
  let insertText = substitute(insertText, "\\([^()]\\{-},\\)\\@<=\\([^,()]\\{-}\\)\\(,\\)\\@=","${`:\\2}","g")
  " 替换最后一个参数
  " foo(aaa,bbb,ccc,ddd) → foo(aaa,bbb,ccc,${^:ddd})
  let insertText = substitute(insertText, "\\(.\\{-},\\)\\@<=\\([^,()]\\{-}\\)\\()\\)\\@=","${`:\\2}","g")
  " 替换唯一一个参数
  " foo(aaaddd) → foo(${^:aaaddd})
  let insertText = substitute(insertText, "\\(.\\{-}(\\)\\@<=\\([^,]\\{-}\\)\\()\\)\\@=","${`:\\2}","g")
  " 把 占位符替换成数字
  let cnt = 1
  let cursor_idx = 1
  let ret_str = ""
  while cursor_idx <= strlen(insertText)
    let curr_char = insertText[cursor_idx-1]
    if curr_char == "`"
      let curr_char = string(cnt)
      let cnt = cnt + 1
    else
      let curr_char = curr_char
    endif
    let ret_str = ret_str . curr_char
    let cursor_idx += 1
  endwhile
  return ret_str
endfunction

function! easycomplete#util#NormalizeFunctionalSnip(insertText)
  return s:NormalizeFunctionalSnip(a:insertText)
endfunction

" Json encode 性能对比
" vim.fn.json_encode
"  - 10000 次  75ms
"  - 1000  次  8ms
"  - 500   次  4ms
" lua json.encode
"  - 10000 次  154ms
"  - 1000  次  15ms
"  - 500   次  8ms

" GetVimCompletionItems {{{
function! easycomplete#util#GetVimCompletionItems(response, plugin_name, word)
  let l:result = a:response['result']
  if type(l:result) == type([])
    let l:items = l:result
    let l:incomplete = 0
  elseif type(l:result) == type({})
    let l:items = l:result['items']
    let l:incomplete = get(l:result, "isIncomplete", 0)
  else
    let l:items = []
    let l:incomplete = 0
  endif

  let l:vim_complete_items = []
  let l:items_length = len(l:items)
  let typing_word = a:word
  for l:completion_item in l:items
    if &filetype == "nim" && s:BadBoy.Nim(l:completion_item, typing_word) | continue | endif
    if &filetype == "vim" && s:BadBoy.Vim(l:completion_item, typing_word) | continue | endif
    if &filetype == "dart" && s:BadBoy.Dart(l:completion_item, typing_word) | continue | endif
    let l:expandable = get(l:completion_item, 'insertTextFormat', 1) == 2
    if has_key(l:completion_item, "kind")
      let l:lsp_type_obj = easycomplete#util#LspType(l:completion_item["kind"])
      let l:kind = l:completion_item["kind"]
    else
      let l:lsp_type_obj = easycomplete#util#LspType(0)
      let l:kind = 0
    endif
    let l:menu_str = g:easycomplete_menu_abbr ? "[". toupper(a:plugin_name) ."]" : l:lsp_type_obj["fullname"]
    let l:vim_complete_item = {
          \ 'kind': l:lsp_type_obj["symble"],
          \ 'dup': 1,
          \ 'kind_number': l:kind,
          \ 'menu' : l:menu_str,
          \ 'empty': 1,
          \ 'icase': 1,
          \ 'lsp_item' : l:completion_item
          \ }

    if has_key(l:completion_item, 'textEdit') && type(l:completion_item['textEdit']) == type({})
      if has_key(l:completion_item['textEdit'], 'nextText')
        let l:vim_complete_item['word'] = l:completion_item['textEdit']['nextText']
      endif
      if has_key(l:completion_item['textEdit'], 'newText')
        let l:vim_complete_item['word'] = l:completion_item['textEdit']['newText']
      endif
    elseif has_key(l:completion_item, 'insertText') && !empty(l:completion_item['insertText'])
      let l:vim_complete_item['word'] = l:completion_item['insertText']
    else
      let l:vim_complete_item['word'] = l:completion_item['label']
    endif
    if a:plugin_name == "cpp" && l:completion_item['label'] =~ "^\\(•\\|\\s\\)" 
      let l:vim_complete_item['word'] = substitute(l:completion_item['label'], "^\\(•\\|\\s\\)", "", "g")
      let l:completion_item['label'] = l:vim_complete_item['word']
    endif

    if l:expandable
      let l:origin_word = l:vim_complete_item['word']
      let l:placeholder_regex = '\$[0-9]\+\|\${\%(\\.\|[^}]\)\+}'
      let l:vim_complete_item['word'] = easycomplete#lsp#utils#make_valid_word(
            \ substitute(l:vim_complete_item['word'],
            \ l:placeholder_regex, '', 'g'))
      let l:placeholder_position = match(l:origin_word, l:placeholder_regex)
      let l:cursor_backing_steps = strlen(l:vim_complete_item['word'][l:placeholder_position:])
      let l:vim_complete_item['abbr'] = l:completion_item['label'] . '~'
      if strlen(l:origin_word) > strlen(l:vim_complete_item['word'])
        let l:user_data_json = {
              \ 'expandable':1,
              \ 'placeholder_position': l:placeholder_position,
              \ 'cursor_backing_steps': l:cursor_backing_steps}
        let l:vim_complete_item['user_data'] = json_encode(l:user_data_json)
        let l:vim_complete_item['user_data_json'] = l:user_data_json
      endif
      let l:user_data_json_l = extend(easycomplete#util#GetUserData(l:vim_complete_item), {
            \ 'expandable': 1,
            \ })
      let l:vim_complete_item['user_data'] = json_encode(l:user_data_json_l)
      let l:vim_complete_item['user_data_json'] = l:user_data_json_l
    elseif l:completion_item['label'] =~ ".(.*)$"
      let l:vim_complete_item['abbr'] = l:completion_item['label']
      if easycomplete#SnipExpandSupport()
        let l:vim_complete_item['word'] = l:completion_item['label']
      else
        " 如果不支持snipexpand，则只做简易展开
        let l:vim_complete_item['word'] = substitute(l:completion_item['label'],"(.*)$","",'g') . "()"
      endif
        " \ 'custom_expand': 1,
      let l:vim_complete_item['user_data_json'] = {
        \ 'expandable': 1,
        \ 'placeholder_position': strlen(l:vim_complete_item['word']) - 1,
        \ 'cursor_backing_steps': 1
        \ }
      let insert_text = ""
      if a:plugin_name == "rust"
        let insert_text = get(l:completion_item, "insertText", l:completion_item["label"])
      end
      if easycomplete#SnipExpandSupport()
        " 确保 vim_complete_item['lsp_item'] 中的 insertText 是标准的 snippet
        " 格式，展开时从 lsp_item.insertText 中获取
        " let l:complete_item['insertText'] = ...
        if insert_text =~ "${\\d"
          " 如果原本就是正确的 snippet 格式
          " Do Nothing
          let l:completion_item["insertText"] = insert_text
        elseif insert_text =~ ".(.*)$"
          " 如果insertText 就是函数形式
          let l:completion_item["insertText"] = s:NormalizeFunctionalSnip(insert_text)
        elseif l:vim_complete_item["word"] =~ ".(.*)$"
          " 如果 word 是函数形式
          let l:completion_item["insertText"] = s:NormalizeFunctionalSnip(l:vim_complete_item["word"])
        else
          " 如果insertText 不是函数形式，且word也不是函数形式
          " Do nothing
          let l:completion_item["insertText"] = insert_text
        endif
      else
        let l:vim_complete_item['user_data_json']["custom_expand"] = 1
      endif
      let l:vim_complete_item["user_data"] = json_encode(l:vim_complete_item['user_data_json'])
    else
      let l:vim_complete_item['abbr'] = l:completion_item['label']
    endif
    if has_key(l:completion_item, "documentation")
      let l:t_info = s:NormalizeLspInfo(l:completion_item["documentation"])
    else
      let l:t_info = []
    endif
    if !empty(get(l:completion_item, "detail", ""))
      let l:vim_complete_item['info'] = [get(l:completion_item, "detail", "")] + l:t_info
    else
      let l:vim_complete_item['info'] = l:t_info
    endif
    let sha256_str_o = easycomplete#util#Sha256(l:vim_complete_item['word'] . string(l:vim_complete_item['info']))
    let sha256_str = strpart(sha256_str_o, 0, 15)
    let user_data_json = extend(easycomplete#util#GetUserData(l:vim_complete_item), {
          \   'plugin_name': a:plugin_name,
          \   'sha256': sha256_str,
          \   'lsp_item': l:completion_item
          \ })
    let l:vim_complete_item['user_data'] = json_encode(user_data_json)
    let l:vim_complete_item["user_data_json"] = user_data_json
    " LSP 初始化未完成时往往会返回 word 为空的一个提示: "LSP initalize not
    " ready... 0 / 40" 这里不需要
    if get(l:vim_complete_item, "word", "") != ""
      let l:vim_complete_items += [l:vim_complete_item]
    endif
    "----------------------------------
  endfor
  return { 'items': l:vim_complete_items, 'incomplete': l:incomplete }
endfunction

function! easycomplete#util#Sha256(str)
  if exists("*sha256")
    return sha256(a:str)
  elseif has("python3")
    return easycomplete#python#Sha256(a:str)
  else
    return a:str
  endif
endfunction

function! s:NormalizeLspInfo(info)
  if type(a:info) == type({})
    let info = get(a:info, "value", "")
  else
    let info = a:info
  endif
  let l:li = split(info, "\n")
  let l:str = []
  if &filetype == "vim"
    let l:str = l:li
  else
    for item in l:li
      if item ==# '```' || item =~ "^```\[a-zA-Z0-9]\\{-}$"
        continue
      endif
      call add(l:str, item)
    endfor
  endif
  return l:str
endfunction

function! easycomplete#util#NormalizeLspInfo(info)
  return s:NormalizeLspInfo(a:info)
endfunction
" }}}

" FindLspServers {{{
" s:find_complete_servers() 获取 LSP Complete Server 信息
function! easycomplete#util#FindLspServers() abort
  let l:server_names = []
  for l:server_name in easycomplete#lsp#get_allowed_servers()
    let l:init_capabilities = easycomplete#lsp#get_server_capabilities(l:server_name)
    if has_key(l:init_capabilities, 'completionProvider')
      " TODO: support triggerCharacters
      call add(l:server_names, l:server_name)
    endif
  endfor

  return { 'server_names': l:server_names }
endfunction

function! easycomplete#util#LspServerReady()
  let opt = easycomplete#GetCurrentLspContext()
  if empty(opt) || empty(easycomplete#installer#GetCommand(opt['name']))
    " 当前并未曾注册过 LSP
    return v:false
  endif
  let l:info = easycomplete#util#FindLspServers()
  let l:ctx = easycomplete#context()
  if empty(l:info['server_names'])
    " LSP 启动失败
    return v:false
  endif
  return v:true
endfunction
" }}}

" 找到 path 最近的父目录里的文件 {{{
function! easycomplete#util#FindNearestParentFile(path, filename) abort
  let l:relative_path = findfile(a:filename, a:path . ';')
  if empty(l:relative_path)
    let l:relative_path = finddir(a:filename, a:path . ';')
  endif
  if !empty(l:relative_path)
    return fnamemodify(l:relative_path, ':p')
  else
    return ''
  endif
endfunction

function! easycomplete#util#HasLua()
  if g:env_is_nvim && has("nvim-0.5.0")
    return v:true
  else
    return v:false
  endif
endfunction

function! easycomplete#util#GetDefaultRootUri()
  let current_lsp_ctx = easycomplete#GetCurrentLspContext()
  let current_file_path = fnamemodify(expand('%'), ':p:h')
  if !has_key(current_lsp_ctx, "root_uri_patterns")
    return "file://" . current_file_path
  endif
  let root_uri = ''
  for pattern in get(current_lsp_ctx, 'root_uri_patterns', [])
    let find_file = easycomplete#util#FindNearestParentFile(current_file_path, pattern)
    if find_file == ""
      continue
    else
      break
    endif
  endfor
  if find_file == ""
    let root_uri = "file://" . current_file_path
  else
    let root_uri = "file://" . fnamemodify(find_file, ':p:h')
  endif
  return root_uri
endfunction " }}}

" aop speed testing {{{
" aop 测试函数调用性能用，四种调用方式
" call emit(function('s:foo'))
" call emit('easycomplete#foo')
" call emit(function('s:foo'), [123])
" call emit('easycomplete#foo', [123])
function! easycomplete#util#emit(...)
  let Method = a:1
  let args = exists('a:2') ? a:2 : []
  call s:StartRecord()
  try
    let res = easycomplete#util#call(Method, args)
  catch /.*/
    echom v:exception
    return 0
  endtry
  call s:StopRecord(string(Method))
  return res
endfunction

" 性能调试用，使用方式
"   call s:StartRecord()
"   call s:DoSth()
"   call s:StopRecord()
function! s:StartRecord()
  if !exists("s:easycomplete_recoding_start")
    let s:easycomplete_recoding_start = []
  endif
  let s:easycomplete_recoding_start += [reltime()]
endfunction

function! s:StopRecord(...)
  let msg = exists('a:1') ? a:1 : "functinal speed"
  " get recoded start time
  if len(s:easycomplete_recoding_start) > 0
    let start_time = s:easycomplete_recoding_start[-1]
    call remove(s:easycomplete_recoding_start, -1)
    call call(function('s:console'), [msg, reltimestr(reltime(start_time))])
  endif
endfunction

function! easycomplete#util#StartRecord()
  call s:StartRecord()
endfunction

function! easycomplete#util#StopRecord(p)
  call s:StopRecord(a:p)
endfunction

" }}}

" lint trim() {{{
function! easycomplete#util#lintTrim(line_str, width, offset)
  let real_width = a:width - a:offset
  let line_str = a:line_str
  if strlen(line_str) > real_width
    return {
          \ "str": repeat(" ", a:offset) . strpart(line_str, 0, real_width),
          \ "trimed": v:true
          \ }
  else
    return {
          \ "str": repeat(" ", a:offset) . line_str . repeat(" ", real_width - strlen(line_str)),
          \ "trimed": v:false
          \ }
  endif
endfunction " }}}

" abbr: 字符串
" max_length: 最大长度
" parseAbbr {{{
function! easycomplete#util#parseAbbr(abbr)
  if g:env_is_nvim
    return s:util_toolkit.parse_abbr(a:abbr)
  else
    return s:ParseAbbr(a:abbr)
  endif
endfunction

function! s:ParseAbbr(abbr)
  let max_length = g:easycomplete_pum_maxlength
  if strlen(a:abbr) <= max_length
    if g:easycomplete_pum_fix_width == 1
      let spaces = repeat(" ", max_length - strlen(abbr))
      return abbr . spaces
    else
      return a:abbr
    endif
  else
    let short_abbr = a:abbr[0:max_length - 2] . "…"
    return short_abbr
  endif
endfunction

" fullfill {{{
" "2"   -> "002"
" "13"  -> "013"
" "234" -> "234"
function! easycomplete#util#fullfill(str)
  if strlen(a:str) == 1
    return "00" . a:str
  endif
  if strlen(a:str) == 2
    return "0" . a:str
  endif
  if strlen(a:str) >= 3
    return a:str
  endif
endfunction
" }}}

function! easycomplete#util#FileExists(file) " {{{
  let fullname = easycomplete#util#GetFullName(easycomplete#util#TrimFileName(a:file))
  try
    let content = readfile(fullname, 1)
  catch /484/
    " File is not exists or can not open
    return v:false
  endtry
  return v:true
endfunction " }}}

" TextEdit {{{
" lnum: 1,2,3
" col_start: 1,2,3
" col_end: 1,2,3
" edit_external_file: v:true/v:false
" return
"   - 1: modify existing buf
"   - 2: modify external file
"   - 0: modify nothing
function! easycomplete#util#TextEdit(filename, lnum, col_start, col_end, new_text, edit_external_file)
  let fullpath = fnamemodify(a:filename,':p')

  " edit buf
  for buf in getbufinfo()
    if !empty(getbufvar(buf['bufnr'], '&buftype')) || !(bufloaded(buf['bufnr']))
      continue
    endif
    if fnamemodify(get(buf, "name", ""), ":p") == fullpath
      let old_line = getbufline(buf['bufnr'], a:lnum, a:lnum)[0]
      let old_prefix = old_line[0:a:col_start - 2]
      let old_suffix = old_line[a:col_end:-1]
      let new_line = join([old_prefix, old_suffix], a:new_text)
      call setbufline(buf["bufnr"], a:lnum, new_line)
      return 1
      break
    endif
  endfor

  " external file
  try
    let content = readfile(fullpath, a:lnum)
  catch /484/
    " File is not exists or can not open
    return 0
  endtry
  if a:edit_external_file
    call s:EditExternalBuf(fullpath, content, a:lnum, a:col_start, a:col_end, a:new_text)
    return 2
  else
    return 0
  endif
endfunction

function! s:EditConfirmCallback(error, res)
  if a:res == 1
    let g:easycomplete_external_modified = 1
    call s:EditExternalBuf(fullpath, content, a:lnum, a:col_start, a:col_end, a:new_text)
  elseif a:res == 0
    let g:easycomplete_external_modified = -1
  endif
endfunction

function! s:EditExternalBuf(fullpath, content, lnum, col_start, col_end, new_text)
  let content = a:content
  let old_line = content[a:lnum - 1]
  let old_prefix = old_line[0:a:col_start - 2]
  let old_suffix = old_line[a:col_end:-1]
  let new_line = join([old_prefix, old_suffix], a:new_text)
  let content[a:lnum - 1] = new_line
  exec "badd " . a:fullpath
  let new_bufnr = bufnr(bufname(a:fullpath))
  call bufload(new_bufnr)
  call setbufline(new_bufnr, a:lnum, new_line)
endfunction
" }}}

function! easycomplete#util#GetBufListWithFileName() " {{{
  let buflist = []
  for buf in getbufinfo()
    if !empty(getbufvar(buf['bufnr'], '&buftype')) || !(bufloaded(buf['bufnr']))
      continue
    endif
    call add(buflist, fnamemodify(get(buf, "name", ""), ":p"))
  endfor
  return buflist
endfunction " }}}

" utils function {{{
function! easycomplete#util#IsGui()
  return (has("termguicolors") && &termguicolors == 1) ? v:true : v:false
endfunction

function! s:console(...)
  if easycomplete#log#running()
    return call('easycomplete#log#log', a:000)
  else
    return call('easycomplete#util#debug', a:000)
  endif
endfunction

function! s:trace(...)
  return call('easycomplete#util#trace', a:000)
endfunction
" }}}

function! easycomplete#util#get(obj, ...) " {{{
  let params = deepcopy(a:000)
  let tmp = a:obj
  for item in params
    let tmp = get(tmp, item, 0)
    if empty(tmp) | break | endif
  endfor
  return tmp
endfunction " }}}

" ['foo', '', 'bar', '', '', ''] → ['foo', '', 'bar']
function! easycomplete#util#RemoveTrailingEmptyStrings(list) " {{{
  while !empty(a:list) && get(a:list, -1, '') == ''
    call remove(a:list, -1)
  endwhile
  return a:list
endfunction " }}}

function! easycomplete#util#ConfigRoot() " {{{
  let config_dir = expand('~/.config/vim-easycomplete')
  return config_dir
endfunction " }}}

function! easycomplete#util#NVimLspInstallRoot() " {{{
  let config_dir = expand('~/.local/share/nvim/lsp_servers/')
  return config_dir
endfunction " }}}

function! easycomplete#util#GetConfigPath(plugin_name) " {{{
  let plugin_name = a:plugin_name
  if a:plugin_name == "tabnine"
    let plugin_name = "tn"
  endif
  let config_root = easycomplete#util#ConfigRoot()
  let config_path = config_root . '/servers/' . plugin_name . '/config.json'
  return config_path
endfunction " }}}

function! easycomplete#util#errlog(...) " {{{
  let args = a:000
  call timer_start(1, { -> easycomplete#util#call("s:errlog", args)})
endfunction " }}}

function! easycomplete#util#debug(...) " {{{
  if has('nvim')
    call call(s:util_toolkit.debug, a:000)
  endif
endfunction " }}}

function! s:errlog(...) " {{{
  let max_line = 1000
  let logfile = easycomplete#util#ConfigRoot() . "/errlog"
  if !exists("g:easy_log_file_exists") && !easycomplete#util#FileExists(logfile)
    call writefile(["----- Easycomplete Errlog ------"], logfile, "a")
  endif
  let g:easy_log_file_exists = 1
  let l:res = call('s:NormalizeLogMsg', a:000)
  if type(l:res) != type([])
    let l:res = [l:res]
  endif
  let time_stamp = strftime("%Y %b %d %X")
  let buf_name = fnamemodify(expand('%'), ':f:h')
  call map(l:res, 'time_stamp . " " . buf_name . v:val')
  let old_content = readfile(logfile, "", -1 * max_line)
  let new_content = old_content + l:res
  call writefile(new_content, logfile, "S")
endfunction " }}}
