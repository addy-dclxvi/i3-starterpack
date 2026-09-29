scriptencoding utf-8
" 自定义 window 实现 pum, for nvim only
" 默认 pum window 初始化属性
let s:default_pum_pot = {
        \ "relative": "editor",
        \ "focusable": v:false,
        \ "zindex": 50,
        \ "bufpos": [0,0]
        \ }
" Scrollthumb 默认属性
let s:default_scroll_thumb_pot = {
        \ "relative": "editor",
        \ "focusable": v:false,
        \ "zindex": 70,
        \ "bufpos": [0,0]
        \ }
" Scrollbar 默认属性
let s:default_scroll_bar_pot = {
        \ "relative": "editor",
        \ "focusable": v:false,
        \ "zindex": 60,
        \ "bufpos": [0,0]
        \ }
let s:pum_window = 0
let s:pum_buffer = 0
let s:pum_direction = ""
" Insert word 的动作会触发 TextChangedI → TextChangedP → TypingMatch
" 这里要让 TextChangedI 躲过去，设置一个标志位
let s:pum_insert_word_timer = 0

" pum 高亮所需的临时样式 match id
let g:easycomplete_match_id = 0
" 高亮exec所需的字符串
let s:easycomplete_hl_exec_cmd = ""

" scrollthumb vars
let s:scrollthumb_window = 0
" scrollbar window
let s:scrollbar_window = 0
let s:scrollbar_buffer = 0
let s:has_scrollbar = 0
" complete_info() 中 selected 从 0 开始，这里从 1 开始
" easycomplete#pum#CompleteInfo() 的返回和 complete_info() 保持一致
let s:selected_i = 0
let s:curr_items = []
" 类似 g:easycomplete_typing_ctx，为了避免干扰，这里只给 pum 使用
let s:original_ctx = {}
" 当前编辑窗口的原始配置
let s:original_opt = {}
let s:contains_shortmess = stridx(&shortmess,"c") >= 0 ? 1 : 0
let s:textwidth = &textwidth
let s:completeopt = &completeopt
let s:lazyredraw = &lazyredraw
let g:easycomplete_onkey_event = 1

" 几个常用尺寸的计算
" window 内高度，不包含tabline和statusline: winheight(win_getid())
" 当前window的起始位置，算上了 tabline: win_screenpos(win_getid())
" cursor所在位置相对window顶部的位置，不包含tabline: winline()
" cursor所在位置相对window到底部的位置，
" screen 整个视口高度，&window
" cursor 相对 screen 顶部的高度(含当前 cursor): win_screenpos(win_getid())[0] + winline() - 1
" cursor 相对 screen 底部的高度(含当前 cursor 和 statusline): &lines - (win_screenpos(win_getid())[0] + winline() - 1)
" cursor 相对 screen 左侧的距离(含当前cursor)，win_screenpos(win_getid())[1] + wincol() - 1

function! easycomplete#pum#complete(startcol, items)
  if len(a:items) == 0
    call s:close()
    return
  endif
  if easycomplete#ok("g:easycomplete_tabnine_enable")
    let items = s:TabNineHLNormalize(a:items)
  else
    let items = a:items
  endif
  let s:curr_items = deepcopy(items)
  call s:OpenPum(a:startcol, s:NormalizeItems(s:curr_items))
  if !s:contains_shortmess
    set shortmess+=c
  endif
endfunction

function! s:HLExists(group)
  return easycomplete#ui#HighlightGroupExists(a:group)
endfunction

