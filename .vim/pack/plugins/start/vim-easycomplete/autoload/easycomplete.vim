" File:         easycomplete.vim
" Author:       @拔赤 <https://github.com/jayli/>
" Description:  A minimalism style complete plugin for vim/nvim
" More Info:    <https://github.com/jayli/vim-easycomplete>

if get(g:, 'easycomplete_script_loaded')
  finish
endif
let g:easycomplete_script_loaded = 1

function! easycomplete#LogStart()
  " call s:console()
  " call s:debug()
endfunction

" 全局 Complete 注册插件，其中 plugin 和 LSP Server 是包含关系
"   g:easycomplete_source['vim'].lsp 指向 lsp config
let g:easycomplete_source  = {}
" 匹配过程中的缓存，主要处理 <BS> 和 <CR> 后显示 Complete 历史
let g:easycomplete_menucache = {}
" runtime 中的 lsp jobs 和 buf 的对应关系
let g:easycomplete_jobs = {}
" 匹配过程中的全量匹配数据，CompleteDone 后置空
let g:easycomplete_menuitems = []
" 显示 complete menu 所需的临时 items，根据 maxlength 截断
let g:easycomplete_complete_ctx = {}
" 隐式匹配菜单所需的临时 items，缓存全量匹配菜单数据
let g:easycomplete_stunt_menuitems= []
" 保存 v:event.complete_item, 判断是否 pum 处于选中状态
let g:easycomplete_completed_item = {}
" 全局时间的标记，性能统计时用
let g:easycomplete_start = reltime()
" 当从 pum 最后一项继续 tab 到第一项时，此时也应当避免发生 completedone
" 需要选择匹配项过程中的过程变量 ctx 暂存下来
let g:easycomplete_firstcomplete_ctx = {}
" 和 YCM 一样，用做 FirstComplete 标志位
let g:easycomplete_first_complete_hit = 0
" 菜单显示最大 item 数量
let g:easycomplete_maxlength = (&filetype == 'vim' && !has('nvim') ? 35 : 50)
" Global CompleteChanged Event：异步回调显示 popup 时借用
let g:easycomplete_completechanged_event = {}
" 触发 lint 动作的延迟
let g:easycomplete_diagnostics_render_delay = 200
" 调用 popup 函数到弹出窗口的延迟
let g:easycomplete_popup_delay = 170
" 记录全局 showmode
let g:easycomplete_showmode = &showmode
" lsp server 是独占还是共享
let g:easycomplete_shared_lsp_server = 1
" 用来判断是否是 c-v 粘贴
let g:easycomplete_insert_char = ''
" First complete 过程中的任务队列，所有队列任务都完成后才显示匹配菜单
" [
"   {
"     "ctx": {},
"     "name": "ts",
"     "condition": 0
"     "done" : 0
"   }
" ]
let g:easycomplete_complete_taskqueue = []
" 一些主流语言的 document 的返回会自定断行，最常见的是 70 宽度来断行，比如
" python，这里留一个小的富裕，设置 80 比较合适
let g:easycomplete_popup_width = 80
" 当前敲入的字符所属的 ctx，主要用来判断光标前进还是后退
let g:easycomplete_typing_ctx = {}
let b:old_changedtick = 0
" 通过文本判断正在输入还是删除字符
let g:easycomplete_backing = 0
" <BS> 或者 <CR>, 以及其他非 ASCII 字符时的标志位
" zizz 标志位
let g:easycomplete_backing_or_cr = 0
" 用作 FirstComplete TaskQueue 回调的定时器
let s:first_render_timer = 0
" FirstCompleteRendering 中 LSP 的超时时间
let s:easycomplete_first_render_delay = 500
" lint 中 FloatWidth
let g:easycomplete_lint_float_width = 180
" 控制是否触发tabnine suggest的timer
let g:easycomplete_tabnine_suggest_timer = 0
" 防止快速换行时的密集调用带来的卡顿
let s:easycomplete_cursor_move_timer = 0
" 幽灵文本
let g:easycomplete_ghost_text_str = ""
" 快速敲击字符的 timer，只在 LazyFireTyping 时使用
let b:easycomplete_typing_timer = 0
let s:easycomplete_toolkit = g:env_is_nvim ? v:lua.require("easycomplete") : v:null
let s:util_toolkit = g:env_is_nvim ? v:lua.require("easycomplete.util") : v:null
let b:is_path_complete = 0
let b:fast_bs_timer = 0

function! easycomplete#Enable()
  call easycomplete#util#timer_start("easycomplete#_enable", [], 100)
endfunction

" EasyComplete 入口函数
function! easycomplete#_enable()
  if !easycomplete#util#EnvReady() | return | endif
  if !easycomplete#ok('g:easycomplete_enable')
    return
  endif
  call easycomplete#LogStart()
  " 插件要求在每个 BufferEnter 时调用
  if exists("b:easycomplete_loaded_done")
    return
  endif
  let b:easycomplete_loaded_done = 1
  call s:errlog("[LOG]", "Easycomplete Startup", easycomplete#util#GetCurrentFullName())
  call s:SnapShoot()
  doautocmd <nomodeline> User easycomplete_default_plugin
  doautocmd <nomodeline> User easycomplete_custom_plugin
  call s:SetCompleteOption()
  "  - 必须要确保typing command先绑定
  "  - 然后绑定插件里的typing command
  call s:BindingTypingCommandOnce()
  call easycomplete#log#init()
  call s:ConstructorCalling()
  doautocmd <nomodeline> User easycomplete_after_constructor
  call s:SetupCompleteCache()
  " lsp 服务初始化必须要放在按键绑定之后
  if !easycomplete#sources#deno#IsTSOrJSFiletype() || easycomplete#sources#deno#IsDenoProject()
    call easycomplete#lsp#enable()
  endif
  if easycomplete#ok('g:easycomplete_diagnostics_enable')
    call easycomplete#sign#init()
    call timer_start(150, {
          \  -> easycomplete#lsp#diagnostics_enable({
          \        'callback':function('easycomplete#action#diagnostics#HandleCallback')
          \     })
          \ })
  endif
  " 依次初始化字典和代码片段
  call timer_start(300, { -> easycomplete#util#AutoLoadDict() })
  call timer_start(400, { -> s:SnippetsInit()})
  exec "hi EasyLintStyle guifg=NONE"
  exec "hi EasyNone guifg=NONE"
  if g:easycomplete_winborder
    call easycomplete#ui#HiFloatBorder()
  endif
endfunction

function! s:SetCompleteOption()
  setlocal completeopt-=menu
  setlocal completeopt+=noinsert
  setlocal completeopt+=menuone
  " noselect 不作为默认选项，应当为可选配置
  " g:easycomplete_pum_noselect 和 setlocal completeopt+=noselect
  " 二选一即可
  if g:easycomplete_pum_noselect
    setlocal completeopt+=noselect
  else
    setlocal completeopt-=noselect
  endif
  setlocal completeopt-=popup
  setlocal completeopt-=preview
  setlocal completeopt-=longest
  setlocal cpoptions+=B
  if g:env_is_vim
    setlocal backspace+=indent,start
  endif
endfunction

function! easycomplete#GetBindingKeys()
  " 通用触发跟指匹配的字符绑定，所有文档类型生效
  " 另外每个插件可自定义触发按键，在插件的 semantic_triggers 中定义
  let l:key_liststr = 'abcdefghijklmnopqrstuvwxyz'.
                    \ 'ABCDEFGHIJKLMNOPQRSTUVWXYZ#$/._'
  return l:key_liststr
endfunction

function! s:BindingTypingCommandOnce()
  if get(g:, 'easycomplete_typing_binding_done')
    return
  endif
  let g:easycomplete_typing_binding_done = 1
  try
    if s:LuaSnipSupports()
      " Do nothing
    elseif s:SnipSupports()
      if g:UltiSnipsExpandTrigger ==? g:easycomplete_tab_trigger
      " Ultisnips 的默认 tab 键映射和 EasyComplete 冲突，需要先unmap掉
        exec "iunmap " . g:easycomplete_tab_trigger
      endif
    endif
  catch
    " do nothing
  endtry
  exec "inoremap <expr> " . g:easycomplete_tab_trigger . "  easycomplete#CleverTab()"
  exec "inoremap <expr> " . g:easycomplete_shift_tab_trigger . "  easycomplete#CleverShiftTab()"
  " luasnip 在选中模式下的跳转，应该闭包在 luasnip.lua 中
  " snoremap <expr> <S-Tab> easycomplete#CleverShiftTab()
  " snoremap <expr> <Tab> easycomplete#CleverTab()
  try
    exec "nnoremap <silent><unique> " . g:easycomplete_diagnostics_next . " :EasyCompleteNextDiagnostic<CR>"
    exec "nnoremap <silent><unique> " . g:easycomplete_diagnostics_prev . " :EasyCompletePreviousDiagnostic<CR>"
  catch /^Vim\%((\a\+)\)\=:E227/
    if g:easycomplete_lsp_checking != 0
      call easycomplete#util#log(
            \ '[Vim-Easycomplete Log] Diagnostic jumping map-key conflict'
            \ )
    endif
    call s:errlog("[ERR]", 'Diagnostic jumping map-key conflict', v:exception)
  endtry

  if g:easycomplete_use_default_cr
    if g:env_is_nvim
      inoremap <CR> <Plug>EasycompleteCR
    endif
  endif

  " TODO 不生效
  " inoremap <Tab> <Plug>EasycompleteTabTrigger
  " 重定向 Tag 的跳转按键绑定，和默认<c-]>功能一致
  nnoremap <silent> <c-]> :EasyCompleteGotoDefinition<CR>
  nnoremap <silent> <S-k> :EasyCompleteHover<CR>
endfunction

function! easycomplete#FileTypes(plugin_name, filetypes)
  if !exists("g:easycomplete_filetypes")
    let g:easycomplete_filetypes = {}
  endif
  let tmp_opt = get(g:easycomplete_filetypes, a:plugin_name, {"whitelist":[]})
  let added_types = get(tmp_opt, "whitelist", [])
  let ret = added_types + a:filetypes
  return ret
endfunction

" 检查当前注册的插件中所依赖的 command 是否已经安装
function! easycomplete#checking()
  call s:flush()
  let amsg = ["Checking lsp cmd tools dependencies:"]
  call add(amsg, "")
  for item in keys(g:easycomplete_source)
    let l:name = item
    if !has_key(g:easycomplete_source[item], 'command')
      continue
    endif
    let l:command = get(g:easycomplete_source[item], 'command')
    let l:flag_txt = easycomplete#installer#executable(l:command) ? "*ready*" : "|missing|"
    let l:flag_ico = easycomplete#installer#executable(l:command) ? "√" : "×"
    let l:msg = "[".l:flag_ico."]" . " " . l:name . ": `" . l:command . "` " . l:flag_txt
    call add(amsg, l:msg)
  endfor
  call add(amsg, "")
  call add(amsg, "Done")
  let current_winid = bufwinid(bufnr(""))
  vertical botright new
  setlocal previewwindow filetype=help buftype=nofile nobuflisted modifiable
  let message_winid = bufwinid(bufnr(""))
  let ix = 0
  for line in amsg
    let ix = ix + 1
    call setbufline(bufnr(""), ix, line)
  endfor
endfunction

function! easycomplete#GetAllPlugins()
  return copy(g:easycomplete_source)
endfunction

function! easycomplete#GetCurrentLspContext()
  if exists("b:easycomplete_current_lsp_context")
    return b:easycomplete_current_lsp_context
  endif
  let l:ctx_name = ''
  if empty(g:easycomplete_source)
    return {}
  endif
  for item in keys(g:easycomplete_source)
    if s:CompleteSourceReady(item)
      if has_key(get(g:easycomplete_source, item), "gotodefinition")
        let l:ctx_name = item
        break
      endif
    endif
  endfor
  let b:easycomplete_current_lsp_context = get(g:easycomplete_source, l:ctx_name, {})
  return b:easycomplete_current_lsp_context
endfunction

" Second Complete Entry
function! s:CompleteTypingMatch(...)
  if (empty(v:completed_item) && s:zizzing()) && !(s:VimColonTyping() || s:VimDotTyping())
    return
  endif

  let l:char = strpart(getline('.'), col('.') - 2, 1)

  " 非 ASCII 码时终止
  if char2nr(l:char) < 33
    call s:CloseCompletionMenu()
    call s:flush()
    return
  endif
  if char2nr(l:char) > 126
    call timer_start(4, { -> s:CloseCompletionMenu() })
    call s:flush()
    return
  endif
  if !get(g:, 'easycomplete_first_complete_hit')
    return
  endif

  let word = exists('a:1') ? a:1 : s:GetTypingWord()
  let local_menuitems = []
  if !empty(g:easycomplete_stunt_menuitems)
    let local_menuitems = g:easycomplete_stunt_menuitems
  else
    let local_menuitems = g:easycomplete_menuitems
  endif
  let filtered_menu = easycomplete#util#CompleteMenuFilter(local_menuitems, word, 250)
  if easycomplete#sources#tn#available()
    let tn_result = easycomplete#sources#tn#GetGlobalSourceItems()
  else
    let tn_result = []
  endif
  " 正常匹配为空，tabnine 结果也为空
  if len(filtered_menu) == 0 && len(tn_result) == 0
    " 正常SecondComplete中无匹配词应该关掉 pum
    if has('nvim')
      call s:CloseCompletionMenu()
      call s:CloseCompleteInfo()
    else
      call s:CloseCompletionMenu()
    endif
    let g:easycomplete_stunt_menuitems = []
    return
  endif

  " 如果正常匹配为空，但还存在旧的 TN 占位符，则物理匹配旧的占位符
  if len(filtered_menu) == 0 && len(tn_result) != 0
    if &filetype == "vim"
      let word = split(word, "#")[-1]
    endif
    let tn_result = easycomplete#util#CompleteMenuFilter(tn_result, word, 500)
    if len(tn_result) == 0
      if has('nvim')
        call s:CloseCompletionMenu()
        call s:CloseCompleteInfo()
      else
        call s:CloseCompletionMenu()
      endif
      call easycomplete#sources#tn#SetGlobalSourceItems([])
    else
      let start_pos = col('.') - strlen(word)
      " call s:SecondCompleteRendering(start_pos, tn_result)
      " 这里如果执行了匹配，tabnine 还会在 20ms
      " 后有一个返回，导致闪烁，因此这里也需要加一个延迟，而不应该直接
      " 执行 Rendering，和 SecondComplete中的逻辑一样
      call easycomplete#sources#tn#SetGlobalSourceItems(tn_result)
      let b:easycomplete_tn_match_done = 0
      call easycomplete#util#timer_start("easycomplete#UpdateTNPlaceHolder", [word], 20)
    endif
    let g:easycomplete_stunt_menuitems = []
    return
  endif

  " 如果在 VIM 中输入了':'和'.'，一旦没有匹配项，就直接清空
  " g:easycomplete_menuitems，匹配状态复位
  " 注意：这里其实区分了 跟随匹配 和 Tab 匹配两个不同的动作
  " - 跟随匹配内容尽可能少，能匹配不出东西就保持空，尽可能少的干扰
  " - Tab 匹配内容尽可能多，能多匹配就多匹配，交给用户去选择
  if (len(filtered_menu) == 0) && (s:VimDotTyping() || s:VimColonTyping())
    call s:CloseCompletionMenu()
    call s:flush()
    return
  endif
  let s:easycomplete_start_pos = col('.') - strlen(word)
  " 为了防止抖动，加上判断 tabnine 是否存在占位，如果有则立即刷新 SecondComplete
  " 如果没有则等 30 ms，尽量等 tabnine 有返回后再刷新，但 tabnine 不一定有返回
  " 但可以尽可能多的缓解抖动问题
  let l:fire_complete_immediately = v:true
  if easycomplete#sources#tn#available()
    let l:tn_ph = easycomplete#sources#tn#GetGlobalSourceItems()
    if empty(l:tn_ph)
      let l:fire_complete_immediately = v:false
    endif
  endif
  if l:fire_complete_immediately
    call s:SecondComplete(s:easycomplete_start_pos, filtered_menu, g:easycomplete_menuitems, word)
  else
    call easycomplete#util#timer_start("easycomplete#SecondComplete", [
      \   s:easycomplete_start_pos, filtered_menu, g:easycomplete_menuitems, word
      \ ], 25)
  endif