" 基础的三类样式用到的 Conceal 字符:
"  EazyFuzzyMatch: "§", abbr 中匹配 fuzzymatch 的字符高亮，只配置 fg
"  EasyKind:       "ϟ", 继承 PmenuKind
"  EasyExtra:      "‰", 继承 PmenuExtra
"
" vscode 提供了超过五种 kind 颜色配置，把 lsp 和 text
" 区分开，这里设置6种常见的颜色配置：
" 6种颜色做隔离足够了，ColorScheme 常用颜色一般也就八九个
"  EasyFunction:   "⊥", Function/Constant/Scruct
"  EasySnippet:    "∫", Snippet/snip
"  EasyTabNine:    "∮", TabNine
"  EasyNormal:     "Φ", Buf/Text/dict - Pmenu 默认色
"  EasyKeyword:    "♧", Keyword
"  EasyModule:     "♤", module
function! s:hl()
  if empty(s:easycomplete_hl_exec_cmd)
    if easycomplete#util#IsGui()
      let dev = "gui"
    else
      let dev = "cterm"
    endif
    let fuzzymatch_hl_group      = s:HLExists("EasyFuzzyMatch") ? "EasyFuzzyMatch" : "PmenuMatch"
    let pmenu_kind_hl_group      = s:HLExists("EasyPmenuKind") ? "EasyPmenuKind"   : "PmenuKind"
    let pmenu_extra_hl_group     = s:HLExists("EasyPmenuExtra") ? "EasyPmenuExtra" : "PmenuExtra"
    let function_hl_group        = s:HLExists("EasyFunction") ? "EasyFunction"     : "Conditional"
    let snippet_hl_group         = s:HLExists("EasySnippet") ? "EasySnippet"       : "Number"
    let tabnine_hl_group         = s:HLExists("EasyTabNine") ? "EasyTabNine"       : "Character"
    let pmenu_hl_group           = s:HLExists("EasyPmenu") ? "EasyPmenu"           : "Pmenu"
    let keyword_hl_group         = s:HLExists("EasyKeyword") ? "EasyKeyword"       : "Define"
    let module_hl_group          = s:HLExists("EasyModule") ? "EasyModule"         : "Function"
    let pmenu_cursor_has_reverse = s:HasReverseHighlight("PmenuSel")
    if s:HLExists("EasyFuzzyMatch")
      let fuzzymatch_bold_str = s:HasBold("EasyFuzzyMatch") ? "gui=bold" : ""
    else
      let fuzzymatch_bold_str = s:HasBold("PmenuMatch") ? "gui=bold" : ""
    endif
    let pmenu_cursor_hl_group_fg = pmenu_cursor_has_reverse ? s:bgcolor("PmenuSel") : s:fgcolor("PmenuSel")
    let pmenu_cursor_hl_group_bg = pmenu_cursor_has_reverse ? s:fgcolor("PmenuSel") : s:bgcolor("PmenuSel")

    if pmenu_cursor_hl_group_fg == "NONE"
      let pmenu_cursor_hl_group_fg = pmenu_cursor_has_reverse ? s:bgcolor("Pmenu") : s:fgcolor("Pmenu")
    endif
    if pmenu_cursor_hl_group_bg == "NONE"
      let pmenu_cursor_hl_group_bg = pmenu_cursor_has_reverse ? s:fgcolor("Pmenu") : s:bgcolor("Pmenu")
    endif
    if pmenu_cursor_hl_group_fg == "NONE"
      let pmenu_cursor_hl_group_fg = pmenu_cursor_has_reverse ? s:bgcolor("Normal") : s:fgcolor("Normal")
    endif
    if pmenu_cursor_hl_group_bg == "NONE"
      let pmenu_cursor_hl_group_bg = pmenu_cursor_has_reverse ? s:fgcolor("Normal") : s:bgcolor("Normal")
    endif

    let fuzzymatch_fg = pmenu_cursor_has_reverse ? s:bgcolor(fuzzymatch_hl_group) : s:fgcolor(fuzzymatch_hl_group)
    if fuzzymatch_fg == "NONE"
      let fuzzymatch_fg = pmenu_cursor_has_reverse ? s:bgcolor("Constant") : s:fgcolor("Constant")
    endif

    let s:easycomplete_hl_exec_cmd = [
          \ 'syntax region CustomFuzzyMatch matchgroup=Conceal start=/\%(§§\)\@!§/ matchgroup=Conceal end=/\%(§§\)\@!§/ concealends oneline keepend',
          \ 'syntax region CustomExtra      matchgroup=Conceal start=/\%(‰‰\)\@!‰/ matchgroup=Conceal end=/\%(‰‰\)\@!‰/ concealends oneline',
          \ 'syntax region CustomKind       matchgroup=Conceal start=/ϟ\([^ϟ]ϟ\)\@=/  matchgroup=Conceal end=/\(ϟ[^ϟ]\)\@<=ϟ/ concealends oneline',
          \ 'syntax region CustomFunction   matchgroup=Conceal start=/⊥\([^⊥]⊥\)\@=/  matchgroup=Conceal end=/\(⊥[^⊥]\)\@<=⊥/ concealends oneline',
          \ 'syntax region CustomSnippet    matchgroup=Conceal start=/∫\([^∫]∫\)\@=/  matchgroup=Conceal end=/\(∫[^∫]\)\@<=∫/ concealends oneline',
          \ 'syntax region CustomTabNine    matchgroup=Conceal start=/∮\([^∮]∮\)\@=/  matchgroup=Conceal end=/\(∮[^∮]\)\@<=∮/ concealends oneline',
          \ 'syntax region CustomKeyword    matchgroup=Conceal start=/♧\([^♧]♧\)\@=/  matchgroup=Conceal end=/\(♧[^♧]\)\@<=♧/ concealends oneline',
          \ 'syntax region CustomModule     matchgroup=Conceal start=/♤\([^♤]♤\)\@=/  matchgroup=Conceal end=/\(♤[^♤]\)\@<=♤/ concealends oneline',
          \ 'syntax region CustomNormal     matchgroup=Conceal start=/Φ\([^Φ]Φ\)\@=/  matchgroup=Conceal end=/\(Φ[^Φ]\)\@<=Φ/ concealends oneline',
          \ "hi CustomFuzzyMatch " . dev . "fg=" . fuzzymatch_fg . " " . fuzzymatch_bold_str,
          \ "hi CustomPmenuSel " . dev . "fg=" . pmenu_cursor_hl_group_fg . " " . dev . "bg=" . pmenu_cursor_hl_group_bg,
          \ "hi link CustomKind     " . pmenu_kind_hl_group,
          \ "hi link CustomExtra    " . pmenu_extra_hl_group,
          \ "hi link CustomFunction " . function_hl_group,
          \ "hi link CustomSnippet  " . snippet_hl_group,
          \ "hi link CustomTabNine  " . tabnine_hl_group,
          \ "hi link CustomNormal   " . pmenu_hl_group,
          \ "hi link CustomKeyword  " . keyword_hl_group,
          \ "hi link CustomModule   " . module_hl_group,
          \ "hi link Error Pmenu",
          \ ]
          " \ "hi Search guibg=NONE guifg=NONE ctermbg=NONE ctermfg=NONE",
  endif
  call win_execute(s:pum_window, join(s:easycomplete_hl_exec_cmd, "\n"))
endfunction

function! s:HasReverseHighlight(group_name)
  let group_text = easycomplete#ui#HighlightArgs(a:group_name)
  " 检查输出中是否包含 reverse（不区分大小写）
  if group_text =~? 'reverse'
    return v:true
  else
    return v:false
  endif
endfunction

function! s:HasBold(group_name)
  let group_text = easycomplete#ui#HighlightArgs(a:group_name)
  if group_text =~? 'gui=bold'
    return v:true
  else
    return v:false
  endif
endfunction

function! s:fgcolor(group)
  return easycomplete#ui#GetFgColor(a:group)
endfunction

function! s:bgcolor(group)
  return easycomplete#ui#GetBgColor(a:group)
endfunction

function! easycomplete#pum#winid()
  return s:pum_window
endfunction

function! easycomplete#pum#bufid()
  return s:pum_buffer
endfunction

function! s:cmdline()
  if exists("g:easycomplete_cmdline_typing") && g:easycomplete_cmdline_typing == 1
    return v:true
  else
    return v:false
  endif
endfunction

function! s:OpenPum(startcol, lines)
  if !exists("b:easycomplete_autopair_disabled")
    let b:easycomplete_autopair_disabled = 0
  endif
  call s:InitBuffer(a:lines)
  let buffer_size = s:GetBufSize(a:lines)
  let pum_pos = s:ComputePumPos(a:startcol, buffer_size)
  if s:cmdline()
    let pum_pos.row = &window
  endif
  let pum_opts = deepcopy(s:default_pum_pot)
  call extend(pum_opts, pum_pos)
  if empty(s:pum_window)
    call s:CacheOpt()
    let hl = 'Normal:Pmenu,NormalNC:Pmenu,CursorLine:CustomPmenuSel,Search:EasyNone'
    let winid = s:OpenFloatWindow(s:pum_buffer, pum_opts, hl)
    let s:pum_window = winid
    call s:hl()
    let s:original_ctx = deepcopy(g:easycomplete_typing_ctx)
  else
    " 已经存在的 windowid 用 nvim_win_set_config
    call nvim_win_set_config(s:pum_window, pum_opts)
    let s:original_ctx = deepcopy(g:easycomplete_typing_ctx)
    doautocmd <nomodeline> User easycomplete_pum_completechanged
  endif
  call s:reset()
  call nvim_win_set_cursor(s:pum_window, [1, 0])
  call s:RenderScrollBar()
  call s:RenderScrollThumb()
  " 缓解在 cmdline 中匹配查找时造成Search高亮的抖动
  if !(s:cmdline())
    noa setl textwidth=0
    noa setl completeopt=menu
  endif
  if g:easycomplete_ghost_text &&
        \ !(s:cmdline())
    noa setlocal lazyredraw
  endif
  if !b:easycomplete_autopair_disabled
    call timer_start(10, { ->  s:DisableAutoPair() })
  endif
endfunction

function! s:DisableAutoPair()
  if exists("g:AutoPairsMapSpace") && g:AutoPairsMapSpace == 1
    try
      exec "iunmap <buffer> <SPACE>"
      exec "iunmap <buffer> <BS>"
      exec "iunmap <buffer> <c-h>"
      exec "iunmap <buffer> <CR>"
    catch
    endtry
  endif
  let b:easycomplete_autopair_disabled = 1
endfunction

function! s:EnableAutoPair()
  if exists("g:AutoPairsMapSpace") && g:AutoPairsMapSpace == 1
    let do_abbrev = ""
    if v:version == 703 && has("patch489") || v:version > 703
      let do_abbrev = "<C-]>"
    endif
    execute 'inoremap <buffer> <silent> <SPACE> '.do_abbrev.'<C-R>=AutoPairsSpace()<CR>'
  endif
  if exists("g:AutoPairsMapBS") && g:AutoPairsMapBS == 1
    " Use <C-R> instead of <expr> for issue #14 sometimes press BS output strange words
    execute 'inoremap <buffer> <silent> <BS> <C-R>=AutoPairsDelete()<CR>'
  endif
  if exists("g:AutoPairsMapCh") && g:AutoPairsMapCh == 1
    execute 'inoremap <buffer> <silent> <C-h> <C-R>=AutoPairsDelete()<CR>'
  endif
  let b:easycomplete_autopair_disabled = 0
endfunction

function! easycomplete#pum#WinScrolled()
  if !s:pumvisible() | return | endif
  if has_key(v:event, bufwinid(bufnr("")))
    " 编辑窗口的移动
    let cursor_left = s:CursorLeft()
    let typing_word = easycomplete#util#GetTypingWord()
    let new_startcol = getcurpos()[2] - strlen(typing_word)
    let new_startcol = s:original_ctx["startcol"]
    let lines = getbufline(s:pum_buffer, 1, "$")
    let buffer_size = s:GetBufSize(lines)
    let pum_pos = s:ComputePumPos(new_startcol, buffer_size)
    let opts = deepcopy(s:default_pum_pot)
    call extend(opts, pum_pos)
    if new_startcol - v:event[bufwinid(bufnr(""))].leftcol <= 1
      let new_startcol = 1
      call timer_start(10, { -> s:RenderScroll() })
    endif
    call nvim_win_set_config(s:pum_window, opts)
    let curr_item = easycomplete#pum#CursoredItem()
    if !empty(curr_item)
      call easycomplete#ShowCompleteInfoByItem(curr_item)
    endif
  endif
  " 当从 cmdline 触发时没有调用 WinScrolled，是因为cmdline激活状态时主屏渲染停滞
  " 所以要注意在 select() 函数中手动触发一下RenderScrollThumb
  if has_key(v:event, s:pum_window)
    " pum 窗口的移动和滚动都会调用这里
    call s:RenderScrollThumb()
  endif
endfunction

function! s:TabNineHLNormalize(menu_items)
  if empty(g:easycomplete_typing_ctx) | return a:menu_items | endif
  let typing_word = get(g:easycomplete_typing_ctx, "typing", "")
  let count_o = min([len(a:menu_items), 5])
  for k in range(count_o)
    let item = a:menu_items[k]
    if has_key(item, "plugin_name") && get(item, "plugin_name") ==# "tn"
      let abbr = get(item, "abbr", "")
      let count_k = s:CompareStrings(typing_word, abbr)
      if count_k == 0
        let item["abbr_marked"] = abbr
      else
        let item["abbr_marked"] = "§" . strcharpart(abbr, 0, count_k) . "§" . strcharpart(abbr, count_k, 150)
      endif
      let item["marked_position"] = range(count_k)
    endif
  endfor
  return a:menu_items
endfunction

function! s:CompareStrings(str1, str2)
  let len1 = strlen(a:str1)
  let len2 = strlen(a:str2)
  let min_len = min([len1, len2])
  let count = 0
  for i in range(min_len)
    let char1 = a:str1[i]
    let char2 = a:str2[i]

    if char1 == char2
      let count += 1
    else
      break
    endif
  endfor
  return count
endfunction

function! s:CacheOpt()
  for item in ["hlsearch", "wrap", "spell"]
    let s:original_opt[item] = eval("&" . item)
  endfor
  " let s:original_opt = {
  "       \ "hlsearch": &hlsearch,
  "       \ "wrap": &wrap,
  "       \ "spell": &spell
  "       \ }
endfunction

function! s:RecoverOpt()
  for k in keys(s:original_opt)
    let v = get(s:original_opt, k, "")
    call setwinvar(0, "&" . k, v)
  endfor
  " call setwinvar(0, '&hlsearch', get(s:original_opt, "hlsearch"))
  " call setwinvar(0, '&wrap', get(s:original_opt, "wrap"))
  " call setwinvar(0, '&spell', get(s:original_opt, "spell"))
endfunction

function! s:SelectNext()
  if !s:pumvisible() | return | endif
  let item_length = len(s:curr_items)
  let next_i = 0
  if s:selected_i == item_length
    let next_i = 0
  else
    let next_i = s:selected_i + 1
  endif
  call s:select(next_i)
  let s:selected_i = next_i
  call easycomplete#zizz()
  doautocmd <nomodeline> User easycomplete_pum_completechanged
endfunction

" 和 pum_getpos() 的返回格式保持一致
function! easycomplete#pum#PumGetPos()
  if !s:pumvisible()
    return {}
  endif
  let pum_pos = s:PumPosition()
  let h = pum_pos.height
  let w = pum_pos.width
  let r = pum_pos.pos[0]
  let c = pum_pos.pos[1]
  let scrollbar = s:HasScrollbar()
  if scrollbar
    let w = w - 1
  endif
  let item_size = len(s:curr_items)
  return {
        \ "col": c + 1,
        \ "row": r,
        \ "height": h,
        \ "width": w - 1,
        \ "scrollbar": scrollbar,
        \ "size": item_size
        \ }
endfunction

function! easycomplete#pum#CompleteChangedEvnet()
  if !s:pumvisible() || !easycomplete#pum#CompleteCursored()
    return {}
  endif
  let pum_pos = easycomplete#pum#PumGetPos()
  let completed_item = easycomplete#pum#CursoredItem()
  return extend(pum_pos, {"completed_item": completed_item })
endfunction

function! s:SelectPrev()
  if !s:pumvisible() | return | endif
  let item_length = len(s:curr_items)
  let prev_i = 0
  if s:selected_i == 1
    let prev_i = 0
  elseif s:selected_i == 0
    let prev_i = item_length
  else
    let prev_i = s:selected_i - 1
  endif
  call s:select(prev_i)
  let s:selected_i = prev_i
  doautocmd <nomodeline> User easycomplete_pum_completechanged
endfunction

function! easycomplete#pum#next()
  call s:SelectNext()
  if s:cmdline()
    redraw
  endif
endfunction

function! easycomplete#pum#prev()
  call s:SelectPrev()
  if s:cmdline()
    redraw
  endif
endfunction

function! easycomplete#pum#CompleteCursored()
  return s:selected_i == 0 ? v:false : v:true
endfunction

function! easycomplete#pum#PumSelectedIndex()
  return s:selected_i
endfunction