endfunction

" 这里调用是异步回来，需要记录上一次 complete 的 start_pos
" easycomplete#TabNineCompleteRendering 和 easycomplete#UpdateTNPlaceHolder
" 总会调用其中一个，旧的占位符要么被定时器更新掉，要么被TN新的返回结果更新掉
function! easycomplete#TabNineCompleteRendering()
  let current_items = g:easycomplete_stunt_menuitems[0 : g:easycomplete_maxlength]
  let tabnine_result = easycomplete#sources#tn#GetGlobalSourceItems()
  if empty(tabnine_result) | return | endif
  let result = tabnine_result + current_items
  let start_pos = empty(s:easycomplete_start_pos) ? col('.') - strlen(s:GetTypingWord()) : s:easycomplete_start_pos
  let b:easycomplete_tn_match_done = 1
  call s:SecondCompleteRendering(start_pos, result)
endfunction

function! easycomplete#UpdateTNPlaceHolder(word)
  if !exists("b:easycomplete_tn_match_done")
    let b:easycomplete_tn_match_done = 0
  endif
  if b:easycomplete_tn_match_done == 0
    let l:tn_ret = easycomplete#sources#tn#GetGlobalSourceItems()
    if empty(l:tn_ret) | return | endif
    let tabnine_result = easycomplete#util#CompleteMenuFilter(l:tn_ret, a:word, 500)
    let current_items = g:easycomplete_stunt_menuitems[0 : g:easycomplete_maxlength]
    let result = tabnine_result + current_items
    let start_pos = empty(s:easycomplete_start_pos) ? col('.') - strlen(a:word) : s:easycomplete_start_pos
    call s:SecondCompleteRendering(start_pos, result)
    call easycomplete#sources#tn#SetGlobalSourceItems(tabnine_result)
  endif
endfunction

function! s:SecondCompleteRendering(start_pos, result)
  call s:StopAsyncRun()
  if len(g:easycomplete_stunt_menuitems) < 40
    call s:AsyncRun('easycomplete#_complete', [a:start_pos, a:result], 5)
  else
    call s:AsyncRun('easycomplete#_complete', [a:start_pos, a:result], 30)
  endif
endfunction

function! easycomplete#SecondComplete(...)
  return call('s:SecondComplete', a:000)
endfunction

function! s:SecondComplete(start_pos, menuitems, easycomplete_menuitems, word)
  let tmp_menuitems = copy(a:easycomplete_menuitems)
  let g:easycomplete_stunt_menuitems = copy(a:menuitems)
  let result = a:menuitems[0 : g:easycomplete_maxlength]
  if len(result) <= 5
    let result = easycomplete#util#uniq(result)
  endif
  " 这里功能上是不必要的，因为已经输入新的字符，应该匹配出新的TN结果，而GetGlobalSourceItems
  " 返回的是旧的，这里还要加上旧结果只是为了先占位，防止删除+呈现TN新结果时的pum的抖动
  "
  " 但TN并不是每次都能有返回，如果没有返回结果时，这里的旧的占位的结果也应该更新掉，否则会
  " 出现 #368 的问题，所以要有一个定时器判断TN有没有正确的返回，如果没有正确返回，那么占位
  " 的TN的旧结果要更新掉
  if easycomplete#sources#tn#available()
    let l:tn_ret = easycomplete#sources#tn#GetGlobalSourceItems()
    let b:easycomplete_tn_match_done = 0
    let result_all = l:tn_ret + result
    call easycomplete#util#timer_start("easycomplete#UpdateTNPlaceHolder", [a:word], 20)
  else
    let result_all = [] + result
  endif
  call s:StopFirstCompleteRenderingTimer()
  call s:SecondCompleteRendering(a:start_pos, result_all)
  call s:AddCompleteCache(a:word, deepcopy(g:easycomplete_stunt_menuitems))
  " complete() 会触发 completedone 事件，会执行 s:flush()
  " 所以这里要确保 g:easycomplete_menuitems 不会被修改
  let g:easycomplete_menuitems = tmp_menuitems
endfunction