" 格式保持和 complete_info() 一致
function! easycomplete#pum#CompleteInfo()
  let l:ret = {
        \ "mode": "function",
        \ "pum_visible": s:pumvisible() ? v:true : v:false,
        \ "items": s:curr_items,
        \ "selected": s:selected_i - 1,
        \ }
  return l:ret
endfunction

function! easycomplete#pum#CursoredItem()
  if !s:pumvisible() | return {} | endif
  if s:selected_i == 0 | return {} | endif
  " Treesitter 开启时当前输入的 syntax token
  " 破损的情况下会很卡，会出现报错，给 insertword
  " 加上了定时器的关闭，缓解这个问题。
  if s:selected_i > len(s:curr_items)
    return {}
  endif
  return s:curr_items[s:selected_i - 1]
endfunction

function! easycomplete#pum#select(index)
  call s:select(a:index)
endfunction

" 从 1 开始
function! s:select(line_index)
  if !s:pumvisible() | return | endif
  if a:line_index > len(s:curr_items)
    let l:line_index = (a:line_index + len(s:curr_items)) % len(s:curr_items)
  else
    let l:line_index = a:line_index
  endif
  if l:line_index == 0
    call setwinvar(s:pum_window, '&cursorline', 0)
    let s:selected_i = 0
  else
    call setwinvar(s:pum_window, '&cursorline', 1)
    call nvim_win_set_cursor(s:pum_window, [l:line_index, 1])
    let s:selected_i = l:line_index
    if g:easycomplete_pum_format[0] == "kind" && g:easycomplete_nerd_font == 1
      let bufline_str = getbufline(s:pum_buffer, s:selected_i)[0]
      " 读取行内 nerdfont 字符时要用函数 strcharpart，不能用下标
      " line_str[1], 用下标取的结果会把字符截断
      let kind_char = strcharpart(bufline_str, 2, 1)
      let prefix_length = 5 + strlen(kind_char)
    else
      let prefix_length = 2
    endif
    call s:HLCursordFuzzyChar("CustomFuzzyMatch", prefix_length)
  endif
  call s:RenderScrollThumb()
endfunction

function s:RenderScroll()
  call s:RenderScrollBar()
  call s:RenderScrollThumb()
endfunction

function! s:CharCounts(str, char)
  let new_str = substitute(a:str, a:char, "", "g")
  let counts = (strlen(a:str) - strlen(new_str)) / strlen(a:char)
  return counts
endfunction

" 根据原始的 fuzzy position 计算 abbr_marked 中真实的高亮位置
function! s:ComputeHLPositions(abbr_marked, fuzzy_p, prefix_length)
  let position = []
  let mark_char = "§"
  let count_i = 0  " marked abbr cursor
  let cursor = 0  " abbr cursor
  while count_i < strlen(a:abbr_marked)
    " 这里要区分 byte index 和 char index
    " 下标索引取的值是 byte index，matchaddpos 用的也是 byte index
    " 比如 '§a'[0] == '§' 是 false，因为第零个位置的 byte index 是 <c2> 
    " 所以这里的游标需要增加一个完整字符长度的 byte index 长度
    if a:abbr_marked[count_i] == mark_char[0]
      let count_i += strlen(mark_char)
      continue
    endif
    if index(a:fuzzy_p, cursor) >= 0
      call add(position, count_i + a:prefix_length)
    endif
    let cursor += 1
    let count_i += 1
  endwhile
  return position
endfunction

function! s:HLCursordFuzzyChar(hl_group, prefix_length)
  if !empty(g:easycomplete_match_id)
    try
      if g:easycomplete_match_id != -1
        call matchdelete(g:easycomplete_match_id, s:pum_window)
      endif
    catch /E802/
      echom ">>" . g:easycomplete_match_id . " " . v:exception
    endtry
  endif
  if !easycomplete#pum#CompleteCursored()
    let g:easycomplete_match_id = 0
    return
  endif
  let selected_item = easycomplete#pum#CursoredItem()
  let abbr_marked = get(selected_item, "abbr_marked", "")
  let marked_position = get(selected_item, "marked_position", [])
  if empty(abbr_marked)
    let g:easycomplete_match_id = 0
    return
  endif
  let hl_p = s:ComputeHLPositions(abbr_marked, marked_position, a:prefix_length)
  " let param_arr = map(copy(hl_p), { _, val -> [s:selected_i, val, 1]})
  " 字符串 lamda 表达式比内联函数更快
  let param_arr = map(copy(hl_p), "[s:selected_i, v:val, 1]")
  let exec_str = "let g:easycomplete_match_id = matchaddpos('" . a:hl_group . "', " . string(param_arr) . ")"
  try
    call win_execute(s:pum_window, exec_str)
  catch
    " do nothing
  endtry
endfunction

function! s:PreventOnKeyEventFowNow()
  let g:easycomplete_onkey_event = 0
  call timer_start(20, { -> s:ResetOnKeyEvent() })
endfunction

function! s:ResetOnKeyEvent()
  let g:easycomplete_onkey_event = 1
endfunction

" snip 展开时，需要把已经 tab 匹配出来的单词清空
function! easycomplete#pum#ResetBSOperatorStr()
  let startcol = s:original_ctx["startcol"]
  let backing_count = col('.') - startcol
  let oprator_str = repeat("\<bs>", backing_count)
  return oprator_str
endfunction

" TAB 和 S-TAB 的过程中对单词的自动补全动作，返回一个需要操作的字符串
function! easycomplete#pum#SetWordBySelecting()
  let pum_pos = s:PumPosition()
  let cursor_left = s:CursorLeft()
  let backing_count = cursor_left - pum_pos.pos[1] - 2
  let oprator_str = repeat("\<bs>", backing_count)
  let word = get(s:curr_items[s:selected_i - 1], "word", "")
  call s:InsertingWordZizz()
  if !easycomplete#pum#CompleteCursored()
    if g:easycomplete_ghost_text
      " 因为ghost_text 对全局的 on_key 做了监听，这里返回的 operator_str
      " 相当于触发了 on_key 回调，所以加上一个阻止 on_key 的标志位，即
      " 所有 Tab 和 S-Tab 操作都不应该触发 on_key 回调
      call s:PreventOnKeyEventFowNow()
    endif
    return oprator_str . get(s:original_ctx, "typing", "")
  else
    " 正常情况下调用 InsertWord 是很流畅没问题的
    " 在开启 Treesitter 的情况下，当所输入的位置不在一个小的 Syntax Token
    " 内，比如字符串没有闭合，数组或者对象也存在破损，这时连续 Tab
    " 频繁插入单词会导致大量的 Treesitter
    " 的计算，切换动作就会很卡。进而导致异常的 completedone 事件的发生
    " VIM 自带的 PUM 同样存在这个问题，默认 PUM 不会导致 CompleteDone
    " 发生，但会非常卡。试了下关闭 Treesitter
    " 体验不好，屏幕会频繁闪烁，也同样会造成大量的 Treesitter Enable
    " 时的重回。这里暂时加上了异步调用的 Stop，避免异常 CompleteDone。
    " 卡顿的问题无法解决。
    " 当关闭 Treesitter 和 syntax off 后始终很流畅
    if exists("b:easy_insert_word_timer") && b:easy_insert_word_timer > 0
      call timer_stop(b:easy_insert_word_timer)
      let b:easy_insert_word_timer = 0
    endif
    let l:t_lazy = 5
    let b:easy_insert_word_timer = timer_start(l:t_lazy, { -> s:InsertWord(word) })
    return ""
  endif
endfunction

function! s:InsertWord(word)
  let startcol = s:original_ctx["startcol"]
  call s:InsertingWordZizz()
  try
    noa call complete(startcol, [{ 'empty': v:true, 'word': a:word }])
    if g:easycomplete_ghost_text && strlen(a:word) > 1
      call easycomplete#util#DeleteHint()
    endif
    if pumvisible()
      noa call complete(startcol, [])
    endif
  catch /785/
    " complete() 只能在插入模式下调用
  endtry
  call easycomplete#SnapShoot()
endfunction

function! s:InsertingWordZizz()
  if easycomplete#pum#IsInsertingWord() && s:pum_insert_word_timer > 0
    call timer_stop(s:pum_insert_word_timer)
  endif
  let s:pum_insert_word_timer = timer_start(200, { -> s:InsertAwake() })
endfunction

function! s:InsertAwake()
  let s:pum_insert_word_timer = 0
endfunction

function! easycomplete#pum#InsertAwake()
  call s:InsertAwake()
endfunction

" 通过 tab 来选择匹配词时需要插入单词，但插入单词时有时会触发 textchangedI
" 事件，插入单词我用的 silent noa call complete，是不应该触发 textchangedI
" 事件的，当开启treesitter或者大文件时，操作变慢，有时会误触发，所以这里加
" 上一个判断，在 textchangedI 中判断如果是 pum 在 inserting word 时，就丢弃。
" 这样就不会错误的触发 typingmatch 的动作了
function! easycomplete#pum#IsInsertingWord()
  return s:pum_insert_word_timer > 0
endfunction

function! easycomplete#pum#select(line_index)
  call s:select(a:line_index)
endfunction

" Cursor 距离 screen top 的位置，含 cursor 的位置，算上了 tabline
function! s:CursorTop()
  return win_screenpos(win_getid())[0] + winline() - 1
endfunction

" Cursor 距离 screen bottom 的位置，含 cursor 的位置，算上了 statusline
function! s:CursorBottom()
  return &lines - s:CursorTop()
endfunction

" Cursor 距离 screen left 的位置，含 cursor 的位置
function! s:CursorLeft()
  return win_screenpos(win_getid())[1] + wincol() - 1
endfunction

function! s:CursorRight()
  return &columns - s:CursorLeft()
endfunction

function! easycomplete#pum#CursorLeft()
  return s:CursorLeft()
endfunction

function! s:CreateEmptyBuffer()
  let local_buffer = nvim_create_buf(v:false, v:true)
  call nvim_buf_set_option(local_buffer, 'filetype', "txt")
  call nvim_buf_set_option(local_buffer, 'syntax', 'on')
  call setbufvar(local_buffer, '&buflisted', 0)
  call setbufvar(local_buffer, '&buftype', 'nofile')
  call setbufvar(local_buffer, '&undolevels', -1)
  return local_buffer
endfunction

function! s:OpenFloatWindow(buf, opts, hl)
  let winid = nvim_open_win(a:buf, v:false, a:opts)
  call setwinvar(winid, '&winhl', a:hl)
  call setwinvar(winid, '&scrolloff', 0)
  call setwinvar(winid, '&spell', 0)
  call setwinvar(winid, '&number', 0)
  call setwinvar(winid, '&wrap', 0)
  call setwinvar(winid, '&signcolumn', "no")
  " call setwinvar(winid, '&hlsearch', 0)
  call setwinvar(winid, '&list', 0)
  call setwinvar(winid, '&conceallevel', 3)
  if exists("&pumblend")
    call setwinvar(winid, '&winblend', &pumblend)
  endif
  return winid
endfunction

function! s:RenderScrollBar()
  if !s:pumvisible() || !s:HasScrollbar()
    call s:CloseScrollBar()
    return
  endif
  " ScrollThumb 和 ScrollBar 共用一个 buffer
  if empty(s:scrollbar_buffer)
    let s:scrollbar_buffer = s:CreateEmptyBuffer()
    let buflines = s:GetScrollBufflines()
    call nvim_buf_set_lines(s:scrollbar_buffer, 0, -1, v:false, buflines)
  endif
  let pos = s:ComputeScrollBarPos()
  let scrollbar_opts = deepcopy(s:default_scroll_bar_pot)
  call extend(scrollbar_opts, pos)
  if empty(s:scrollbar_window)
    let hl = "Normal:PmenuSbar,NormalNC:PmenuSbar,CursorLine:PmenuSbar,Search:EasyNone,NonText:PmenuSbar"
    let s:scrollbar_window = s:OpenFloatWindow(s:scrollbar_buffer, scrollbar_opts, hl)
  else
    " update scroll window
    call nvim_win_set_config(s:scrollbar_window, scrollbar_opts)
  endif
endfunction

function! s:CloseScrollBar()
  if !empty(s:scrollbar_window) && nvim_win_is_valid(s:scrollbar_window)
    call nvim_win_close(s:scrollbar_window, 1)
  endif
  let s:scrollbar_window = 0
endfunction

function! s:RenderScrollThumb()
  if !s:pumvisible() || !s:HasScrollbar()
    call s:CloseScrollThumb()
    return
  endif
  if empty(s:scrollbar_buffer)
    let s:scrollbar_buffer = s:CreateEmptyBuffer()
    let buflines = s:GetScrollBufflines()
    call nvim_buf_set_lines(s:scrollbar_buffer, 0, -1, v:false, buflines)
  endif
  let pos = s:ComputeScrollThumbPos()
  let scrollthumb_opts = deepcopy(s:default_scroll_thumb_pot)
  call extend(scrollthumb_opts, pos)
  if scrollthumb_opts.height == 0
    call s:CloseScrollThumb()
    return
  endif
  if empty(s:scrollthumb_window)
    " create scrollthumb window
    let hl = "Normal:PmenuThumb,NormalNC:PmenuThumb,CursorLine:PmenuThumb,NonText:PmenuThumb"
    let s:scrollthumb_window = s:OpenFloatWindow(s:scrollbar_buffer, scrollthumb_opts, hl)
  else
    " update scrollthumb window

    " if get(scrollthumb_opts, "row") == -1 && g:easycomplete_winborder
    "   let scrollthumb_opts["row"] = 100
    " endif
    " if get(scrollthumb_opts, "row") == 0 && g:easycomplete_winborder
    "   let scrollthumb_opts["row"] = 101
    " endif
    call nvim_win_set_config(s:scrollthumb_window, scrollthumb_opts)
  endif