function! easycomplete#CompleteDone()
  " hack for nvim
  " 正常情况下回退会触发 completedone，进而导致popup_close，nvim
  " 中也遵循这个逻辑，需要手动再打开一下
  if g:env_is_nvim && !easycomplete#pum#visible()
    call easycomplete#util#DeleteHint()
    let g:easycomplete_ghost_text_str = ""
  endif
  if g:env_is_nvim && easycomplete#pum#visible() && easycomplete#IsBacking()
        \ && easycomplete#FirstSelectedWithOptDefaultSelected()
    call s:ShowCompleteInfoWithoutTimer()
  elseif g:env_is_nvim && easycomplete#pum#visible() && easycomplete#IsBacking()
    call easycomplete#popup#CompleteDone()
  elseif g:env_is_nvim && !easycomplete#pum#visible() && easycomplete#IsBacking()
    call s:CloseCompleteInfo()
  else
    call easycomplete#popup#CompleteDone()
  endif
  if !s:SameCtx(easycomplete#context(), g:easycomplete_firstcomplete_ctx) && !s:zizzing()
    return
  endif
  if g:env_is_nvim
    " 触发 tabnine suggest
    if !easycomplete#pum#visible() && !easycomplete#IsBacking() && easycomplete#tabnine#ready()
      call s:LazyTabNineSuggestFire(500)
    endif
    "TODO v:complete_item 是否是必须的，还需再测试一下
    if easycomplete#pum#visible() || (g:easycomplete_first_complete_hit != 1)
      call s:zizz()
      return
    endif
  else
    if pumvisible() || (empty(v:completed_item) && g:easycomplete_first_complete_hit != 1)
      call s:zizz()
      return
    endif
  endif
  call s:flush()
endfunction

function! s:LazyTabNineSuggestFire(delay)
  if g:easycomplete_tabnine_suggestion <= 0
    return
  endif
  if g:easycomplete_tabnine_suggest_timer > 0
    call timer_stop(g:easycomplete_tabnine_suggest_timer)
    let g:easycomplete_tabnine_suggest_timer = 0
  endif
  let g:easycomplete_tabnine_suggest_timer = timer_start(a:delay, { -> easycomplete#tabnine#fire() })
endfunction

function! easycomplete#WinScrolled()
  if empty(v:event) | return | endif
  let l:winid = win_getid()
  if has_key(v:event, l:winid) || has_key(v:event, easycomplete#pum#PumWinid())
    call easycomplete#pum#WinScrolled()
  endif
endfunction

" 有时候 pum_done 事件执行的比 PumClose 要快，这时判断 pumvisible 应该为 false
" 却实际上是 true，保险起见加上一个timer
function! s:CompleteDoneTeardown()
  if g:env_is_nvim && !easycomplete#pum#visible()
    call s:CloseCompleteInfo()
  endif
endfunction

function! easycomplete#InsertLeave()
  if easycomplete#ok('g:easycomplete_diagnostics_enable')
    call easycomplete#lint()
    " call easycomplete#sign#LintCurrentLine()
    call easycomplete#sign#LintPopup()
  endif
  call easycomplete#tabnine#flush()
  call s:flush()
endfunction

function! easycomplete#flush()
  call s:flush()
endfunction

" 判断 pum 是否是选中状态，兼容 nvim 和 vim
function! easycomplete#CompleteCursored()
  if g:env_is_nvim && easycomplete#pum#visible()
    return easycomplete#pum#CompleteCursored()
  elseif g:env_is_vim && pumvisible()
    return complete_info()['selected'] == -1 ? v:false : v:true
  else
    return v:false
  endif
endfunction

" 兼容nvim 和 vim
function! easycomplete#GetCursordItem()
  if easycomplete#CompleteCursored()
    if g:env_is_nvim
      return easycomplete#pum#CursoredItem()
    else
      let l:item = complete_info()["items"][complete_info()['selected']]
      return l:item
    endif
  endif
  return {}
endfunction

" typing 过程中需要即时展开completeinfo，这里先做一个判断
function! easycomplete#FirstSelectedWithOptDefaultSelected()
  if g:easycomplete_pum_noselect
    return v:false
  endif
  if g:env_is_vim && !pumvisible()
    return v:false
  endif
  if g:env_is_nvim && !easycomplete#pum#visible()
    return v:false
  endif
  if !easycomplete#CompleteCursored()
    return v:false
  endif
  let l:selected = g:env_is_nvim ?
        \ easycomplete#pum#CompleteInfo()['selected'] : complete_info()['selected']
  if l:selected == 0
    return v:true
  endif
  return v:false
endfunction

" 展开pum且已经开始选择item动作(当前Cursored的位置不是第一个)
function! easycomplete#PumSelecting()
  if easycomplete#pum#CompleteCursored()
    return v:true
  else
    return v:false
  endif
endfunction

function! easycomplete#SetCompletedItem(item)
  let g:easycomplete_completed_item = a:item
endfunction

" easycomplete#GetCompletedItem 和 easycomplete#GetCursordItem 的不同：
"  GetCompletedItem: completeopt 包含 noselect
"  时使用，选中动作可能不会补全原单词
"  GetCursordItem:   completeopt 不包含 noselect
"  时使用，每次选中动作会补全原单词
function! easycomplete#GetCompletedItem()
  return g:easycomplete_completed_item
endfunction

function! easycomplete#IsBacking()
  return g:easycomplete_backing
endfunction

function! s:TrimEnd(str)
  return substitute(a:str, "^\\(.\\{\-}\\)\\s\\+$","\\1","g")
endfunction

function! s:BackChecking()
  let curr_ctx = easycomplete#context()
  let old_ctx = deepcopy(g:easycomplete_typing_ctx)
  " call s:SnapShoot(curr_ctx)
  if empty(curr_ctx) || empty(old_ctx) | return v:false | endif
  if get(curr_ctx, 'lnum') == get(old_ctx,'lnum') && strlen(get(old_ctx,'typed',"")) >= 2
    if curr_ctx['typed'] ==# old_ctx['typed'][:-2]
      " 单行后退非到达首字母的后退
      return v:true
    endif
    if s:TrimEnd(curr_ctx['typed']) ==# s:TrimEnd(old_ctx['typed'])
          \ && strlen(curr_ctx['typed']) < strlen(old_ctx['typed'])
      " 单行回退只删除空格或者删除tab
      return v:true
    endif
    if curr_ctx['typed'] ==# old_ctx['typed'] && strlen(curr_ctx['line']) == strlen(old_ctx['line']) - 1
      " 单行在 Normal 模式下按下 s 键
      return v:true
    endif
  elseif get(curr_ctx,'lnum') == get(old_ctx,'lnum')
        \ && strlen(old_ctx['typed']) == 1 && strlen(curr_ctx['typed']) == 0
    " 单行后退到达首字母的后退
    return v:true
  elseif old_ctx['lnum'] == curr_ctx['lnum'] + 1 && old_ctx['col'] == 1
    " 隔行后退
    return v:true
  else
    return v:false
  endif
  return v:false
endfunction

function! easycomplete#BackChecking()
  return s:BackChecking()
endfunction

function! easycomplete#Up()
  if g:env_is_vim && pumvisible()
    call s:zizz()
  elseif g:env_is_nvim && easycomplete#pum#visible()
    call easycomplete#pum#prev()
    return ""
  else
    call easycomplete#popup#close("float")
  endif
  return "\<Up>"
endfunction

function! easycomplete#Down()
  if g:env_is_vim && pumvisible()
    call s:zizz()
  elseif g:env_is_nvim && easycomplete#pum#visible()
    call easycomplete#pum#next()
    return ""
  else
    call easycomplete#popup#close("float")
  endif
  return "\<Down>"
endfunction

function! easycomplete#Left()
  if g:env_is_vim
    " do nothing
  elseif g:env_is_nvim && easycomplete#pum#visible()
    call timer_start(5, { -> easycomplete#pum#close() })
  endif
  return "\<Left>"
endfunction

function! easycomplete#Right()
  if g:env_is_vim
    " do nothing
  elseif g:env_is_nvim && easycomplete#pum#visible()
    call timer_start(5, { -> easycomplete#pum#close() })
  endif
  return "\<Right>"
endfunction

" 当前文档状态的上下文
function! easycomplete#context() abort
  let l:ret = {
        \ 'bufnr':bufnr('%'),
        \ 'curpos':getcurpos(),
        \ 'changedtick': b:changedtick
        \ }
  let l:ret['lnum'] = l:ret['curpos'][1] " 行号
  let l:ret['col'] = l:ret['curpos'][2] " 列号
  let l:ret['filetype'] = &filetype " filetype
  if !exists("b:easycomplete_buffer_filepath")
    let b:easycomplete_buffer_filepath = expand('%:p') " filepath
  end
  let l:ret['filepath'] = b:easycomplete_buffer_filepath
  let l:line = getline(l:ret['lnum']) " 当前行内容
  let l:ret['line'] = l:line
  let l:ret['typed'] = strpart(l:line, 0, l:ret['col']-1) " 光标前敲入的内容
  let l:ret['char'] = strpart(l:line, l:ret['col']-2, 1) " 当前单个字符
  let l:ret['typing'] = s:GetTypingWord() " 当前敲入的单词
  let l:ret['startcol'] = l:ret['col'] - strlen(l:ret['typing']) " 单词起始位置
  return l:ret
endfunction

function! easycomplete#CheckContextSequence(ctx)
  return s:SameCtx(a:ctx, easycomplete#context())
endfunction

function! s:OrigionalPosition()
  return easycomplete#CheckContextSequence(g:easycomplete_firstcomplete_ctx)
endfunction

" 外部插件回调的 API
function! easycomplete#complete(plugin_name, ctx, startcol, items, ...) abort
  if s:NotInsertMode()
    call s:flush()
    return
  endif
  let l:ctx = easycomplete#context()
  if !s:SameCtx(a:ctx, l:ctx)
    return
  endif
  call s:SetCompleteTaskQueue(a:plugin_name, l:ctx, 1, 1)
  call s:CompleteAdd(a:items, a:plugin_name)
endfunction

function! s:CallConstructorByName(name, ctx)
  let l:opt = get(g:easycomplete_source, a:name)
  let b:constructor = get(l:opt, "constructor")
  if empty(b:constructor)
    return v:null
  endif
  if type(b:constructor) == 2 " type is function
    call b:constructor(l:opt, a:ctx)
  endif
  if type(b:constructor) == type("string") " type is string
    call call(b:constructor, [l:opt, a:ctx])
  endif
endfunction

function! s:CallCompeltorByName(name, ctx)
  let l:opt = get(g:easycomplete_source, a:name)
  if empty(l:opt) || empty(get(l:opt, "completor"))
    return v:true
  endif
  let b:completor = get(l:opt, "completor")
  if type(b:completor) == 2 " type is function
    return b:completor(l:opt, a:ctx)
  endif
  if type(b:completor) == type("string") " type is string
    return call(b:completor, [l:opt, a:ctx])
  endif
endfunction

function! easycomplete#FireCondition()
  return s:NormalTrigger() || s:SemanticTrigger()
endfunction

" 是否符合某个插件自定义的条件 trigger，包含:true, 不包含:false
function! s:SemanticTrigger()
  let flag = v:false
  for name in keys(g:easycomplete_source)
    if s:CompleteSourceReady(name) && s:SemanticTriggerForPluginName(name)
      let flag = v:true
      break
    endif
  endfor
  return flag
endfunction

function! s:SemanticTriggerForPluginName(name)
  let ctx = easycomplete#context()
  let trigger_keys = get(g:easycomplete_source[a:name], 'semantic_triggers', [])
  if empty(trigger_keys) | return v:false | endif
  for item_rgx in trigger_keys
    if ctx['typed'] =~ item_rgx
      return v:true
    endif
  endfor
  return v:false
endfunction

" 是否匹配通用字符 trigger
function! s:NormalTrigger()
  let l:char = easycomplete#context()["char"]
  if s:zizzing() && index([":",".","_","/",">"], l:char) < 0
    return v:false
  endif
  " if s:PythonColonTyping()
  "   return v:false
  " endif
  let binding_keys = easycomplete#GetBindingKeys()
  if index(easycomplete#util#str2list(binding_keys), char2nr(l:char)) >= 0
    return v:true
  endif
  return v:false
endfunction

" python 的冒号
function! s:PythonColonTyping()
  if &filetype == "python" &&
        \ easycomplete#context()['typed'] =~ "\\(\\w\\|)\\):$"
    return v:true
  else
    return v:false
  endif
endfunction

" C++ 的双冒号
function! s:CppColonTyping()
  if &filetype == "cpp" &&
        \ easycomplete#context()['typed'] =~ "\\w::$"
    return v:true
  else
    return v:false
  endif
endfunction

" C++ 的箭头
function! s:CppArrowTyping()
  if &filetype == "cpp" &&
        \ easycomplete#context()['typed'] =~ "->$"
    return v:true
  else
    return v:false
  endif
endfunction

" vim 的冒号
function! s:VimColonTyping()
  if !(&filetype == "vim")
    return v:false
  endif
  let l:typed = easycomplete#context()['typed']
  if    (
        \   l:typed =~ "\\W\\(w\\|t\\|a\\|b\\|v\\|s\\|g\\):$"
        \   ||
        \   l:typed =~ "^\\(w\\|t\\|a\\|b\\|v\\|s\\|g\\):$"
        \ )
    return v:true
  else
    return v:false
  endif
endfunction

" vim 的点号
function! s:VimDotTyping()
  if &filetype == "vim" && easycomplete#context()['typed'] =~ '\(\w\+\.\)\{-1,}$'
    return v:true
  else
    return v:false
  endif
endfunction

function! s:GetCurrentChar()
  return strpart(getline('.'), getcurpos()[2]-2, 1)
endfunction

function! easycomplete#ResetInsertChar()
  let g:easycomplete_insert_char = ""
endfunction

function! s:BackingCompleteHandler()
  let g:easycomplete_backing = 1
  let g:easycomplete_stunt_menuitems = []
  call s:zizz()
  let ctx = easycomplete#context()

  if empty(ctx["typing"]) || empty(ctx['char'])
        \ || !s:SameBeginning(g:easycomplete_firstcomplete_ctx, ctx)
    noa call s:CloseCompletionMenu()
    call s:flush()
  else
    let g:easycomplete_stunt_menuitems = []
    if !empty(g:easycomplete_menuitems)
      let g:easycomplete_stunt_menuitems = s:GetCompleteCache(s:GetTypingWordByGtx())['menu_items']
      let start_pos = col('.') - strlen(s:GetTypingWordByGtx())
      let result = g:easycomplete_stunt_menuitems[0 : g:easycomplete_maxlength]
      if g:env_is_nvim
        if g:easycomplete_ghost_text && len(result) > 0
          let ghost_text = s:GetGhostText(start_pos, result[0]["word"])
          call easycomplete#util#ShowHint(ghost_text)
          let g:easycomplete_ghost_text_str = ghost_text
        endif
        noa call easycomplete#util#timer_start("easycomplete#pum#complete", [start_pos, result], 30)
        call easycomplete#sources#tn#SetGlobalSourceItems([])
        noa call timer_start(31, { -> s:CloseCompleteInfo() && s:ShowCompleteInfoWithoutTimer()})
        " TODO here 这里的 easycomplete_pum_done 没执行？
        " pumvisible时的正常退回默认会关闭pum，关闭动作会触发completedone事件
        " 这里在nvim中模拟completedone事件
        if !empty(result)
          doautocmd <nomodeline> User easycomplete_pum_done
        else
          doautocmd <nomodeline> User easycomplete_pum_done
          call s:CloseCompleteInfo()
        endif
      else
        noa silent! call complete(start_pos, result)
      endif
    endif
  endif
endfunction

function! easycomplete#BackSpace()
  if !exists("b:fast_bs_timer")
    let b:fast_bs_timer = 0
  endif
  if b:fast_bs_timer > 0
    call timer_stop(b:fast_bs_timer)
  endif
  let b:fast_bs_timer = timer_start(70, { -> s:FastBSTimerReset()})
  " 回退过程中先处理 ghost_text 防止闪烁
  " 在tabnine.lua 中的回退事件监听里处理了
  return "\<C-H>"
endfunction

function! s:FastBSTimerReset()
  let b:fast_bs_timer = 0
endfunction

" 正常输入和退格监听函数
" for firstcompele typing and back typing
function! easycomplete#typing()
  if !easycomplete#ok('g:easycomplete_enable')
    return
  endif

  let l:curr_char = s:GetCurrentChar()

  if l:curr_char == " "
    call s:flush()
    return
  endif

  if (g:env_is_vim && pumvisible()) || (g:env_is_nvim && easycomplete#pum#visible())
    return ""
  endif

  let g:easycomplete_start = reltime()
  let back_checking = s:BackChecking()
  if g:env_is_vim && back_checking
    let g:easycomplete_backing = 1
    call s:BackingCompleteHandler()
    call s:SnapShoot()
    return ""
  endif
  if g:env_is_nvim && back_checking
    let g:easycomplete_backing = 1
    call s:BackingCompleteHandler()
    " 回退不能激发 complete
    call s:SnapShoot()
    return ""
  endif

  let g:easycomplete_backing = 0

  " 判断是否是 C-V 粘贴
  call s:AsyncRun('easycomplete#ResetInsertChar', [], 30)
  if empty(g:easycomplete_insert_char)
    return ""
  endif

  " TODO 为了防止tab补全 tabnine后自动触发complete动作，这里需要更多测试兼容性
  if s:zizzing() | return "" | endif

  if !easycomplete#FireCondition()
    " tabnine
    if s:TabnineSupports() && easycomplete#sources#tn#FireCondition()
      call s:flush()
      if g:env_is_nvim
        call s:util_toolkit.defer_fn("easycomplete#sources#tn#refresh", [v:true], 20)
      else
        call timer_start(20, { -> easycomplete#sources#tn#refresh(v:true) })
      endif
    endif
    return ""
  endif

  " hack for vim ':' typing
  if &filetype == 'vim' && l:curr_char == ":"
    if !s:VimColonTyping()
      return ""
    endif
  endif

  " vim lsp 返回结果中包含多层的对象，比如 "a.b.c"，这样在输入"." 时就需要匹配
  " 返回结果中的"."，":" 也是同理，这里只对 viml 做特殊处理
  if s:VimColonTyping()
    " continue
  elseif s:VimDotTyping()
    " continue
  elseif s:zizzing()
    return ""
  endif

  call s:SnapShoot()
  call s:StopAsyncRun()
  call s:DoComplete(v:false)
  return ""
endfunction

function! easycomplete#DoComplete(immediately)
  call s:DoComplete(a:immediately)
endfunction

" immediately: 是否立即执行 complete()
" 在 '/' 或者 '.' 触发目录匹配时立即执行
function! s:DoComplete(immediately)
  let l:ctx = easycomplete#context()
  " 过滤不连续的 '.'
  if strlen(l:ctx['typed']) >= 2 && l:ctx['char'] ==# '.'
        \ && l:ctx['typed'][l:ctx['col'] - 3] !~ '^[a-zA-Z0-9]$'
    call s:CloseCompletionMenu()
    return v:null
  endif

  " sh #!<tab> hack, bugfix #12
  if &filetype == "sh" && l:ctx['typed'] == "#!"
    call s:MainCompleteHandler()
    return v:null
  endif

  if g:env_is_vim && complete_check()
    call s:flush()
    return v:null
  endif

  " One ':' or '.', Do nothing
  if strlen(l:ctx['typed']) == 1 && (l:ctx['char'] ==# '.' || l:ctx['char'] ==# ':')
    call s:CloseCompletionMenu()
    return v:null
  endif

  " 连续两个 '.' 重新初始化 complete
  if l:ctx['char'] == '.' &&
        \ (len(l:ctx['typed']) >= 2 &&
        \ easycomplete#util#str2list(l:ctx['typed'])[-2] == char2nr('.'))
    call s:CompleteInit()
    call s:ResetCompleteCache()
  endif

  " 首次按键给一个延迟，体验更好
  if index([':','.','/'], l:ctx['char']) >= 0 || a:immediately is v:true
    let word_first_type_delay = 0
  else
    let word_first_type_delay = 5
  endif

  " typing 中的 SecondComplete 特殊字符处理
  " 特殊字符'->',':','.','::'等 在个语言中的匹配，一般要配合 lsp 一起使用，即
  " lsp给出的结果中就包含了 "a.b.c" 的提示，这时直接执行 SecondComplete 动作
  if !empty(g:easycomplete_menuitems)
    " hack for vim ':' colon typing
    if s:VimColonTyping()
      let l:vim_word = matchstr(l:ctx['typed'], '\w:$')
      call s:CompleteTypingMatch(l:vim_word)
      return v:null
    endif
  endif

  " 检查模糊匹配 fuzzy match 条件
  if !empty(g:easycomplete_menuitems)
        \ && !s:SameCtx(l:ctx, g:easycomplete_firstcomplete_ctx)
        \ && s:SameBeginning(g:easycomplete_firstcomplete_ctx, l:ctx)
    call s:CompleteTypingMatch()
    return v:null
  endif

  " 如果不是 insert 模式
  if g:env_is_nvim && mode() != 'i'
    return v:null
  endif

  " 执行 DoComplete
  call s:MainCompleteHandler()
  return v:null
endfunction

" 插件注册样例:
" call easycomplete#RegisterSource({
"     \ 'name': 'buffer',
"     \ 'allowlist': ['*'],
"     \ 'blocklist': ['go'],
"     \ 'completor': function('easycomplete#sources#buffer#completor'),
"     \ 'config': {
"     \    'max_buffer_size': 5000000,
"     \  },
"     \ })
function! easycomplete#RegisterSource(opt)
  if !has_key(a:opt, "name")
    return
  endif
  if !exists("g:easycomplete_source")
    let g:easycomplete_source = {}
  endif
  let g:easycomplete_source[a:opt["name"]] = a:opt
endfunction

function! easycomplete#UnRegisterSource(name)
  if !exists("g:easycomplete_source")
    let g:easycomplete_source = {}
    return
  endif
  if has_key(g:easycomplete_source, a:name)
    unlet g:easycomplete_source[a:name]
  endif
endfunction

function! easycomplete#RegisterLspServer(opt, config)
  let cmd = get(a:opt, 'command', '')
  if empty(cmd)
    let l:not_defined_msg = 'Plugin command name is not defined.'
    " Bugfix for #83
    if g:env_is_nvim
      call s:AsyncRun("easycomplete#util#info", [l:not_defined_msg], 1)
    else
      call easycomplete#util#info(l:not_defined_msg)
    endif
    return
  endif
  let g:easycomplete_source[a:opt["name"]].lsp = copy(a:config)
  if !easycomplete#installer#executable(cmd) && !has_key(g:easycomplete_lsp_server, a:opt["name"])
    let l:lsp_installing_msg = "'". cmd ."' is not avilable. Do ':InstallLspServer'"
    if g:easycomplete_lsp_checking
      if g:env_is_nvim
          call s:AsyncRun("easycomplete#util#info", [l:lsp_installing_msg], 1)
      else
        call easycomplete#util#info(l:lsp_installing_msg)
      endif
    endif
    let g:easycomplete_source[a:opt["name"]].lsp.ready = v:false
    return
  endif
  let g:easycomplete_source[a:opt["name"]].lsp.ready = v:true
  call easycomplete#lsp#register_server(a:config)
endfunction

function! easycomplete#GetPluginNameByLspName(lsp_name)
  let plugin_name = ""
  for item in keys(g:easycomplete_source)
    let lsp = get(g:easycomplete_source[item], 'lsp', {})
    if !empty(lsp) && lsp['name'] ==# a:lsp_name
      let plugin_name = item
      break
    endif
  endfor
  return plugin_name
endfunction

function! easycomplete#GetFirstRenderTimer()
  return s:first_render_timer
endfunction

function! easycomplete#ResetFirstRenderTimer()
  let s:first_render_timer = 0
endfunction

" 从注册的插件中依次调用每个 completor 函数，此函数只在 FirstComplete 时调用
" 每个 completor 中给出匹配结果后回调给 CompleteAdd
function! s:CompletorCallingAtFirstComplete(ctx)
  let l:ctx = a:ctx
  call s:ResetCompleteTaskQueue()
  if s:first_render_timer > 0
    call timer_stop(s:first_render_timer)
  endif
  let s:first_render_timer = timer_start(s:easycomplete_first_render_delay,
        \ { -> s:FirstCompleteRendering(
        \            s:GetCompleteCache(l:ctx['typing'])['start_pos'],
        \            s:GetCompleteCache(l:ctx['typing'])['menu_items']
        \          )
        \ })

  " TODO 原本在设计 CompletorCalling 机制时，每个CallCompeltorByName返回true时继
  " 续执行，返回false中断执行，目的是为了实现那些排他性的CompleteCalling，比如
  " path. 这样就只能串行执行每个插件的 completor()
  "
  " 但在 runtime 中不能很好的执行，因为每个 complete_plugin 的
  " completor 的调用顺序不确定，如果让所有 completor 全都异步，是可以实现排他性
  " complete的，但即便每个调用都是异步，对于 lsp request 已经发出的情况，由于不
  " 能abort掉 lsp 进程，因此还是会有返回值冲刷进 g:easycomplete_menuitems，进而
  " 污染匹配结果。
  "
  " 这里默认只有 path 唯一一个需要排他的情况，把 path 提前。
  " 设计上需要重新考虑下，是否是只能有一个排他completor，还是存在多个共存的
  " 情况，还不清楚，先这样hack掉
  try
    let source_path = ['path']
    let source_names = []

    for name in keys(g:easycomplete_source)
      if name == "path"
        continue
      endif
      if name == "snips" || name == "buf"
        " 非lsp plugin，都放后面
        call add(source_names, name)
      elseif has_key(g:easycomplete_source[name], "command")
        " lsp 需要耗时的，都放前面
        let source_names = [name] + source_names
      else
        call add(source_names, name)
      endif
    endfor
    " 最后把 source_path 放在最前面
    let source_names = source_path + source_names

    let l:count = 0
    while l:count < len(source_names)
      let item = source_names[l:count]
      let l:count += 1
      if s:CompleteSourceReady(item) && (s:NormalTrigger() || s:SemanticTriggerForPluginName(item))
        let l:cprst = s:CallCompeltorByName(item, l:ctx)
        if l:cprst == v:true " true: 继续
          continue
        else
          call s:flush()
          call s:LetCompleteTaskQueueAllDone()
          break " false: break, 只在 directory 文件目录匹配时使用
        endif
      endif
    endwhile
  catch
    call s:errlog("[ERR] Completor Calling At FirstComplete", v:exception)
    call s:flush()
  endtry
endfunction

function! s:CallCRHandlerByName(item, ctx)
  let plugin_name = get(a:item, "plugin_name", "")
  let l:opt = get(g:easycomplete_source, plugin_name)
  if empty(l:opt) || empty(get(l:opt, "cr_handler"))
    return v:false
  endif
  let b:cr_handler = get(l:opt, "cr_handler")
  if type(b:cr_handler) == 2 " type is function
    return b:cr_handler(a:item, a:ctx)
  endif
  if type(b:cr_handler) == type("string") " type is string
    return call(b:cr_handler, [a:item, a:ctx])
  endif
endfunction

function easycomplete#ConstructorCallingByName(plugin_name)
  let l:ctx = easycomplete#context()
  if s:CompleteSourceReady(a:plugin_name)
    call s:CallConstructorByName(a:plugin_name, l:ctx)
  endif
endfunction

function! s:ConstructorCalling(...)
  let l:ctx = easycomplete#context()
  for item in keys(g:easycomplete_source)
    if s:CompleteSourceReady(item)
      call s:CallConstructorByName(item, l:ctx)
    endif
  endfor
endfunction

function! easycomplete#CompleteSourceReady(name)
  return s:CompleteSourceReady(a:name)
endfunction

function! s:CompleteSourceReady(name)
  if has_key(g:easycomplete_source, a:name)
    let completor_source = get(g:easycomplete_source, a:name)
    if has_key(completor_source, 'whitelist')
      let whitelist = get(completor_source, 'whitelist')
      if index(whitelist, &filetype) >= 0 || index(whitelist, "*") >= 0
        return v:true
      else
        return v:false
      endif
    else
      return v:true
    endif
  else
    return v:false
  endif
endfunction

" 这个函数只能在 SecondComplete 过程中使用
" 用来根据 g:easycomplete_firstcomplete_ctx 和 ctx 做 diff 算出 typing word
"   For example:
"     步骤1. 输入 app 按 Tab 执行 FristComplete
"         app<Tab>
"         append
"         appendTo
"         apple
"         appleId
"         applyBufline
"
"     步骤2. 继续输入 end 执行 SecondComplete
"         append<Typing>
"         append
"         appendTo
"       这时 SecondComplete 中根据`end`过滤 FristComplete 返回的全量匹配词表
"       GetTypingWordByGtx() 即返回 `end` 被带入到 CompleteTypingMatch() 中
"
" Gtx 即 g:easycomplete_firstcomplete_ctx
function! s:GetTypingWordByGtx()
  if empty(g:easycomplete_firstcomplete_ctx)
    return ""
  endif
  let l:ctx = easycomplete#context()
  let l:gtx = g:easycomplete_firstcomplete_ctx
  let offset = l:gtx['startcol'] - l:ctx['startcol']
  return l:ctx['typed'][strlen(l:gtx['typed']) - strlen(l:gtx['typing']) - offset:]
endfunction

function! s:CompleteMatchAction()
  call s:StopZizz()
  if s:TabnineSupports()
    call easycomplete#sources#tn#refresh()
  endif
  " let l:vim_word = s:GetTypingWordByGtx() " 刚输入的单词
  let l:vim_word = easycomplete#util#GetTypingWord()
  let l:vim_char = strpart(getline('.'), col('.') - 2, 1) " 刚输入的字符
  if g:env_is_nvim && empty(l:vim_word)
    " 输入了 . 或者 : 后先 closemenu 再尝试做一次匹配
    " 也有可能输入了(，这时应该尝试执行signature
    call s:CloseCompletionMenu()
    call s:flush()
    call s:StopZizz()
    " 这里的 timer 要比 tabnine 的触发慢 20ms 以上才能正常激活 
    let local_delay = easycomplete#ok("g:easycomplete_tabnine_enable") ? 50 : 20
    if g:env_is_nvim
      call s:util_toolkit.defer_fn("easycomplete#typing", [], local_delay)
      if easycomplete#ok('g:easycomplete_signature_enable')
        call easycomplete#action#signature#LazyRunHandle()
      endif
    else
      call timer_start(local_delay, { -> easycomplete#typing() })
    endif
    return
  endif
  call s:CompleteTypingMatch(l:vim_word)
  call s:SnapShoot()
endfunction

function! s:SnapShoot(...)
  if empty(a:000)
    let l:ctx = easycomplete#context()
  else
    let l:ctx = a:1
  endif
  let g:easycomplete_typing_ctx = deepcopy(l:ctx)
endfunction

function! easycomplete#SnapShoot(...)
  return call('s:SnapShoot', a:000)
endfunction

function! easycomplete#CompleteChanged()
  " 在 SecondMatchAction 时，这里获得的是changed之前的item
  " 因此这里起作用的逻辑主要是菜单不变的情况下，只移动cursor，CompleteShow
  " 是不会触发 showinfo 的动作的
  " 还有一种情况会触发CompleteChanged，就是 SecondCompleteRendering
  " 的时机，这时就要根据 noselect 配置来判断是否默认显示 info
  if g:easycomplete_ghost_text
    " 选中第一项和未选中时的 deleteHint 去掉
    if easycomplete#CompleteCursored()
      if easycomplete#IsBacking()
        " Do Nothing
      elseif easycomplete#pum#PumSelectedIndex() > 1
        call easycomplete#util#DeleteHint()
      endif
    elseif !empty(g:easycomplete_ghost_text_str)
      " 选择一圈后回到初始状态，未选中任何选项
      call easycomplete#util#timer_start("easycomplete#util#ShowHint",
                                      \ [g:easycomplete_ghost_text_str], 1)
    endif
  endif
  let item = deepcopy(easycomplete#GetCursordItem())
  call easycomplete#SetCompletedItem(item)
  if empty(item)
    call s:CloseCompleteInfo()
    return
  endif
  " call s:SnapShoot()
  " 改成异步，避免按住tab时连续触发completechanged会频繁大量调用
  call s:StopAsyncRun()
  call s:AsyncRun("easycomplete#ShowCompleteInfoByItem", [item], 50)
  let l:event = g:env_is_vim ? v:event : easycomplete#pum#CompleteChangedEvnet()
  " Hack 所有异步获取 document 时，需要暂存 event
  let g:easycomplete_completechanged_event = deepcopy(l:event)
endfunction

function! easycomplete#CompleteShow()
  if easycomplete#FirstSelectedWithOptDefaultSelected()
    call s:ShowCompleteInfoWithoutTimer()
    if easycomplete#util#GetCurrentPluginName() == "ts"
      call timer_start(2, { -> easycomplete#sources#ts#CompleteChanged() })
    endif
  endif
  if g:easycomplete_showmode
    setlocal noshowmode
  endif
endfunction

function! s:CloseCompleteInfo()
  if g:env_is_nvim
    call easycomplete#popup#MenuPopupChanged([])
  else
    call easycomplete#popup#close("popup")
  endif
endfunction

function! easycomplete#ShowCompleteInfoByItem(item)
  let info = easycomplete#util#GetInfoByCompleteItem(copy(a:item), g:easycomplete_menuitems)
  let async = empty(info) ? v:true : v:false
  if easycomplete#util#ItemIsFromLS(a:item) &&
        \ (async || index(["rb"], easycomplete#util#GetLspPluginName()) >= 0)
    call s:StopAsyncRun()
    call s:AsyncRun('easycomplete#action#documentation#LspRequest', [a:item], 80)
  else
    if type(info) == type("")
      let info = [info]
    endif
    if exists('b:easycomplete_documentation_popup') && b:easycomplete_documentation_popup > 0
      call timer_stop(b:easycomplete_documentation_popup)
    endif
    call s:ShowCompleteInfo(info)
  endif
endfunction

function! easycomplete#ShowCompleteInfoWithoutTimer()
  call s:ShowCompleteInfoWithoutTimer()
endfunction

function! s:ShowCompleteInfoWithoutTimer()
  if !easycomplete#CompleteCursored()
    call s:CloseCompleteInfo()
    return
  endif
  if g:env_is_nvim
    let item = easycomplete#pum#CursoredItem()
  else
    let item = complete_info()["items"][complete_info()['selected']]
  endif
  if empty(item)
    call s:CloseCompleteInfo()
    return
  endif
  let info = easycomplete#util#GetInfoByCompleteItem(copy(item), g:easycomplete_menuitems)
  let async = empty(info) ? v:true : v:false
  if easycomplete#util#ItemIsFromLS(item) &&
        \ (async || index(["rb"], easycomplete#util#GetLspPluginName()) >= 0)
    call s:StopAsyncRun()
    call s:AsyncRun('easycomplete#action#documentation#LspRequest', [item], 2)
  else
    if type(info) == type("")
      let info = [info]
    endif
    " call s:ShowCompleteInfo(info)
    call easycomplete#popup#DoPopup(info, 0)
  endif
endfunction

function easycomplete#ShowCompleteInfo(info)
  call s:ShowCompleteInfo(a:info)
endfunction

function! s:ShowCompleteInfo(info)
  call easycomplete#HandleTagbarUpdateAction()
  call easycomplete#popup#MenuPopupChanged(a:info)
endfunction

function easycomplete#HandleTagbarUpdateAction()
  if easycomplete#util#TagBarExists()
    try
      call tagbar#StopAutoUpdate()
    catch /^Vim\%((\a\+)\)\=:E216/
      " Do Nothing
    endtry
  endif
endfunction

function s:ModifyInfoByMaxwidth(...)
  return call('easycomplete#util#ModifyInfoByMaxwidth', a:000)
endfunction

function! easycomplete#SetMenuInfo(name, info, menu_flag)
  for item in g:easycomplete_menuitems
    let t_name = easycomplete#util#GetItemWord(item)
    if t_name ==# a:name && get(item, "menu") ==# a:menu_flag
      let item.info = a:info
      break
    endif
  endfor
endfunction

function! easycomplete#CleverTab()
  if !easycomplete#ok('g:easycomplete_enable')
    return "\<Tab>"
  endif
  if g:env_is_vim && pumvisible()
    call s:zizz()
    return "\<C-N>"
  elseif g:env_is_nvim && easycomplete#pum#visible()
    call s:zizz()
    call easycomplete#pum#next()
    " call timer_start(5, { -> s:SnapShoot()})
    call easycomplete#util#timer_start("easycomplete#SnapShoot", [], 10)
    return easycomplete#pum#SetWordBySelecting()
  else
    if easycomplete#tabnine#SnippetReady()
      " call easycomplete#tabnine#insert()
      call s:AsyncRun('easycomplete#tabnine#insert', [], 5)
      return ""
    endif
  endif
  if mode() == "i" && &filetype == "sh" && easycomplete#context()['typed'] == "#!" && s:SnipSupports()
    " sh #!<tab> hack, bugfix #12
    " luasnip 中没有 Tab 触发展开的功能，这里只考虑 ultisnips 的情况
    call s:ExpandSnipManually("#!")
    return ""
  elseif s:LuaSnipSupports() && luaeval("require('luasnip').locally_jumpable(1)")
    " luasnip Tab Jump
    call s:zizz()
    call luaeval("require('luasnip').jump(1)")
    return ""
  elseif s:SnipSupports() && UltiSnips#CanJumpForwards()
    " ultisnips tab jump
    call s:zizz()
    call eval('feedkeys("\'. g:UltiSnipsJumpForwardTrigger .'")')
    return ""
  elseif  getline('.')[0 : col('.')-1]  =~ '^\s*$' ||
        \ getline('.')[col('.')-2 : col('.')-1] =~ '^\s$' ||
        \ len(s:StringTrim(getline('.'))) == 0
    " 空行检查:
    "   whole empty line
    "   a space char before
    "   empty line
    call s:zizz()
    return "\<Tab>"
  elseif s:CppArrowTyping()
    call s:DoTabCompleteAction()
    return ""
  elseif match(strpart(getline('.'), 0 ,col('.') - 1)[0:col('.')-1],
        \ "\\(\\w\\|\\/\\|\\.\\|\\:\\)$") < 0
    " 输入非字母表字符，同时也不是 '/' 或者 ':'
    call s:zizz()
    return "\<Tab>"
  else
    if &filetype == "none" && &buftype == "nofile"
      return "\<Tab>"
    endif
    " 插入模式下直接插入 Tab，不再作为激发键使用
    " call s:DoTabCompleteAction()
    return "\<Tab>"
  endif
endfunction

function! s:DoTabCompleteAction()
  if g:env_is_nvim
    " Hack nvim，nvim 中，在 DoComplete 中 mode() 会是 n，导致调用 flush()
    " nvim 中改用异步调用
    call s:AsyncRun("easycomplete#DoComplete", [v:true], 1)
    call s:SendKeys( "\<ESC>a" )
  elseif g:env_is_vim
    call s:DoComplete(v:true)
  endif
endfunction

" CleverShiftTab
function! easycomplete#CleverShiftTab()
  if !easycomplete#ok('g:easycomplete_enable')
    return
  endif
  call s:zizz()
  if g:env_is_vim
    return pumvisible() ? "\<C-P>" : "\<Tab>"
  else
    if easycomplete#pum#visible()
      call easycomplete#pum#prev()
      " call timer_start(5, { -> s:SnapShoot()})
      return easycomplete#pum#SetWordBySelecting()
    elseif (mode() == "i" || mode() == "s") &&
          \ s:LuaSnipSupports() && luaeval("require('luasnip').locally_jumpable(-1)")
      call luaeval("require('luasnip').jump(-1)")
      return ""
    else
      return ""
    endif
  endif
endfunction

" nvim only
function! easycomplete#CtlN()
  if easycomplete#pum#visible()
    call easycomplete#pum#next()
  endif
  return ""
endfunction

" nvim only
function! easycomplete#CtlP()
  if easycomplete#pum#visible()
    call easycomplete#pum#prev()
  endif
  return ""
endfunction

" nvim only
function! easycomplete#CtlE()
  call s:zizz()
  if easycomplete#pum#visible()
    call s:CloseCompletionMenu()
    call s:flush()
    return ""
  elseif pumvisible()
    return "\<C-E>"
  endif
  return "\<C-E>"
endfunction

function! easycomplete#Esc()
  call easycomplete#popup#close("popup")
  if easycomplete#util#InsertMode()
    call easycomplete#popup#CloseLintPopup()
  elseif easycomplete#popup#LintPopupVisible()
    " do nothing
  else
    call easycomplete#popup#close("float")
  endif
  return "\<ESC>"
endfunction

function! easycomplete#close()
  call easycomplete#popup#close()
  return easycomplete#CtlE()
endfunction

" <CR> 逻辑，主要判断是否展开代码片段
function! easycomplete#TypeEnterWithPUM()
  if !(g:easycomplete_pum_noselect)
    let l:item = easycomplete#GetCursordItem()
  else
    let l:item = easycomplete#GetCompletedItem()
  endif
  " 得到光标处单词
  let l:word = matchstr(getline('.'), '\S\+\%'.col('.').'c')
  if (g:env_is_vim && pumvisible()) || (g:env_is_nvim && easycomplete#pum#visible())
    " 选中目录
    if (!empty(l:item) && (get(l:item, "menu") ==# "[Dir]" || get(l:item, "menu") ==# "folder"))
      " call s:AsyncRun("easycomplete#DoComplete", [v:true], 60)
      call timer_start(80, { -> s:DoTabCompleteAction() })
      return s:CtrlY()
    endif
    if !empty(l:item) && s:CallCRHandlerByName(l:item, g:easycomplete_typing_ctx) && !s:zizzing()
      call s:zizz()
      return s:CtrlY()
    endif
    " 未选中任何单词，直接回车，直接关闭匹配菜单
    if (s:SnipSupports() || s:LuaSnipSupports()) && empty(l:item) && !s:zizzing()
      call s:zizz()
      return s:CtrlY()
    endif
    " 其他选中动作一律插入单词并关闭匹配菜单
    call s:zizz()
    " snippets 的逻辑不会走这里，这里只处理lsp带的snip返回
    if easycomplete#util#expandable(l:item)
      " 新增 expandable 支持 for #48
      let oitems = easycomplete#util#GetLspItem(l:item)
      let insert_text = get(oitems, 'insertText', '')
      let user_data = easycomplete#util#GetUserData(l:item)
      let custom_expand = get(user_data, 'custom_expand', 0)
      let is_snips = (get(user_data, 'plugin_name', '') == "snips" ? v:true : v:false)
      if custom_expand
        " 简易展开
        let l:back = get(json_decode(l:item['user_data']), 'cursor_backing_steps', 0)
        call timer_start(40, {
              \ -> easycomplete#CursorExpandableSnipBackword(l:back)
              \ })
      elseif is_snips
        " 如果源是 snips
        call easycomplete#sources#snips#cr(l:item, {})
        return s:FlushCtrlY()
      elseif !empty(insert_text) && s:LuaSnipSupports()
        " lsp 返回的 snip: 如果支持 luaSnip，则用 luasnip 展开
        call timer_start(10, {
              \ -> easycomplete#sources#snips#ExpandLuaSnipManually(insert_text)
              \ })
        return s:FlushCtrlY()
      elseif !empty(insert_text) && s:SnipSupports()
        " lsp 返回的 snip: 如果支持 ultiSnip，则用 ultisnip 展开
        let word = get(l:item, "word")
        call s:AsyncRun("UltiSnips#Anon",[insert_text, word], 60)
        call timer_start(30, { -> call(function("UltiSnips#Anon"), [insert_text, word])})
        return s:FlushCtrlY()
        " TODO 把光标 cursor 到正确的位置
        " call timer_start(170, { -> s:HandleLspSnipPosition(oitems)})
      else
        " do nothing
      endif
      if easycomplete#ok('g:easycomplete_signature_enable')
        call s:AsyncRun("easycomplete#action#signature#do",[], 60)
      endif
    endif
    return s:CtrlY()
  else " 如果没有 pum，正常回车
    return "\<CR>"
  endif
endfunction

" 强制关闭，把已经匹配的单词也删掉
function! s:FlushCtrlY()
  let ret_str = easycomplete#pum#ResetBSOperatorStr()
  call s:CloseCompletionMenu()
  call s:flush()
  return ret_str
endfunction

" pumvisible 情况下，填入选中的单词，并关闭 pum
" Normal CtrlY
function! s:CtrlY()
  if g:env_is_vim
    return "\<C-Y>"
  else
    let ret_str = easycomplete#pum#SetWordBySelecting()
    call s:CloseCompletionMenu()
    call s:flush()
    return ret_str
  endif
endfunction

function! s:HandleLspSnipPosition(lsp_item)
  let start = s:get(a:lsp_item, "textEdit", "range", "start")
  if empty(start)
    return
  endif
  call s:CursorExpandableSnipPosition(s:get(start, "line"),
        \ s:get(start, "character"), s:get(a:lsp_item, "textEdit", "newText"))
endfunction

function! s:CursorExpandableSnipPosition(start_line, start_row, insertText)
  let lines = split(a:insertText, "\n")
  let lines_no = len(lines)
  let backline = lines_no - a:start_line
  let cursor_line = getcurpos()[1] - backline
  let cursor_row = a:start_row
  " call cursor(cursor_line, cursor_row)
endfunction

function! easycomplete#CursorExpandableSnipBackword(back)
  call cursor(getcurpos()[1], getcurpos()[2] - a:back)
endfunction

function! s:cursor(line, row)
  call cursor(line, row)
endfunction

function! s:ExpandSnipManually(...)
  return call('easycomplete#sources#snips#ExpandSnipManually', a:000)
endfunction

function! s:SendKeys(keys)
  call feedkeys(a:keys, 'in')
endfunction

function! s:StringTrim(str)
  return easycomplete#util#trim(a:str)
endfunction

" close pum
function! s:CloseCompletionMenu()
  if g:env_is_nvim
    if easycomplete#pum#visible()
      call timer_start(5, { -> easycomplete#pum#close() })
      call s:zizz()
    endif
  else
    if pumvisible()
      if !(g:easycomplete_pum_noselect)
        call timer_start(10, { -> s:SendKeys("\<Esc>a")})
      else
        silent! noa call s:SendKeys("\<C-Y>")
      endif
      call s:zizz()
    endif
  endif
  call s:ResetCompletedItem()
endfunction

function! s:MainCompleteHandler()
  call s:StopAsyncRun()
  if s:NotInsertMode() && g:env_is_vim | return | endif
  let l:ctx = easycomplete#context()
  " 执行 complete action 之前最后一道严格拦截，只对这几个末尾特殊字符放行
  let l:checking = [':','.','/','>',"@","$"]
  if &filetype == "json"
    call extend(l:checking, ['"'])
  endif
  if strwidth(l:ctx['typing']) == 0 && index(l:checking, l:ctx['char']) < 0
    return
  endif
  " 以上所有步骤都是特殊情况的拦截，后续逻辑应当完全交给 LSP 插件来做标准处
  " 理，原则上后续处理不应当做过多干扰，是什么结果就是什么结果了，除非严重错误，
  " 否则不应该在后续链路做 Hack 了
  call s:flush()
  call s:CompleteInit()
  call s:CompletorCallingAtFirstComplete(l:ctx)
  " 记录 g:easycomplete_firstcomplete_ctx 的时机，最早就是这里
  let g:easycomplete_firstcomplete_ctx = l:ctx
endfunction

function! s:CompleteInit(...)
  if !exists('a:1')
    let l:word = s:GetTypingWord()
  else
    let l:word = a:1
  endif
  " 这会导致 pum 闪烁
  let g:easycomplete_menuitems = []
  " 用一个延时来避免闪烁
  if exists('g:easycomplete_visual_delay') && g:easycomplete_visual_delay > 0
    call timer_stop(g:easycomplete_visual_delay)
  endif
  let g:easycomplete_visual_delay = timer_start(100, function("s:CompleteMenuResetHandler"))
endfunction

function! s:CompleteMenuResetHandler(...)
  if s:NotInsertMode() | return |endif
  if !exists("g:easycomplete_menuitems") || empty(g:easycomplete_menuitems)
    call s:CloseCompletionMenu()
  endif
endfunction

function! s:Has_Shift_K_Map()
  let maps = execute('map <s-k>')
  if maps =~ "EasyCompleteHover"
    return v:true
  else
    return v:false
  endif
endfunction

function! easycomplete#CompleteAdd(menu_list, plugin_name)
  if !s:CheckCompleteTaskQueueAllDone()
    if s:zizzing() | return | endif
  endif
  if s:NotInsertMode() | return |endif
  if !exists('g:easycomplete_menucache')
    call s:SetupCompleteCache()
  endif

  if !exists('g:easycomplete_menuitems')
    let g:easycomplete_menuitems = []
  endif

  if type(a:menu_list) != type([]) || empty(a:menu_list)
    if s:CheckCompleteTaskQueueAllDone()
      " continue
    else
      return
    endif
  endif

  if easycomplete#CompleteCursored()
    if g:env_is_nvim
      call s:CloseCompletionMenu()
    else
      call feedkeys("\<C-E>")
    endif
  endif


  " FristComplete 的过滤方法重写了
  " 为了避免重复过滤，去掉了这里的 CompleteMenuFilter 动作
  " 这里只做 CombineAllMenuitems 动作，在 Render 时一次性做过滤
  let typing_word = s:GetTypingWord()
  let new_menulist = a:menu_list
  if empty(new_menulist)
    let g:easycomplete_source[a:plugin_name].complete_result = []
  else
    call easycomplete#StoreCompleteSourceItems(a:plugin_name, a:menu_list)
  endif
  let g:easycomplete_menuitems = s:CombineAllMenuitems()
  let g_easycomplete_menuitems = deepcopy(g:easycomplete_menuitems)
  let filtered_menu = g_easycomplete_menuitems
  let start_pos = col('.') - strwidth(typing_word)

  if a:plugin_name == "path"
    " let typed = strpart(getline('.'), 0, col('.') - 1)
    " let start_pos = strwidth(typed) - strwidth(fnamemodify(typed, ":t"))
    let b:is_path_complete = 1
  else
    let b:is_path_complete = 0
  endif

  try
    call s:FirstComplete(start_pos, filtered_menu)
  catch /^Vim\%((\a\+)\)\=:E730/
    return v:null
  endtry
  if g:env_is_vim
    call easycomplete#popup#close("popup")
  endif
endfunction

function! easycomplete#GetStuntItems()
  let arr = []
  for item in g:easycomplete_stunt_menuitems
    call add(arr, get(item, "word"))
  endfor
  return arr
endfunction

function! easycomplete#StoreCompleteSourceItems(plugin_name, result)
  " let tt = reltime()
  if g:env_is_nvim
    let norm_menu_list = s:util_toolkit.final_normalize_menulist(a:result, a:plugin_name)
  else
    let norm_menu_list = s:FinalNormalizeMenulist(a:result, a:plugin_name)
  endif
  " call s:console(a:plugin_name, reltimestr(reltime(tt)))
  if a:plugin_name == "tn"
    let sort_menu_list = norm_menu_list
  else
    let sort_menu_list = s:NormalizeSort(norm_menu_list)
  endif
  let g:easycomplete_source[a:plugin_name].complete_result = deepcopy(sort_menu_list)
endfunction

function! s:CombineAllMenuitems()
  let result = []
  for name in keys(g:easycomplete_source)
    if name == "tn" | continue | endif
    call extend(result, get(g:easycomplete_source[name], 'complete_result', []))
  endfor
  return result
endfunction

" FirstComplete: 只做首次匹配
" SecondComplete: 做二次匹配
function! s:FirstComplete(start_pos, menuitems)
  if s:zizzing() | return | endif
  if s:CheckCompleteTaskQueueAllDone()
    if len(a:menuitems) == 1 &&
          \ easycomplete#util#GetPluginNameFromUserData(a:menuitems[0]) ==# "buf"
      if a:menuitems[0]["word"] == expand("<cword>")
        call s:flush()
        return
      endif
    endif
    call s:FirstCompleteRendering(a:start_pos, a:menuitems)
  endif
endfunction

function! easycomplete#zizzing()
  return s:zizzing()
endfunction

function! easycomplete#GetOptions(name)
  return get(g:easycomplete_source, a:name, {})
endfunction

function! easycomplete#FirstCompleteRendering(...)
  return call("s:FirstCompleteRendering", a:000)
endfunction

function! easycomplete#GetPlugNameByCommand(cmd)
  let plug_name = ""
  for name in keys(g:easycomplete_source)
    if a:cmd == get(g:easycomplete_source[name], 'command', '')
      let plug_name = name
      break
    endif
  endfor
  return plug_name
endfunction

function! s:StopFirstCompleteRenderingTimer()
  if s:first_render_timer > 0
    call timer_stop(s:first_render_timer)
    let s:first_render_timer = 0
  endif
endfunction

function! s:FirstCompleteRendering(start_pos, menuitems)
  if easycomplete#util#NotInsertMode()
    call s:flush()
    return
  endif
  call s:StopFirstCompleteRenderingTimer()
  " 如果 copilot.nvim 已经给了提示，那么就暂停展示 pum
  if exists("g:copilot_ready") && g:copilot_ready && copilot#copilot_snippet_ready()
    call s:flush()
    return
  endif
  let l:ctx = easycomplete#context()
  let typing_word = l:ctx["typing"]
  if b:is_path_complete
    let typing_word = easycomplete#util#GetFileName(l:ctx["typed"])
  endif
  let should_stop_render = 0
  try
    if s:OrigionalPosition()
      " 如果 LSP 结果返回时没有前进 typing，就返回结果过滤呈现即可
      let source_result = a:menuitems
    elseif !empty(typing_word) && l:ctx["typed"] =~ "[a-zA-Z0-9#]$"
      " FirstTyping 已经发起 LSP Action，结果返回之前又前进 Typing，直接执行
      " easycomplete#typing() → s:CompleteTypingMatch()，叠加之前请求 LSP 的返
      " 回值后进行重新过滤呈现
      let source_result = a:menuitems + g:easycomplete_stunt_menuitems
    else
      if (g:env_is_vim && !pumvisible()) || (g:env_is_nvim && !easycomplete#pum#visible())
        let should_stop_render = 1
      endif
    endif

    if !should_stop_render && len(source_result) > 0
      if b:is_path_complete
        let filtered_menu = deepcopy(source_result)
      else
        " distinct 只去重 bufkeyword 和 dict
        let tmp_result = easycomplete#util#distinct(deepcopy(source_result))
        let tt = reltime()
        " 过滤出 350 个字符是 17ms
        let filtered_menu = easycomplete#util#CompleteMenuFilter(tmp_result, typing_word, 350)
        " call s:console(reltimestr(reltime(tt)),len(filtered_menu))
      endif
      let filtered_menu = map(filtered_menu, function("easycomplete#util#PrepareInfoPlaceHolder"))
      let g:easycomplete_stunt_menuitems = filtered_menu
      let result = filtered_menu[0 : g:easycomplete_maxlength]
      if len(result) <= 10
        let result = easycomplete#util#uniq(result)
      endif

      if len(result) == 1 &&
            \ result[0]["word"] == typing_word &&
            \ easycomplete#util#GetPluginNameFromUserData(result[0]) == "buf"
        let result = []
      endif

      " tabnine
      if easycomplete#sources#tn#available()
        let tabnine_result = easycomplete#sources#tn#GetGlobalSourceItems()
        let result = tabnine_result + copy(result)
      endif

      " Info: 调用 complete 有两种方法
      "    第一种是直接执行 complete, complete(a:start_pos, result)
      "    第二种是通过<Plug>Complete,easycomplete#_complete(a:start_pos, result)
      " 第一种优势是不会造成 mode() 的切换，避免 CmdlineEnter 和 CmdlineLeave
      " 事件发生，杜绝 statusline 的闪烁，缺点是不通过cmd队列来显示的话，容易
      " 在连续快速敲击键盘时渲染菜单动作的进程挤占，带来不必要的菜单render视觉破损
      " 第二种优势是通过事件队列来管理，菜单高速连续切换显示时比较流畅，但在首
      " 次FirstComplete当匹配菜单内容过大、计算量过重时，带来的延时会造成明显
      " 的 CmdlineEnter 和 CmdlineLeave，带来 statusline 闪烁。
      " 因此在 FirstComplete 时采用方法一，SecondComplete 采用方法二
      call easycomplete#tabnine#flush()
      noa call s:complete(a:start_pos, result)
      call easycomplete#util#timer_start("easycomplete#ShowCompleteInfoInFirstRendering", [], 45)
      call s:SetFirstCompeleHit()
      if g:easycomplete_ghost_text
        let ghost_text = s:GetGhostText(a:start_pos, s:get(result,0,"word"))
        call easycomplete#util#ShowHint(ghost_text)
        let g:easycomplete_ghost_text_str = ghost_text
      endif
      call s:AddCompleteCache(s:GetTypingWord(), deepcopy(g:easycomplete_stunt_menuitems))
    endif
    call s:LetCompleteTaskQueueAllDone()
  catch
    call s:errlog('[ERR]', 'FirstCompleteRendering', v:exception)
  endtry
endfunction

function! s:RemovePrefixIgnoreCase(str, prefix) abort
  if a:prefix ==# ''
    return a:str
  endif
  " 构造正则表达式：忽略大小写匹配前缀，并只匹配开头部分
  let pattern = '\c^' . escape(a:prefix, '\/.*$^~[]')
  " 判断是否匹配
  if a:str =~ pattern
    " 匹配则返回去掉前缀的部分
    return substitute(a:str, pattern, '', '')
  else
    " 不匹配则返回空字符串
    return ''
  endif
endfunction

" TODO here jayli ，再多测试一下
function! s:GetGhostText(start_pos, first_complete_word)
  let curr_col = col('.')
  let span = curr_col - a:start_pos
  let prefix = strpart(getline('.'), a:start_pos - 1, span)
  let ghost_text = s:RemovePrefixIgnoreCase(a:first_complete_word, prefix)
  return ghost_text
endfunction

function! easycomplete#refresh(...)
  let start = get(g:easycomplete_complete_ctx, 'start', col('.'))
  let candidates = get(g:easycomplete_complete_ctx, 'candidates', [])
  noa call s:complete(start, candidates)
  return ''
endfunction

" FirstComplete 专用
function! s:complete(start, context) abort
  let g:complete_start = reltime()
  if mode() =~# 'i' && &paste != 1
    let should_fire_pum_show = v:false
    if g:env_is_nvim
      if !easycomplete#pum#visible() && !empty(a:context)
        let should_fire_pum_show = v:true
      endif
      noa call easycomplete#pum#complete(a:start, a:context)
    else
      if !pumvisible() && !empty(a:context)
        let should_fire_pum_show = v:true
      endif
      noa silent! call complete(a:start, a:context)
    endif
    if should_fire_pum_show
      silent doautocmd <nomodeline> User easycomplete_pum_show
    else
      call s:ShowCompleteInfoInSecondRendering()
    endif
  endif
  noa call easycomplete#popup#overlay()
endfunction

" SecondComplete 专用
function! easycomplete#_complete(start, items)
  let g:easycomplete_complete_ctx = {
        \ 'start': a:start,
        \ 'candidates': a:items,
        \ }
  if mode() =~# 'i' && &paste != 1
    let should_fire_pum_show = v:false
    if g:env_is_nvim
      if !easycomplete#pum#visible() && !empty(a:items)
        let should_fire_pum_show = v:true
      endif
      call easycomplete#pum#complete(a:start, a:items)
      if g:easycomplete_ghost_text
        let ghost_text = s:GetGhostText(a:start, a:items[0]["word"])
        let g:easycomplete_ghost_text_str = ghost_text
        if !exists("g:easycomplete_second_complete_ghost_timer")
          let g:easycomplete_second_complete_ghost_timer = 0
        endif
        if g:easycomplete_second_complete_ghost_timer > 0
          call timer_stop(g:easycomplete_second_complete_ghost_timer)
          let g:easycomplete_second_complete_ghost_timer = 0
        endif
        let g:easycomplete_second_complete_ghost_timer = timer_start(40, {
              \ -> easycomplete#util#ShowHint(ghost_text)
              \ })
      endif
    else
      let should_fire_pum_show = v:false
      if !pumvisible() && !empty(a:items)
        let should_fire_pum_show = v:true
      endif
      silent! noa call feedkeys("\<Plug>EasycompleteRefresh", 'i')
    endif
    if should_fire_pum_show
      silent doautocmd <nomodeline> User easycomplete_pum_show
    else
      call s:ShowCompleteInfoInSecondRendering()
    endif
  endif
endfunction

" 这个方法是给 lua ghost_text 快速输入处理占位符用的
" 当快速输入时应当避免这个定时器的干扰
function! easycomplete#StopSecondCompleteGhostTimer()
  if !exists("g:easycomplete_second_complete_ghost_timer")
    let g:easycomplete_second_complete_ghost_timer = 0
  endif
  if g:easycomplete_second_complete_ghost_timer > 0
    call timer_stop(g:easycomplete_second_complete_ghost_timer)
    let g:easycomplete_second_complete_ghost_timer = 0
  endif
endfunction

" 简单的触发pum，只给BackSpacer用
function! s:SimpleComplete(start, items)
  let g:easycomplete_complete_ctx = {
        \ 'start': a:start,
        \ 'candidates': a:items,
        \ }
  silent! noa call feedkeys("\<Plug>EasycompleteRefresh", 'i')
endfunction

" 这里只处理默认无 noselect 的情况
function! s:ShowCompleteInfoInSecondRendering()
  if !(g:easycomplete_pum_noselect)
    call timer_start(2, { -> s:ShowCompleteInfoWithoutTimer() })
    if easycomplete#util#GetCurrentPluginName() == "ts"
      call timer_start(1, { -> easycomplete#sources#ts#CompleteChanged() })
    endif
  endif
endfunction

" 有时候能弹出，有时候弹不出，无所谓了
function! easycomplete#ShowCompleteInfoInFirstRendering()
  if !(g:easycomplete_pum_noselect)
    call timer_start(2, { -> s:ShowCompleteInfoWithoutTimer() })
    if easycomplete#util#GetCurrentPluginName() == "ts"
      call timer_start(1, { -> easycomplete#sources#ts#CompleteChanged() })
    endif
  endif
endfunction

function! s:SetFirstCompeleHit()
  let g:easycomplete_first_complete_hit = 1
endfunction

function! s:emit(...)
  return call("easycomplete#util#emit", a:000)
endfunction

" PY: 0.004, VIM: 0.04 Lua: 0.001
" 200 长度的列表，PY 比 VIM 快十倍，Lua 比 PY 快十倍
" TODO PY 和 VIM 实现的一致性
" 因为需要对全量列表进行排序，所以只在 FirstComplete 之前的数据准备时使用
function! s:NormalizeSort(items)
  " 实测 Lua 比 python 快了 30 倍
  " Lua 3   0.001079   0.000039
  " Py  3   0.036487   0.020912
  if g:env_is_nvim && has("nvim-0.5.0")
    return s:NormalizeSortLua(a:items)
  elseif has("python3")
    return s:NormalizeSortPY(a:items)
  else
    return s:NormalizeSortVIM(a:items)
  endif
endfunction

function! s:NormalizeSortVIM(items)
  " 先按照长度排序
  let l:items = sort(copy(a:items), "s:SortTextComparatorByLength")
  " 再按照字母表排序
  let l:items = sort(copy(l:items), "s:SortTextComparatorByAlphabet")
  return l:items
endfunction

function! s:NormalizeSortLua(items)
  return s:easycomplete_toolkit.normalize_sort(a:items)
endfunction

function! s:NormalizeSortPY(...)
  return call("easycomplete#python#NormalizeSortPY", a:000)
endfunction

function! s:SortTextComparatorByAlphabet(...)
  return call("easycomplete#util#SortTextComparatorByAlphabet", a:000)
endfunction

function! s:SortTextComparatorByLength(...)
  return call("easycomplete#util#SortTextComparatorByLength", a:000)
endfunction

function! s:FinalNormalizeMenulist(arr, plugin_name)
  if exists("b:easycomplete_lsp_plugin") && !has_key(b:easycomplete_lsp_plugin, "name")
    return a:arr
  endif
  if exists("b:easycomplete_lsp_plugin") && a:plugin_name == b:easycomplete_lsp_plugin["name"]
    return a:arr
  endif
  if a:plugin_name == "snips"
    return a:arr
  endif
  if empty(a:arr)
    return []
  endif
  " 似乎只对buffer+dict做封装就可以了
  let l:menu_list = []
  for item in a:arr
    let sha256_str = strpart(sha256(string(item)), 0, 31)
    let r_user_data = {
          \ 'plugin_name': a:plugin_name,
          \ 'sha256':      sha256_str,
          \ }
    
    " 处理 TypeScript 插件的 user_data
    if a:plugin_name == "ts" && has_key(item, "user_data") && !empty(item.user_data)
      try
        let l:user_data_json = json_decode(item.user_data)
        if type(l:user_data_json) == v:t_dict
          " 将原始 user_data 中的字段复制到 r_user_data
          for [l:key, l:value] in items(l:user_data_json)
            let r_user_data[l:key] = l:value
          endfor
        endif
      catch
        " JSON 解析失败时忽略错误
      endtry
    endif
    
    call add(l:menu_list, extend({
          \   'word': '',      'menu': '',
          \   'user_data': json_encode(r_user_data), 'equal': 0,
          \   'dup': 1,        'info': '',
          \   'kind': '',      'abbr': '',
          \   'kind_number' : get(item, 'kind_number', 0),
          \   'plugin_name' : a:plugin_name,
          \   'user_data_json': r_user_data
          \ },  item ))
  endfor
  return l:menu_list
endfunction

function! s:CompleteAdd(...)
  return call("easycomplete#CompleteAdd", a:000)
endfunction

function! s:CompleteFilter(raw_menu_list)
  let arr = []
  let word = s:GetTypingWord()
  if empty(word)
    return a:raw_menu_list
  endif
  for item in a:raw_menu_list
    if strwidth(matchstr(item.word, word)) >= 1
      call add(arr, item)
    endif
  endfor
  return arr
endfunction

"  TaskQueue: 每个插件都完成后，一并显示匹配菜单
"  任务队列的设计不完善，当lsp特别慢的时候有可能会等待很长时间，需要加一个超时
"
" FirstComplete 过程中调用
function! s:ResetCompleteTaskQueue()
  let g:easycomplete_complete_taskqueue = []
  let l:ctx = easycomplete#context()
  for name in keys(g:easycomplete_source)
    if s:CompleteSourceReady(name) && (s:NormalTrigger() || s:SemanticTriggerForPluginName(name))
      call s:SetCompleteTaskQueue(name, l:ctx, 1, 0)
    else
      call s:SetCompleteTaskQueue(name, l:ctx, 0, 0)
    endif
  endfor
endfunction

" SecondComplete 过程中调用
function! s:ResetAlwaysCompleteTaskQueue()
  let g:easycomplete_complete_taskqueue = []
  let l:ctx = easycomplete#context()
  for name in keys(g:easycomplete_source)
    if s:CompleteSourceReady(name) && get(g:easycomplete_source[name], 'trigger', '') == 'always'
      call s:SetCompleteTaskQueue(name, l:ctx, 1, 0)
    elseif s:CompleteSourceReady(name)
      call s:SetCompleteTaskQueue(name, l:ctx, 1, 1)
    else
      call s:SetCompleteTaskQueue(name, l:ctx, 0, 0)
    endif
  endfor
endfunction

function! s:SetCompleteTaskQueue(name, ctx, condition, done)
  call filter(g:easycomplete_complete_taskqueue, 'v:val.name != "'.a:name.'"')
  call add(g:easycomplete_complete_taskqueue, {
        \ "name" : a:name,
        \ "condition": a:condition,
        \ "ctx" : a:ctx,
        \ "done" : a:done
        \ })
endfunction

function! s:CheckCompleteTaskQueueAllDone()
  let flag = v:true
  for item in g:easycomplete_complete_taskqueue
    if item.condition == 1 && item.done == 0
      let flag = v:false
      break
    endif
  endfor
  return flag
endfunction

function! s:complete_check()
  return !s:CheckCompleteTaskQueueAllDone()
endfunction

function! s:LetCompleteTaskQueueAllDone()
  for item in g:easycomplete_complete_taskqueue
    let item.done = 1
  endfor
endfunction

function! s:TabnineSupports() abort
  return g:easycomplete_tabnine_enable && easycomplete#sources#tn#available()
endfunction

function! easycomplete#SnipSupports()
  return s:SnipSupports()
endfunction

function! easycomplete#LuaSnipSupports()
  return s:LuaSnipSupports()
endfunction

function! easycomplete#SnipExpandSupport()
  return s:SnipSupports() || s:LuaSnipSupports()
endfunction

function! s:SnipSupports()
  if !exists("g:easycomplete_snips_enable")
    let g:easycomplete_snips_enable = 1
  endif
  if g:easycomplete_snips_enable == 1 && exists("g:UltiSnipsDebugServerEnable")
    return v:true
  else
    return v:false
  endif
endfunction

function! s:LuaSnipSupports()
  if !exists("g:easycomplete_snips_enable") ||
        \ (exists("g:easycomplete_snips_enable") && g:easycomplete_snips_enable == 1)
    if g:env_is_vim | return v:false | endif
    let ls = v:lua.require("easycomplete.luasnip")
    return ls.luasnip_installed()
  else
    return v:false
  endif
endfunction

function! s:SnippetsInit()
  if !exists("g:easycomplete_snips_enable")
    if s:LuaSnipSupports()
      let g:easycomplete_snips_enable = 1
    elseif s:SnipSupports()
      let g:easycomplete_snips_enable = 1
    else
      let g:easycomplete_snips_enable = 0
    endif
  endif
  try
    if LuaSnipSupports()
      " LuaSnip 的本地代码片段的载入在 require('easycomplete.luasnip').init_once() 中执行
    elseif s:SnipSupports()
      if g:easycomplete_custom_snippet == ""
        let easycomplete_root = easycomplete#util#GetEasyCompleteRootDirectory()
        let snip_path = easycomplete_root . "/snippets/ultisnips"
      else
        let snip_path = g:easycomplete_custom_snippet
      endif
      let g:UltiSnipsSnippetDirectories = [snip_path]
      " 在 &runtimepath 中搜寻 snippets
      " Ultisnips 只会查找`snippets`命名的目录，在目录中查找 SnipMate snippets
      " 默认是 1，这里会去查找 SnipMate 的 snippet.
      let g:UltiSnipsEnableSnipMate = 1
    endif
  catch
    " do nothing
  endtry
endfunction

function! easycomplete#nill() abort
  return ''
endfunction

function! easycomplete#GetStuntMenuItems()
  return g:easycomplete_stunt_menuitems
endfunction

" 清空全局配置
function! s:flush()
  let g:easycomplete_menuitems = []
  let g:easycomplete_stunt_menuitems = []
  let g:easycomplete_first_complete_hit = 0
  call s:ResetCompletedItem()
  call s:ResetCompleteCache()
  call s:ResetCompleteTaskQueue()
  let g:easycomplete_firstcomplete_ctx = {}
  " call s:SnapShoot()
  let g:easycomplete_completechanged_event = {}
  if s:first_render_timer > 0
    call timer_stop(s:first_render_timer)
    let s:first_render_timer = 0
  endif
  for sub in keys(g:easycomplete_source)
    let g:easycomplete_source[sub].complete_result = []
  endfor
  let g:easycomplete_completedone_insert_mode = mode()
  if easycomplete#util#InsertMode() && complete_check()
    call timer_start(50, { -> s:HideComplete(col("."))})
  endif
  if g:easycomplete_showmode
    set showmode
  endif
  if g:env_is_nvim
    call s:CloseCompletionMenu()
  endif
  let s:easycomplete_start_pos = 0
  let b:old_changedtick = 0
  call timer_start(20, { -> easycomplete#popup#free() })
endfunction

function! s:HideComplete(col)
  try
    silent noa call complete(a:col, [])
  catch
    " E785: complete() can only be used in Insert mode
  endtry
endfunction

function! s:ResetCompletedItem()
  if pumvisible() || easycomplete#pum#visible()
    return
  endif
  let g:easycomplete_completed_item = {}
endfunction

function! s:SetupCompleteCache()
  let g:easycomplete_menucache = {}
  let g:easycomplete_menucache["_#_1"] = 1  " line num of current typing word
  let g:easycomplete_menucache["_#_2"] = 1  " col num of current typing word
endfunction

function! s:ResetCompleteCache()
  if !exists('g:easycomplete_menucache') || empty(get(g:easycomplete_menucache, "_#_1"))
    call s:SetupCompleteCache()
  endif

  let start_pos = col('.') - strwidth(s:GetTypingWord())
  if g:easycomplete_menucache["_#_1"] != line('.') || g:easycomplete_menucache["_#_2"] != start_pos
    let g:easycomplete_menucache = {}
  endif
  let g:easycomplete_menucache["_#_1"] = line('.')  " line num
  let g:easycomplete_menucache["_#_2"] = start_pos  " col num
endfunction

function! s:AddCompleteCache(word, menulist)
  if !exists('g:easycomplete_menucache')
    call s:SetupCompleteCache()
  endif

  let start_pos = col('.') - strwidth(a:word)
  if g:easycomplete_menucache["_#_1"] == line('.') && g:easycomplete_menucache["_#_2"] == start_pos
    let g:easycomplete_menucache[a:word] = a:menulist
  else
    let g:easycomplete_menucache = {}
  endif
  let g:easycomplete_menucache["_#_1"] = line('.')  " line num
  let g:easycomplete_menucache["_#_2"] = start_pos  " col num
endfunction

function! s:GetCompleteCache(word)
  return {'menu_items':get(g:easycomplete_menucache, a:word, []),
        \ 'start_pos':g:easycomplete_menucache["_#_2"]
        \ }
endfunction

function! easycomplete#GetCompleteCache(...)
  return call("s:GetCompleteCache", a:000)
endfunction

function! s:ResetBacking(...)
  let g:easycomplete_backing_or_cr = 0
endfunction

" 空闲 30ms，简单粗暴避免事件意外触发
" vim 和 nvim 的事件设计有一些不一致，这时通过 zizz 来避免误操作非常好用
function! s:zizz()
  let delay = g:env_is_nvim ? 30 : (&filetype == 'vim' ? 50 : 50)
  let g:easycomplete_backing_or_cr = 1
  if exists('s:zizz_timmer') && s:zizz_timmer > 0
    call timer_stop(s:zizz_timmer)
  endif
  let s:zizz_timmer = timer_start(delay, function('s:ResetBacking'))
  return "\<BS>"
endfunction

function! easycomplete#zizz()
  call s:zizz()
endfunction

function! s:StopZizz()
  if exists('s:zizz_timmer') && s:zizz_timmer > 0
    call timer_stop(s:zizz_timmer)
  endif
  call s:ResetBacking()
endfunction

function s:zizzing()
  return g:easycomplete_backing_or_cr == 1 ? v:true : v:false
endfunction

function! s:SameCtx(ctx1, ctx2)
  if type(a:ctx1) != type({}) || type(a:ctx2) != type({})
    return v:false
  endif
  if !has_key(a:ctx1, 'lnum') || !has_key(a:ctx2, 'lnum')
    return v:false
  endif
  if a:ctx1["lnum"] == a:ctx2["lnum"]
        \ && a:ctx1["col"] == a:ctx2["col"]
        \ && a:ctx1["typing"] ==# a:ctx2["typing"]
    return v:true
  else
    return v:false
  endif
endfunction

function! easycomplete#SameBeginning(ctx1, ctx2)
  return s:SameBeginning(a:ctx1, a:ctx2)
endfunction

" ctx1 在前，ctx2 在后
" 判断 FirstComplete 和 SecondComplete 是否是一个 ctx 下的行为
function! s:SameBeginning(ctx1, ctx2)
  try
    if !has_key(a:ctx1, "lnum") || !has_key(a:ctx2, "lnum")
      return v:false
    endif
  catch
    call s:errlog("[ERR]", 'SameBeginning', v:exception)
    " for E715
    return v:false
  endtry
  if a:ctx1["startcol"] == a:ctx2["startcol"]
        \ && a:ctx1["lnum"] == a:ctx2["lnum"]
        \ && match(a:ctx2["typing"], a:ctx1["typing"]) == 0
    return v:true
  else
    return v:false
  endif
endfunction

function! easycomplete#Filename(...)
  let template = get(a:000, 0, "$1")
  let arg2 = get(a:000, 1, "")
  let basename = expand('%:t:r')
  if basename == ''
    return arg2
  else
    return substitute(template, '$1', basename, 'g')
  endif
endfunction

function! s:GetTypingWord()
  return easycomplete#util#GetTypingWord()
endfunction

" LSP 的 completor 函数，通用函数，可以直接使用，也可以自己再封装一层
function! easycomplete#DoLspComplete(opt, ctx)
  return easycomplete#action#completion#do(a:opt, a:ctx)
endfunction

" LSP definition 跳转的通用封装
" file_exts 文件后缀
function! easycomplete#DoLspDefinition(...)
  if easycomplete#util#FitLspFiletype()
    return easycomplete#action#defination#LspRequest()
  else
    " exec "tag ". expand('<cword>')
    " 未成功跳转，则交给主进程处理
    return v:false
  endif
endfunction

" lsp 各项配置检查是否通过
function! easycomplete#ok(str)
  if empty(bufname())
    return v:false
  endif
  " let varstr = substitute(a:str, "[abvgsl]:","","i")
  let varstr = a:str[2:]
  let flag = 0
  let value = get(g:easycomplete_config, a:str, 0)
  if exists(a:str) && get(g:, varstr, 0) == 0
    let flag = 0
  elseif exists(a:str) && get(g:, varstr, 0) != 0
    let flag = get(g:, varstr, 0)
  elseif !exists(a:str)
    let flag = value
  endif
  let g:easycomplete_config[a:str] = flag
  return flag
endfunction

function! easycomplete#lint()
  call easycomplete#action#diagnostics#do()
endfunction

function! easycomplete#reference()
  call easycomplete#action#reference#do()
endfunction

function! easycomplete#rename()
  call easycomplete#action#rename#do()
endfunction

function! easycomplete#BufWritePost()
  call easycomplete#lint()
endfunction

function! easycomplete#CursorMoved()
  if g:easycomplete_diagnostics_enable
        \ && easycomplete#util#NormalMode() && s:NotInsertMode()
    " 防止快速换行时的密集调用带来的卡顿
    if s:easycomplete_cursor_move_timer > 0
      call timer_stop(s:easycomplete_cursor_move_timer)
      let s:easycomplete_cursor_move_timer = 0
    endif
    " let s:easycomplete_cursor_move_timer = timer_start(35, { -> easycomplete#sign#LintCurrentLine() })
    let s:easycomplete_cursor_move_timer = timer_start(80, { -> easycomplete#sign#LintPopup() })
  endif

  " 上下移动时关闭hover，左右移动时不关闭
  if exists("s:last_cursor_line") && s:NotInsertMode()
    let current_line = line(".")
    if current_line != s:last_cursor_line
      call easycomplete#popup#CloseLintPopup()
    endif
  endif
  let s:last_cursor_line = line(".")
endfunction

function! easycomplete#CursorMovedI()
  " 只是移动光标，没有修改buf
  if exists("b:old_changedtick") && b:old_changedtick == b:changedtick
    if g:env_is_nvim && easycomplete#pum#visible()
      call easycomplete#pum#close()
    endif
    call easycomplete#popup#CloseLintPopup()
  endif
endfunction

function! easycomplete#ColorScheme()
  if g:easycomplete_winborder
    call easycomplete#ui#HiFloatBorder()
  endif
endfunction

function! easycomplete#defination()
  call easycomplete#action#defination#do()
endfunction

function! easycomplete#signature()
  if easycomplete#ok('g:easycomplete_signature_enable')
    call easycomplete#action#signature#do()
  endif
  return ""
endfunction

function! easycomplete#CursorHold()
  if !easycomplete#ok('g:easycomplete_enable')
    return
  endif
  call easycomplete#lint()
  if easycomplete#ok('g:easycomplete_diagnostics_enable')
        \ && easycomplete#ok('g:easycomplete_diagnostics_hover')
    " call easycomplete#sign#LintPopup()
  endif
endfunction

function! easycomplete#CursorHoldI()
  if easycomplete#IsBacking()
    " do nothting
  elseif easycomplete#tabnine#ready()
    call s:LazyTabNineSuggestFire(30)
  endif
endfunction

function! easycomplete#TextChangedI()
  " 如果输入的字符是非法字符，则终止
  let cc = getcharstr(1)
  if stridx(easycomplete#GetBindingKeys(), cc) == -1
    return
  endif

  if !easycomplete#ok('g:easycomplete_enable')
    return
  endif
  if s:zizzing() | return | endif " 点击回车选中item后不直接complete()
  if g:env_is_nvim
    call easycomplete#tabnine#LoadingStop()
  endif
  call easycomplete#tabnine#flush()
  " TextCHangedP 和 TextChangedI 是互斥的
  if g:env_is_nvim && easycomplete#pum#visible()
    " TextChangedP
    " nvim pum 在 tab select 过程中会触发 TextchangedI，原生 pum 不应当触发
    " 这里加一个逻辑，阻止掉 tab selecting 过程中的 textchangedp和textchangedi
    " 事件, vim 中的逻辑不受影响
    if easycomplete#pum#IsInsertingWord()
      " call easycomplete#pum#InsertAwake()
    else
      " Fire easycomplete#TextChangedP()
      " 用事件队列比直接调用函数流畅度要更好
      doautocmd <nomodeline> User easycomplete_pum_textchanged_p
    endif
  else
    " TextChangedI
    if !exists("b:fast_bs_timer")
      let b:fast_bs_timer = 0
    endif
    if !b:fast_bs_timer
      call s:LazyFireTyping()
    endif
    if easycomplete#ok('g:easycomplete_signature_enable')
      call easycomplete#action#signature#LazyRunHandle()
    endif
    let b:old_changedtick = b:changedtick
    " s:BackChecking() 比对文本差异判断是否回退，比较慢
    " b:fast_bs_timer 只用作判断是否刚按下<bs>
    "if s:BackChecking()
    if b:fast_bs_timer
      let g:easycomplete_backing = 1
    endif
    return ""
  endif
endfunction

function! s:LazyFireTyping()
  if !exists('b:easycomplete_typing_timer') | let b:easycomplete_typing_timer = 0 | endif
  if b:easycomplete_typing_timer > 0
    if g:env_is_nvim
      call s:easycomplete_toolkit.global_timer_stop()
    else
      call timer_stop(b:easycomplete_typing_timer)
    endif
    let b:easycomplete_typing_timer = 0
  endif
  " TODO here 为什么 50 的延时会体感这么久
  " 判断连续输入的两次字符是否是同一个
  " 如果是则有可能是连续按键，加上延迟，防止连续输入时粘连
  " 如果不是则立即触发，提高响应速度
  if !exists("b:easycomplete_old_char")
    let b:easycomplete_old_char = ""
  endif
  let l:easycomplete_curr_char = s:GetCurrentChar()
  if b:easycomplete_old_char ==# l:easycomplete_curr_char
    let l:lazy_time = 70
  else
    let l:lazy_time = 0
  endif
  let b:easycomplete_old_char = l:easycomplete_curr_char

  if g:env_is_nvim
    call s:easycomplete_toolkit.global_timer_start("easycomplete#typing", l:lazy_time)
    let b:easycomplete_typing_timer = reltime()[0]
  else
    let b:easycomplete_typing_timer = timer_start(l:lazy_time, { -> easycomplete#typing() })
  endif
endfunction

function! easycomplete#InsertCharPre()
  " backspace不会走到这里
  let g:easycomplete_insert_char = v:char
endfunction

function! easycomplete#TextChangedP()
  if b:fast_bs_timer > 0
    let g:easycomplete_backing = 1
  endif

  if g:easycomplete_enable == 0 || !exists('b:old_changedtick')
    return
  endif

  if g:env_is_nvim && b:old_changedtick == b:changedtick
    return
  endif

  if g:env_is_nvim && easycomplete#pum#visible() && easycomplete#pum#IsInsertingWord()
    if g:easycomplete_ghost_text && !empty(g:easycomplete_ghost_text_str)
      call easycomplete#util#DeleteHint()
    endif
    return
  endif

  " for #313，当判断是通过 tab 来插入word时，是不应该发生 textchangedp
  " 事件的，但当文件很大或者很卡时，neovim 有可能会误触
  " textchangedI，这是不应该的，这里做一层拦截
  if g:env_is_nvim && easycomplete#pum#IsInsertingWord()
    return
  endif

  let l:ctx = easycomplete#context()

  "当前输入的字符长度为1，并且没有回退过，说明是tab匹配到一个函数`abc()`后敲击字符
  "应该终止当前SecondComplete，而应当进入FirstComplete
  if strlen(l:ctx["typing"]) == 1 && l:ctx["typed"][-1:] == ")" && g:easycomplete_backing == 0
    call s:flush()
    call s:StopZizz()
    call timer_start(10, { -> s:LazyFireTyping() })
    return
  endif

  let line_length = strlen(l:ctx['typed'])
  let selected_item = easycomplete#GetCompletedItem()
  if empty(selected_item)
    let word_str_len = 0
  else
    let word_str_len = strlen(selected_item["word"])
  endif
  if b:old_changedtick == b:changedtick
    " neovim 中 textchangedI and textchangedP 会在 Firstcomplete 时同时触发
  elseif g:env_is_vim && easycomplete#CompleteCursored() && s:zizzing() &&
        \ get(selected_item, "word", "") == l:ctx['typed'][line_length - word_str_len:line_length - 1]
    " 直接按下 C-P 或者 C-N 不做任何处理
  elseif g:env_is_nvim && easycomplete#pum#visible() && !s:zizzing()
    " custom pum 和 默认 pum 的行为不一致
    " 默认 pum 在回退时都要先触发 completedone 然后关闭 pum，所以这里 hack
    " 的比较麻烦，custom pum 就不用这么麻烦，直接这里判断是否是回退即可
    let g:easycomplete_start = reltime()
    " 判断是否为回退
    if s:BackChecking()
      let g:easycomplete_backing = 1
      call s:BackingCompleteHandler()
      call s:SnapShoot()
    else
      let g:easycomplete_backing = 0
      " 首次激发不走这里的逻辑，走 Textchangedi 里的逻辑
      if s:OrigionalPosition() || g:easycomplete_first_complete_hit != 1
        return
      else
        call s:CompleteMatchAction()
      endif
    endif
    let b:old_changedtick = b:changedtick
  elseif g:env_is_vim && pumvisible() && !s:zizzing()
    " tabnine, 空格 trigger 出的 tabnine menu 敲入字母后的逻辑
    if len(easycomplete#GetStuntMenuItems()) == 0 && s:TabnineSupports()
      " nvim 中的 paste text 行为异常，空格弹出 pum 后直接 paste 时，c-y 会把
      " 菜单关掉的同时也把 pasted text 清空，应该是nvim的bug，这里用c-x,c-z 代替
      if has('nvim') && empty(g:easycomplete_insert_char)
        call timer_start(50, { -> s:SendKeys("\<C-X>\<C-Z>")})
      else
        call s:CloseCompletionMenu()
      endif
      call s:flush()
      call s:StopZizz()
      call easycomplete#TextChangedI()
      return
    endif
    if s:OrigionalPosition() || g:easycomplete_first_complete_hit != 1
      call s:SnapShoot()
      return
    endif
    let g:easycomplete_start = reltime()
    let delay = len(g:easycomplete_stunt_menuitems) > 180 ?
          \ (g:env_is_iterm && g:env_is_vim ? 35 : (g:env_is_nvim ? 10 : 20)) : (has("nvim") ? 2 : 4)
    call s:StopAsyncRun()
    " 异步执行的目的是避免快速频繁输入字符时的complete渲染扎堆带来的视觉破损，
    " 不能杜绝，但能大大缓解
    call s:AsyncRun('easycomplete#CompleteMatchAction', [], delay)
    let b:old_changedtick = b:changedtick
  endif
endfunction

function! easycomplete#CompleteMatchAction()
  call s:CompleteMatchAction()
endfunction

function! easycomplete#Hover()
  call easycomplete#action#hover#do()
endfunction

function! easycomplete#HoverNothing(msg)
  call s:log(a:msg)
  if s:Has_Shift_K_Map()
    let cw = expand('<cword>')
    try
      exec "h " . cw
    catch /^Vim\%((\a\+)\)\=:E149/
      echo v:exception
    endtry
  endif
endfunction

function! easycomplete#BackToOriginalBuffer()
  call easycomplete#action#reference#back()
endfunction

function! easycomplete#CmdlineEnter(...)
endfunction

function! easycomplete#CmdlineLeave()
endfunction

function! easycomplete#CmdlineChanged(char)
endfunction

function! easycomplete#Textchanged()
endfunction

function! easycomplete#BufLeave()
endfunction

function! easycomplete#QuickfixEnter()
  execute "normal! \<CR>"
  " call timer_start(70, { -> s:CloseQuickFix() })
endfunction

function! s:CloseQuickFix()
  call easycomplete#action#reference#CloseQF()
endfunction

function! easycomplete#LintRefreash()
  call easycomplete#sign#DiagHoverFlush()
  call easycomplete#sign#LintPopup()
endfunction

function! easycomplete#Undo()
  call easycomplete#LintRefreash()
  return "u"
endfunction

function! easycomplete#SingleDelete()
  call easycomplete#LintRefreash()
  return "x"
endfunction

function! easycomplete#DeleteLine()
  call easycomplete#LintRefreash()
  return "dd"
endfunction

function! easycomplete#Recover()
  call easycomplete#LintRefreash()
  return "\<c-r>"
endfunction

function! easycomplete#InsertEnter()
  call s:SnapShoot()
  call easycomplete#sign#DiagHoverFlush()
  call timer_start(10, { ->easycomplete#popup#CloseLintPopup() })
endfunction

function! easycomplete#disable()
  let g:easycomplete_enable = 0
  call easycomplete#util#info('[Vim-EasyComplete] is shutdown.')
endfunction

function! easycomplete#StartUp()
  let g:easycomplete_enable = 1
  call easycomplete#Enable()
  call easycomplete#util#info('[Vim-EasyComplete] is avilable.')
endfunction

function! easycomplete#BufEnter()
  " hack for autopair
  if exists("g:AutoPairsMapCR") && g:AutoPairsMapCR == 1 && !exists("b:easycomplete_autopairs_loaded")
    call timer_start(500, { -> easycomplete#UnmapCR() })
  endif
  if easycomplete#ok('g:easycomplete_diagnostics_enable')
    if easycomplete#sources#deno#IsTSOrJSFiletype() && !easycomplete#sources#deno#IsDenoProject()
      call easycomplete#sources#ts#bufEnter()
      return
    endif
    call timer_start(1600, { -> easycomplete#lint() })
  endif
  call s:flush()
endfunction

function easycomplete#UnmapCR()
  try
    iunmap <buffer> <CR>
  catch
  endtry
  let b:easycomplete_autopairs_loaded = 1
endfunction

function! easycomplete#finish()
  " call s:errlog('[LOG]', "exit vim", v:exiting, v:dying)
  try
    finish
  catch
    " do nothing
  endtry
endfunction

function! s:HasKey(...)
  return call('easycomplete#util#HasKey', a:000)
endfunction

function! s:AsyncRun(...)
  return call('easycomplete#util#AsyncRun', a:000)
endfunction

function! s:StopAsyncRun(...)
  return call('easycomplete#util#StopAsyncRun', a:000)
endfunction

function! s:NotInsertMode()
  return call('easycomplete#util#NotInsertMode', a:000)
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! s:get(...)
  return call('easycomplete#util#get', a:000)
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction

function! s:debug(...)
  return call('easycomplete#util#debug', a:000)
endfunction

function! s:trace(...)
  return call('easycomplete#util#trace', a:000)
endfunction

function! s:errlog(...)
  return call('easycomplete#util#errlog', a:000)
endfunction

function! Console(...)
  return call('easycomplete#log#log', a:000)
endfunction