endfunction

function! s:GetScrollBufflines()
  return repeat([" "], len(s:curr_items))
endfunction

function! s:ComputeScrollBarPos()
  let pum_pos = s:PumPosition()
  let c = pum_pos.pos[1] + pum_pos.width - 1
  let r = pum_pos.pos[0]
  let w = 1
  let h = pum_pos.height
  if g:easycomplete_winborder
    let c = c + 1
    let r = r + 1 " + (s:pum_direction == "above" ? 2 : 0)
  endif
  return { "col": c, "row": r, "width": w, "height": h }
endfunction

function! s:ComputeScrollThumbPos()
  let pum_pos = s:PumPosition()
  let c = pum_pos.pos[1] + pum_pos.width - 1
  let r = pum_pos.pos[0]
  let w = 1
  " ---- 计算 scrollbar 的高度 ----
  let buf_h = len(s:curr_items)
  let pum_h = pum_pos.height
  if g:easycomplete_winborder
    let pum_h = pum_h
  endif
  let scroll_h = float2nr(floor(pum_h * pum_h * 1.0 / buf_h))
  if scroll_h >= pum_h
    let scroll_h = pum_h
  endif
  if scroll_h == 0
    let scroll_h = 1
  endif
  let h = scroll_h
  " ---- 计算scrollbar 的位置 ----
  let top_line = getwininfo(s:pum_window)[0]["topline"]
  let max_off_r = pum_h - scroll_h
  let max_top_line = buf_h - pum_h + 1
  if top_line == 1
    let r = pum_pos.pos[0]
  elseif top_line >= max_top_line
    let r = pum_pos.pos[0] + max_off_r
  else
    let p_position = (top_line) * 1.0 / (max_top_line)
    let r_position = float2nr((pum_h * p_position * 1.0) - (scroll_h * 1.0 / 2))
    if r_position < 0
      let r_position = 0
    elseif r_position >= max_off_r
      let r_position = max_off_r
    endif

    if r_position == 0 && top_line > 1
      let r_position = 1
    elseif r_position == max_off_r && top_line < max_top_line
      let r_position = max_off_r - 1
    endif
    let r = pum_pos.pos[0] + r_position
  endif

  let c = c + (g:easycomplete_winborder ? 1 : 0)
  let r = r + (g:easycomplete_winborder ? 1 : 0)

  return { "col": c, "row": r, "width": w, "height": h }
endfunction

function! s:CloseScrollThumb()
  if !empty(s:scrollthumb_window) && nvim_win_is_valid(s:scrollthumb_window)
    call nvim_win_close(s:scrollthumb_window, 1)
  endif
  let s:scrollthumb_window = 0
endfunction

function! s:HasScrollbar()
  return s:has_scrollbar == 1 ? v:true : v:false
endfunction

" PumPosition 是获得原始window信息，实测不包括 window border
function! s:PumPosition()
  if s:pumvisible()
    " pos 这里是窗口初始化时给的值，如果溢出屏幕，需要重新矫正
    let pos = nvim_win_get_position(s:pum_window)
    let h = nvim_win_get_height(s:pum_window)
    let w = nvim_win_get_width(s:pum_window)
    if s:cmdline()
      let editor_height = &window
      let rel_row = editor_height - h - (g:easycomplete_winborder ? 2 : 0)
      let pos[0] = rel_row
      if pos[1] < 0
        let pos[1] = 0
      endif
    endif
    return {"pos":pos, "height": h, "width": w}
  else
    return {}
  endif
endfunction

" 判断 PUM 是向上展示还是向下展示
function! s:PumDirection(buffer_height)
  let buffer_height = a:buffer_height
  let below_space = s:CursorBottom() - 1
  let above_space = s:CursorTop() - 1
  
  " #369: 尽量和 signature 不要重叠
  let signature_direction = easycomplete#popup#SignatureDirection()
  if signature_direction == "below"
    if above_space - (g:easycomplete_winborder ? 2 : 0) <= 6 " 顶部空间少于6个item
      if buffer_height - (above_space - (g:easycomplete_winborder ? 2 : 0)) < 0 " 顶部空间可以展开所有item
        return "above"
      else " 顶部空间太小，且item个数比顶部空间更多，一律在底部展示
        return "below"
      endif
    else " 顶部空间大于 6 个item，一律在顶部展示
      return "above"
    endif
  elseif signature_direction == "above"
    if below_space - (g:easycomplete_winborder ? 2 : 0) <= 6 " 底部空间少于 6 个item
      if buffer_height - (below_space - (g:easycomplete_winborder ? 2 : 0)) < 0 " 底部空间可以展开所有item
        return "below"
      else " 底部空间太小，且item个数比底部空间更多，一律在顶部展示
        return "above"
      endif
    else " 底部空间大于6个item，一律在底部展示
      return "below"
    endif
  endif

  " 如果底部空间不够
  if buffer_height > below_space
    if below_space < 6 + (g:easycomplete_winborder ? 2 : 0) " 底部空间太小，小于 6，一律在上部展示
      return "above"
    elseif below_space >= 10 && !g:easycomplete_winborder " 无边框时底部空间大于等于10，一律在底部展示
      return "below"
    elseif below_space >= 12 && g:easycomplete_winborder " 有边框时底部空间大于等于12，一律在底部显示
      return "below"
    elseif buffer_height - (below_space - (g:easycomplete_winborder ? 2 : 0)) <= 3
      " 底部空间只藏了5个及以内的item，可以在底部展示
      return "below"
    else " 底部空间不够且溢出5个以上的 item，就展示在上部
      return "above"
    endif
  elseif g:easycomplete_winborder && below_space <= 4 && buffer_height > below_space - 2
    return "above"
  elseif buffer_height == below_space && g:easycomplete_winborder && below_space <= 7
    return "above"
  elseif buffer_height == below_space && !g:easycomplete_winborder && below_space <= 6
    return "above"
  else " 如果底部空间足够
    return "below"
  endif
endfunction

function! s:TrimBelowHeight(below_space)
  let l:real_below_space = a:below_space
  let h = g:easycomplete_pum_maxheight
  if g:easycomplete_winborder
    let l:real_below_space = a:below_space > h - 2 ? h - 2 : a:below_space
  else
    let l:real_below_space = a:below_space > h ? h : a:below_space
  endif
  return l:real_below_space
endfunction

function! s:TrimAboveHeight(above_space)
  let l:real_above_space = a:above_space
  let h = g:easycomplete_pum_maxheight
  if g:easycomplete_winborder
    let l:real_above_space = a:above_space > h - 2 ? h - 2 : a:above_space
  else
    let l:real_above_space = a:above_space > h ? h : a:above_space
  endif
  return l:real_above_space
endfunction

" 根据起始位置和buffer的大小，计算Pum应该有的大小和位置，返回 options
function! s:ComputePumPos(startcol, buffer_size)
  let pum_direction = s:PumDirection(a:buffer_size.height)
  let s:pum_direction = pum_direction
  let l:height = 0
  let l:width = a:buffer_size.width
  let l:row = 0
  let below_space = s:CursorBottom() - 1
  let below_space = s:TrimBelowHeight(below_space)
  let above_space = s:CursorTop() - 1
  let above_space = s:TrimAboveHeight(above_space)
  if s:cmdline()
    let pum_direction = "above"
    let above_space = &window - 1
    let above_space = s:TrimAboveHeight(above_space)
  endif
  if pum_direction == "below"
    if a:buffer_size.height >= below_space " 需要滚动
      let l:height = below_space
    else
      let l:height = a:buffer_size.height
    endif
    let l:row = s:CursorTop()
  endif
  if pum_direction == "above"
    if a:buffer_size.height >= above_space " 需要滚动
      let l:height = above_space
    else
      let l:height = a:buffer_size.height
    endif
    if s:cmdline()
      let l:row = &window - l:height - 1
    else
      let l:row = s:CursorTop() - l:height - 1
    endif
  endif
  if g:easycomplete_winborder
    if pum_direction == "below"
      if a:buffer_size.height <= below_space - 2 " 无需滚动
        let s:has_scrollbar = 0
      else
        " 需要滚动
        let s:has_scrollbar = 1
      endif
    elseif pum_direction == "above"
      if a:buffer_size.height <= above_space - 2 " 无需滚动
        let s:has_scrollbar = 0
      else
        " 需要滚动
        let s:has_scrollbar = 1
      endif
    endif
  else
    if l:height < a:buffer_size.height
      " 判断是否应该出现 scrollbar
      let s:has_scrollbar = 1
      let l:width = a:buffer_size.width + 1
    else
      let s:has_scrollbar = 0
    endif
  endif
  " 计算相对于 editor 的 startcol
  let offset = col('.') - a:startcol
  let realcol = s:CursorLeft() - offset
  " 如果触碰到右壁，默认缩短，和 vim 保持一致，永远和字符对齐
  let right_space = &columns - (realcol - 2)
  if right_space < l:width + (g:easycomplete_winborder ? 2 : 0)
    let l:width = right_space - (g:easycomplete_winborder ? 2 : 0)
    if g:easycomplete_winborder && s:has_scrollbar == 1
      let s:has_scrollbar = 0
    endif
  endif
  let pum_origin_opt = {"row": l:row, "col": realcol - 2,
        \ "width":  l:width,
        \ "height": l:height
        \ }
  if g:easycomplete_winborder
    let l:pum_pos = s:SetWinBorder(pum_origin_opt, pum_direction)
  else
    let l:pum_pos = pum_origin_opt
  endif
  return l:pum_pos
endfunction

function! easycomplete#pum#PumWinid()
  return s:pum_window
endfunction

function! s:SetWinBorder(opt, pum_direction)
  if a:pum_direction == "below"
    let l:row = a:opt.row
    let l:col = a:opt.col
    let l:width = a:opt.width
    let l:below_space = s:CursorBottom() - 1
    let l:below_space = s:TrimBelowHeight(l:below_space)
    if a:opt.height + 2 <= l:below_space
      " 向下远没有触底
      let l:height = a:opt.height
    elseif a:opt.height + 1 == l:below_space
      " 向下+1后触底
      let l:height = a:opt.height - 1
    elseif a:opt.height + 2 == l:below_space
      " 向下+2后触底
      let l:height = a:opt.height - 2
    else
      " 超过触底，一般不会走到这里
      let l:height = a:opt.height - 2
    endif
  elseif a:pum_direction == "above"
    let l:col = a:opt.col
    let l:above_space = s:CursorTop() - 1
    " TODO here jayli 要处理顶部高度----------------------
    " 不写这句好像就可以了，还需要再测试下
    if s:cmdline()
      let l:above_space = &window - 1
    endif
    let l:above_space = s:TrimAboveHeight(l:above_space)
    let l:row_with_maxheight_computed = s:CursorTop() - l:above_space - 1
    let l:height = a:opt.height
    let l:width = a:opt.width

    if a:opt.height + 2 <= l:above_space
      " 向上远没有触顶
      let l:height = a:opt.height
      let l:row = a:opt.row - 2
    elseif a:opt.height + 1 == l:above_space
      " 向上+1后触顶
      let l:height = a:opt.height - 1
      let l:row = l:row_with_maxheight_computed > 0 ? l:row_with_maxheight_computed : 0
    elseif a:opt.height + 2 == l:above_space
      " 向上+2后触顶
      let l:height = a:opt.height - 2
      let l:row = l:row_with_maxheight_computed > 0 ? l:row_with_maxheight_computed : 0
    else
      " 超过触顶，一般不会走到这里
      let l:height = a:opt.height - 2
      let l:row = l:row_with_maxheight_computed > 0 ? l:row_with_maxheight_computed : 0
    endif
  endif
  return extend(a:opt, {
        \ "height": l:height,
        \ "width": l:width + (s:has_scrollbar ? 1 : 0),
        \ "row": l:row,
        \ "col": l:col,
        \ "border": g:easycomplete_pum_border_style
        \ })
endfunction

" secondcomplete 过程中有可能手动移动了 pum 的 cursor，继续 typing
" 时需要reset一下状态 
function! s:reset()
  if !(g:easycomplete_pum_noselect)
    call s:select(1)
  else
    call s:select(0)
  endif
endfunction

function! s:flush()
  if !exists("b:easycomplete_autopair_disabled")
    let b:easycomplete_autopair_disabled = 0
  endif
  let should_fire_pum_done = 0
  if !empty(s:pum_window) && nvim_win_is_valid(s:pum_window)
    call nvim_win_close(s:pum_window, 1)
    call s:RecoverOpt()
    let should_fire_pum_done = 1
  endif
  if !empty(s:pum_buffer)
    execute 'bwipeout' . s:pum_buffer
    let s:pum_buffer = 0
  endif
  if !empty(s:scrollthumb_window)
    call s:CloseScrollThumb()
  endif
  if !empty(s:scrollbar_window)
    call s:CloseScrollBar()
  endif
  if !empty(s:scrollbar_buffer)
    execute 'bwipeout' . s:scrollbar_buffer
    let s:scrollbar_buffer = 0
  endif
  let s:pum_window = 0
  let s:has_scrollbar = 0
  let s:selected_i = 0
  let s:curr_items = []
  let s:original_ctx = {}
  let s:scrollthumb_window = 0
  let s:scrollbar_window= 0
  let s:pum_direction = ""
  let g:easycomplete_match_id = 0
  if should_fire_pum_done
    doautocmd <nomodeline> User easycomplete_pum_done
  endif
  if !s:contains_shortmess
    set shortmess-=c
  endif
  call execute("noa setl textwidth=" . s:textwidth)
  call execute("noa setl completeopt=" . s:completeopt)
  if g:easycomplete_ghost_text && !(s:cmdline())
    if !s:lazyredraw
      noa setlocal nolazyredraw
    endif
  endif
  if b:easycomplete_autopair_disabled
    call timer_start(10, { -> s:EnableAutoPair() })
  endif
endfunction

function! s:close()
  call s:flush()
endfunction

function! easycomplete#pum#close()
  call s:flush()
endfunction

function! s:pumvisible()
  return s:pum_window > 0 ? v:true : v:false
endfunction

function! easycomplete#pum#visible()
  return s:pumvisible()
endfunction

function! s:InitBuffer(lines)
  if empty(s:pum_buffer)
    let pum_buffer = s:CreateEmptyBuffer()
    let s:pum_buffer = pum_buffer
  endif
  call nvim_buf_set_lines(s:pum_buffer, 0, -1, v:false, a:lines)
endfunction

function! s:GetBufSize(lines)
  let buffer_width = s:MaxLength(a:lines) + 1
  let buffer_height = len(a:lines)
  return {"width": buffer_width, "height": buffer_height}
endfunction

function! s:MaxLength(lines)
  let max_length = 0
  for item in a:lines
    let remove_style_wrapper = item
    let remove_style_wrapper = substitute(remove_style_wrapper, "\\s⊥\[^⊥\]⊥\\s", " x ", "g")
    let remove_style_wrapper = substitute(remove_style_wrapper, "\\s∫\[^∫\]∫\\s", " x ", "g")
    let remove_style_wrapper = substitute(remove_style_wrapper, "\\s∮\[^∮\]∮\\s", " x ", "g")
    let remove_style_wrapper = substitute(remove_style_wrapper, "\\sΦ\[^Φ\]Φ\\s", " x ", "g")
    let remove_style_wrapper = substitute(remove_style_wrapper, "\\s♧\[^♧\]♧\\s", " x ", "g")
    let remove_style_wrapper = substitute(remove_style_wrapper, "\\s♤\[^♤\]♤\\s", " x ", "g")
    let curr_length = strdisplaywidth(substitute(remove_style_wrapper, "\[§ϟ‰]", "", "g"))
    if curr_length > max_length
      let max_length = curr_length
    endif
  endfor
  return max_length
endfunction

function! s:NormalizeItems(items)
  let new_line_arr = s:GetFullfillItems(a:items)
  return map(copy(new_line_arr["items"]), function('s:MapFunction'))
endfunction

function! s:MapFunction(key, val)
  let kind_char = "ϟ"
  if g:easycomplete_nerd_font
    let kind_o = get(a:val, "kind", "")
    if      kind_o ==# g:easycomplete_lsp_type_font["function"] ||
          \ kind_o ==# g:easycomplete_lsp_type_font["constant"] ||
          \ kind_o ==# g:easycomplete_lsp_type_font["struct"]
      " 颜色1
      let kind_char = "⊥"
    elseif  kind_o ==# g:easycomplete_menu_skin["snip"]["kind"] ||
          \ kind_o ==# g:easycomplete_lsp_type_font["snippet"]
      " 颜色2
      let kind_char = "∫"
    elseif kind_o ==# g:easycomplete_menu_skin["tabnine"]["kind"]
      " 颜色3
      let kind_char = "∮"
    elseif  kind_o ==# g:easycomplete_menu_skin["buf"]["kind"] ||
          \ kind_o ==# g:easycomplete_menu_skin["dict"]["kind"] ||
          \ kind_o ==# g:easycomplete_lsp_type_font["text"]
      " 颜色4，标准色
      let kind_char = "Φ"
    elseif  kind_o ==# g:easycomplete_lsp_type_font["keyword"] ||
          \ kind_o ==# g:easycomplete_lsp_type_font["class"]
      " 颜色 5
      let kind_char = "♧"
    elseif  kind_o ==# g:easycomplete_lsp_type_font["module"] ||
          \ kind_o ==# g:easycomplete_lsp_type_font["method"]
      " 颜色 6
      let kind_char = "♤"
    endif
  endif
  let kind_str = get(a:val, "kind", "")
  if kind_str == ""
    let kind_char = ""
  endif
  let format_object = {
        \ "abbr" : get(a:val, "abbr", ""),
        \ "kind" : kind_char . kind_str . kind_char,
        \ "menu" : "‰" . get(a:val, "menu", "") . "‰"
        \ }
  let ret = []
  if g:easycomplete_nerd_font
    let format_s = g:easycomplete_pum_format
  else
    let format_s = ["abbr", "kind", "menu"]
  endif
  for item in format_s
    call add(ret, " " . get(format_object, item, ""))
  endfor
  return join(ret,"")
endfunction

function! s:GetFullfillItems(data)
  let wlength = 0
  let word_arr_length = []
  let kind_arr_length = []
  let menu_arr_length = []
  let abbr_arr_length = []
  let new_data = []
  " ------------ find max length --------------
  for item in a:data
    " let abbr = easycomplete#util#GetItemAbbr(item)
    let word = get(item, "word", "")
    let abbr = get(item, "abbr", "")
    " if empty(get(item, "abbr", ""))
    "   let item["abbr"] = abbr
    " endif
    let word_arr_length += [strdisplaywidth(word)]
    let abbr_arr_length += [strdisplaywidth(abbr)]
    let kind_arr_length += [strdisplaywidth(trim(get(item, "kind", "")))]
    let menu_arr_length += [strdisplaywidth(trim(get(item, "menu", "")))]
  endfor
  let maxlength = {
        \ "word_max_length": max(word_arr_length),
        \ "abbr_max_length": max(abbr_arr_length),
        \ "kind_max_length": max(kind_arr_length),
        \ "menu_max_length": max(menu_arr_length)
        \ }
  for item in a:data
    let f_kind = s:fullfill(trim(get(item, "kind", "")), maxlength.kind_max_length)
    let f_menu = s:fullfill(trim(get(item, "menu", "")), maxlength.menu_max_length)
    call add(new_data, {
          \ "abbr": s:FullfillMarkedAbbr(get(item, "abbr", ""),
          \                              get(item, "abbr_marked", ""),
          \                              maxlength.abbr_max_length),
          \ "word": get(item, "word", ""),
          \ "kind": f_kind,
          \ "menu": f_menu
          \ })
  endfor
  return extend({
        \ "items": new_data,
        \ }, maxlength)
endfunction

function! s:FullfillMarkedAbbr(abbr, abbr_marked, max_length)
  let added_spaces = a:max_length - strdisplaywidth(a:abbr)
  let res = (empty(a:abbr_marked) ? a:abbr : a:abbr_marked) . repeat(" ", added_spaces)
  return res
endfunction

function! s:fullfill(word, length)
  let word_length = strdisplaywidth(a:word)
  if word_length >= a:length
    return a:word
  endif
  let inc = a:length - word_length
  " if g:easycomplete_nerd_font
  "   return repeat(" ", inc) . a:word
  " else
  return a:word . repeat(" ", inc)
  " endif
endfunction

function! easycomplete#pum#fullfill(word, length)
  return s:fullfill(a:word, a:length)
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

function! s:trace(...)
  return call('easycomplete#util#trace', a:000)
endfunction
