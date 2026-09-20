" Popup menu 的实现 <bachi@taobao.com>
" vim 8.2 实现了 popupmenu, 即 completeopt+=popup 很好用，但有几个bug
" 1. setlocal completepopup=width:70 中的 Width 属性无效
" 2. 连续 c-n 快速在 completemenu 中移动选中位置，频繁 popup 出 infomenu
" 时会有 complete menu 的闪烁
" 3. menu info 字段不支持 list 类型
" 4. 按照官方文档手工通过 popup_settext 和 popup_show 来显示 popup window
" 的话，必须通过 popup_findinfo 来获取已经存在的 popup window，但
" popup_findinfo 必须被存在 info 不为空的 complete item 高亮时先创建出来，否则
" popup_findinfo 的结果是空，如果这时手工创建 popup window，popup_findinfo 依
" 然无法返回手工创建的这个 window id，还不如全部手写 popup 逻辑
" 5. nvim 没有实现 popup menu 的功能，但提供了浮窗能力，因此干脆手写了
" 6. popup 和 float 应当分开
"     - popup 只给completemenu显示 info 使用
"     - float 用作signature和diagnostics

" popup window 最大高度
let s:popup_max_height = 50
let s:float_max_height = 15
let s:is_vim = !has('nvim')
let s:is_nvim = has('nvim')
" signature/lint
let s:float_type = ""
let s:float_opt = {}
let s:hlsearch = &hlsearch

augroup easycomplete#popup#au
  autocmd!
  autocmd VimResized * call easycomplete#popup#reopen()
  autocmd BufLeave * call easycomplete#popup#close()
  " autocmd BufWinLeave * call easycomplete#popup#close()
  " autocmd WinLeave * call easycomplete#popup#close()
  autocmd InsertLeave * call easycomplete#popup#close()
  if s:is_nvim
    autocmd VimResume * call easycomplete#popup#reopen()
  endif
augroup END

let s:timer = 0
let g:easycomplete_popup_win = {
      \ "popup" : 0,
      \ "float" : 0
      \ }
let s:event = {}
let s:item = {}
let s:info = []

let s:last_event = {}
let s:last_winargs = []
let s:buf = {
      \ "popup":0,
      \ "float":0,
      \ }

function! easycomplete#popup#MenuPopupChanged(info)
  let l:event = g:env_is_vim ? v:event : easycomplete#pum#CompleteChangedEvnet()
  " 这两个 if 如果默认选中第一项的逻辑
  " 一次 typingmatch 会触发多次MenuPopupChanged，一般会2次或者3次
  " 这里应该避免多次相同事件同时发生
  let curr_item = easycomplete#GetCursordItem()
  if !empty(s:GetMenuInfoWinid()) && s:SamePositionAsLastTime()
                                \ && easycomplete#util#SameItem(s:item, curr_item)
                                \ && easycomplete#FirstSelectedWithOptDefaultSelected()
    return
  endif

  if g:env_is_nvim && empty(curr_item)
    call easycomplete#popup#close("popup")
  elseif g:env_is_nvim && easycomplete#FirstSelectedWithOptDefaultSelected() && !easycomplete#zizzing()
    let s:item = deepcopy(curr_item)
    call easycomplete#popup#DoPopup(a:info, 1)
  elseif g:env_is_vim && empty(l:event) && easycomplete#FirstSelectedWithOptDefaultSelected()
    let s:item = deepcopy(curr_item)
    call easycomplete#popup#DoPopup(a:info, 1)
  elseif g:env_is_nvim && !easycomplete#pum#visible() && empty(a:info)
    call easycomplete#popup#close("popup")
  else
    if empty(l:event) && empty(g:easycomplete_completechanged_event) | return | endif
    let s:event = empty(l:event) ? copy(g:easycomplete_completechanged_event) : copy(l:event)
    let s:item = has_key(l:event, 'completed_item') ?
          \ copy(l:event.completed_item) : copy(easycomplete#GetCompletedItem())

    call easycomplete#popup#DoPopup(a:info, g:easycomplete_popup_delay)
  endif
  let s:info = a:info
endfunction

function! s:GetMenuInfoWinid()
  return g:easycomplete_popup_win["popup"]
endfunction

function! s:SamePositionAsLastTime()
  let pum_pos = g:env_is_vim ? pum_getpos() : easycomplete#pum#PumGetPos()
  if empty(pum_pos) | return v:false | endif
  if !exists("s:easycomplete_pum_pos")
    let s:easycomplete_pum_pos = deepcopy(pum_pos)
    return v:false
  endif
  " if !pumvisible()
  "   unlet s:easycomplete_pum_pos
  "   return v:false
  " endif
  if pum_pos.height == get(s:easycomplete_pum_pos, "height", 0) &&
        \  pum_pos.width == get(s:easycomplete_pum_pos, "width", 0) &&
        \  pum_pos.col == get(s:easycomplete_pum_pos, "col", 0) &&
        \  pum_pos.row == get(s:easycomplete_pum_pos, "row", 0)
    return v:true
  else
    let s:easycomplete_pum_pos = deepcopy(pum_pos)
    return v:false
  endif
endfunction

function! easycomplete#popup#CompleteDone()
  let s:item = copy(v:completed_item)
  call easycomplete#popup#close("popup")
endfunction

function! easycomplete#popup#test()
  let content = [
        \ "~/.vim/bundle/vim-easycomplete/autoload/easycomplete/popup.vim [+] [utf-8]",
        \ "asdkjfo ajodij aojf aojf a;fj alfj",
        \ "testing testing"]
  call easycomplete#popup#float(content, 'ErrorMsg', 0, "python", [0,0], 'signature')
endfunction

function! s:GetCurrentLineLastCharToWindowRightEdgeDistance()
  return winwidth(0) - wincol() - s:GetCusorToLineRightEdgeDistance() + 1
endfunction

function! s:CurrCharIsChinese()
  let offset = 0
  " Tab
  if char2nr(strpart(getline('.'), col('.')-1, 1)) == 9
    return 1
  endif
  let l_len = strwidth(strpart(getline('.'), col('.')-1, 3))
  if l_len == 2
    let offset = 1 " 是中文字符
  else
    let offset = 0 " 不是中文字符
  endif
  return offset
endfunction

function! s:GetCusorToLineRightEdgeDistance()
  let l:chinese_offset = s:CurrCharIsChinese()
  " 要计算当前行的 \t 的数量，根据&tabstop长度补上差的宽度
  let l:ts_nr = len(substitute(getline('.'), '[^\t]', '', 'g'))
  let l:offset = (&tabstop - 1) * l:ts_nr
  return strwidth(getline('.')) + l:offset - virtcol('.') + 1 + l:chinese_offset
endfunction

function! s:lint(content, hl, ft)
  let distance = s:GetCurrentLineLastCharToWindowRightEdgeDistance()
  let lensleft = s:GetCusorToLineRightEdgeDistance()
  let s:float_type = 'lint'
  let s:float_opt = {}
  try
    if distance < 5
      let b:easycomplete_echo_lint_msg = 1
      echo a:content[0][0:winwidth(0) - 11]
      return
    endif
    let trimed_content = easycomplete#util#lintTrim(a:content[0], distance, 2)
    let l:content = [trimed_content["str"]]
    if trimed_content["trimed"]
      " TODO 关闭
      let b:easycomplete_echo_lint_msg = 1
      echo a:content[0][0:winwidth(0) - 11]
    endif
    call s:InitBuf(l:content, 'float', a:ft)
    let screen_col_enc = win_screenpos(win_getid())[1] - 1
    let screen_row_enc = win_screenpos(win_getid())[0] - 1
    let p_row = screen_row_enc + winline() - 1
    let p_col = screen_col_enc + wincol() - 1
    let p_width = distance
    let p_height = 1
    let p_offset_right = 0

    let opt = extend({
          \   'relative':'editor',
          \   'focusable': v:false,
          \   'style':'minimal',
          \   'filetype': empty(a:ft) ? "help" : a:ft
          \ },
          \ {
          \   'width': p_width,
          \   'height': p_height,
          \   'col': p_col + lensleft + p_offset_right,
          \   'row': p_row
          \ })
    " 判断右侧是否有足够的空间
    call easycomplete#popup#close("float")
    if g:env_is_nvim
      call s:NVimShow(opt, "float", 'lint')
    else
      call s:VimShow(opt, "float", 'lint')
    endif
  catch /.*/
    echom v:exception
  endtry
endfunction

function! s:float(content, hl, direction, ft, offset, float_type)
  let content = a:content
  if a:float_type == "signature"
    let float_maxwidth = g:easycomplete_popup_width
  endif
  let content = easycomplete#util#ModifyInfoByMaxwidth(content, float_maxwidth)
  if len(content) == 1 && strwidth(content[0]) == 0
    return
  endif
  let prevw_width = easycomplete#popup#DisplayWidth(content, float_maxwidth)
  let prevw_height = easycomplete#popup#DisplayHeight(content, prevw_width, 'float') - 1
  call s:InitBuf(content, 'float', a:ft)
  let opt = extend({
        \   'relative':'editor',
        \   'focusable': v:true,
        \   'style':'minimal',
        \   'filetype': empty(a:ft) ? "help" : a:ft
        \ },
        \ {
        \   'width': prevw_width,
        \   'height': prevw_height,
        \ })
  " handle height
  let screen_enc = (win_screenpos(win_getid())[0] - 1)
  if !a:direction " 正常向下
    if winline() + prevw_height + (g:easycomplete_winborder ? 2 : 0) <= winheight(win_getid())
      " 菜单向下展开ok
      let opt.row = winline() + 1 + screen_enc
    elseif winline() + prevw_height + (g:easycomplete_winborder ? 2 : 0) >= winheight(win_getid())
          \ && prevw_height >= 3
          \ && winheight(win_getid()) - winline() >= 3 + (g:easycomplete_winborder ? 2 : 0)
      " 压缩float框向下展开
      let opt.height = winheight(win_getid()) - winline() - (g:easycomplete_winborder ? 1 : 0)
      let opt.row = winline() + 1 + screen_enc
    else
      " 菜单向上展开
      let opt.row = winline() - prevw_height + screen_enc - (g:easycomplete_winborder ? 2 : 0)
    endif
  else " 正常向上
    if winheight(win_getid()) - winline() + 1 + prevw_height + (g:easycomplete_winborder ? 2 : 0) <= winheight(win_getid())
      " 单窗口内空间足够，菜单向上展开 ok
      let opt.row = winline() - prevw_height + screen_enc + (g:easycomplete_winborder ? 2 : 0)
    elseif winheight(win_getid()) - winline() + prevw_height + 1 + (g:easycomplete_winborder ? 2 : 0) > winheight(win_getid())
          \ && prevw_height >= 3
          \ && winline() >= 4 + (g:easycomplete_winborder ? 2 : 0)
      " 单窗口内向上展开所需空间不够，要判断窗口上方还有没有多余空间
      let t_pos = screen_enc + ((winline() - prevw_height) -1)
      if t_pos >= 0
        " 占用顶部空间全部展开
        let opt.height = prevw_height
        let opt.row = t_pos + 1 - (g:easycomplete_winborder ? 2 : 0)
      else
        " 占用顶部空间也不够展示，则向上压缩展开
        let opt.height = prevw_height + t_pos - (g:easycomplete_winborder ? 2 : 0)
        let opt.row = 1
      endif
    else  " 单窗口内向下展开
      " 先判断顶部是否有多余的空间给与展示
      let t_pos = screen_enc + ((winline() - prevw_height) -1)
      if t_pos >= 0
        " 顶部还有空，用顶部空间全部展开
        let opt.height = prevw_height
        let opt.row = t_pos + 1
      else
        " 顶部空间仍然不够，则菜单向下展开
        let opt.row = winline() + 1 + screen_enc
      endif
    endif
  endif
  let opt.row -= 1

  let screen_col_enc = win_screenpos(win_getid())[1] - 1
  let opt.col = screen_col_enc + wincol() - 1
  let opt.col += a:offset[1]
  " TODO col 方向的offset的处理ok，line方向的offset未做处理
  " handle width
  if opt.col + prevw_width > winwidth(win_getid()) + screen_col_enc - 1
    let opt.col = screen_col_enc + winwidth(win_getid()) - prevw_width
  elseif opt.col < 0
    " 如果叠加 offset 之后，左侧超出边界，则直接赋值为 0
    let opt.col = 0
  endif

  if !empty(a:hl)
    let opt.highlight = a:hl
  endif

  if g:easycomplete_winborder && a:float_type == "signature"

  endif

  if s:is_nvim
    call easycomplete#popup#close("float")
    call s:NVimShow(opt, "float", a:float_type)
  elseif s:is_vim
    call s:VimShow(opt, "float", a:float_type)
  endif
  let s:float_type = a:float_type
  let s:float_opt = opt
endfunction

" content, hl, direction: 0, 向下，1，向上
" ft, 文件类型
" offset, 偏移量，正常跟随光标传入[0,0], [line(),col()]
" float_type: signature/lint
"   signature: 函数参数提示
"   lint:      错误提示
function! easycomplete#popup#float(content, hl, direction, ft, offset, float_type)
  if type(a:content) == type('')
    let content = [a:content]
  elseif type(a:content) == type([])
    let content = a:content
  else
    return
  endif
  if a:float_type == "lint"
    call s:lint(a:content, a:hl, a:ft)
  else
    call s:float(content, a:hl, a:direction, a:ft, a:offset, a:float_type)
  endif
endfunction

function! easycomplete#popup#LintPopupVisible()
  if g:env_is_nvim && g:easycomplete_popup_win["float"] == 0
    return v:false
  elseif g:env_is_nvim && nvim_win_is_valid(g:easycomplete_popup_win["float"])
    return v:true
  elseif g:easycomplete_popup_win["float"] && s:float_type == "lint"
    return v:true
  else
    return v:false
  endif
endfunction

function! easycomplete#popup#SignatureVisible()
  if g:easycomplete_popup_win["float"] && s:float_type == "signature"
    return v:true
  else
    return v:false
  endif

  " if empty(s:float_type) || empty(g:easycomplete_popup_win["float"])
  "   return v:false
  " else
  "   return v:true
  " endif
endfunction

" 当 float_type 是 signature 时，判断 popup
" 在当前行上还是下，如果没有显示则返回空
"   上: above
"   下: below
"   无: ''
function! easycomplete#popup#SignatureDirection()
  if easycomplete#popup#SignatureVisible() && !(empty(s:float_opt))
    let screen_row_enc = win_screenpos(win_getid())[0] - 1
    let c_row = screen_row_enc + winline() - 1
    if c_row < s:float_opt["row"]
      return "below"
    elseif c_row > s:float_opt["row"]
      return "above"
    else
      return ""
    endif
  else
    return ""
  endif
endfunction

" 这里只判断complete menu和float 之间是否有overlay
" 如果有overlay，则关闭float
" 在completedone之后调用
" 这里简化一下，只判断Y轴上是否有重叠
function! easycomplete#popup#overlay()
  if s:IsOverlay()
    call easycomplete#popup#close("float")
  endif
endfunction

function! s:IsOverlay()
  let float_winid = g:easycomplete_popup_win['float']
  if empty(float_winid) | return v:false | endif
  if g:env_is_vim && empty(pum_getpos())
    return v:false
  elseif g:env_is_nvim && !easycomplete#pum#visible()
    return v:false
  endif
  " if empty(pum_getpos()) | return v:false | endif
  if empty(getwininfo(float_winid)) | return v:false | endif
  let float_config = getwininfo(float_winid)[0]
  let pum_config = g:env_is_vim ? pum_getpos() : easycomplete#pum#PumGetPos()
  let overlay = v:false
  if float_config.height != 1
    if pum_config.row <= float_config.winrow
          \ && pum_config.row + pum_config.height - 1 >= float_config.winrow
      let overlay = v:true
    endif
    if pum_config.row <= float_config.winrow + float_config.height - 1
          \ && pum_config.row + pum_config.height - 1 >= float_config.winrow + float_config.height - 1
      let overlay = v:true
    endif
  endif
  let screen_line = winline() + (win_screenpos(win_getid())[0] - 1)
  if (pum_config.row > screen_line && float_config.winrow > screen_line)
        \ || (pum_config.row < screen_line && float_config.winrow < screen_line)
        \ || (pum_config.row == screen_line && float_config.winrow > screen_line)
    let overlay = v:true
  endif
  return overlay
endfunction

function! easycomplete#popup#DoPopup(info, delay)
  call s:StopVisualAsyncRun()
  call s:StartPopupAsyncRun(function("s:popup"), [a:info], a:delay)
endfunction

" s:popup 代替 popup_info 方法，只给 completion 使用
" 外部调用时统一使用 easycomplete#popup#float() 方法
function! s:popup(info)
  if g:env_is_vim && (!pumvisible() || !easycomplete#CompleteCursored())
    call easycomplete#popup#close("popup")
    return
  endif
  if g:env_is_nvim && (!easycomplete#pum#visible() || !easycomplete#CompleteCursored())
    call easycomplete#popup#close("popup")
    return
  endif
  if empty(s:item) || empty(a:info)
    if s:is_vim
      call popup_hide(g:easycomplete_popup_win["popup"])
    else
      call easycomplete#popup#close("popup")
    endif
    return
  endif
  if easycomplete#FirstSelectedWithOptDefaultSelected()
    let l:event = g:env_is_vim ? v:event : easycomplete#pum#CompleteChangedEvnet()
    let s:event = l:event
    let s:last_event = l:event
  else
    if s:is_nvim && g:easycomplete_popup_win["popup"] && s:event == s:last_event
      return
    endif
    let s:last_event = s:event
  endif

  let info = type(a:info) == type("") ? [a:info] : a:info
  let info = easycomplete#util#ModifyInfoByMaxwidth(info, g:easycomplete_popup_width)

  if len(info) == 1 && len(info[0]) == 0
    if s:is_vim
      call popup_hide(g:easycomplete_popup_win["popup"])
    else
      call easycomplete#popup#close("popup")
    endif
    return
  endif
  call s:InitBuf(info, 'popup',  getbufvar(bufnr(), "&filetype"))
  let prevw_width = easycomplete#popup#DisplayWidth(info,
        \ g:easycomplete_popup_width)
  let prevw_height = easycomplete#popup#DisplayHeight(info, prevw_width, 'popup') - 1
  let opt = {
        \ 'focusable': v:true,
        \ 'width': prevw_width,
        \ 'height': prevw_height,
        \ 'relative':'editor',
        \ 'style':'minimal',
        \ 'filetype': &filetype
        \ }
  if g:env_is_vim
    let pum_pos = pum_getpos()
  else
    let pum_pos = easycomplete#pum#PumGetPos()
  endif
  if get(pum_pos, 'scrollbar')
    let right_avail_col  = pum_pos.col + pum_pos.width + 1
  else
    let right_avail_col  = pum_pos.col + pum_pos.width
  endif
  let left_avail_col = pum_pos.col - 2

  let right_avail = &co - right_avail_col - (g:easycomplete_winborder ? 2 : 0)
  let left_avail = left_avail_col + 1 - (g:easycomplete_winborder ? 2 : 0)

  if right_avail >= prevw_width + (g:easycomplete_winborder ? 2 : 0)
    let opt.col = right_avail_col + (g:easycomplete_winborder ? 2 : 0)
  elseif left_avail >= prevw_width + (g:easycomplete_winborder ? 2 : 0)
    let opt.col = left_avail_col - prevw_width + 1 - (g:easycomplete_winborder ? 2 : 0)
  else
    " 如果左右都没有正常空间可以展开

    " 如果左右空间都小于 20，直接关闭
    if right_avail <= 20 && left_avail <= 20
      call easycomplete#popup#close("popup")
      return
    endif

    if right_avail >= left_avail
      " 右侧空间较大
      " let opt.col = float2nr(right_avail_col) + (g:easycomplete_winborder ? 2 : 0)
      let opt.col = pum_pos.col + pum_pos.width + 1 + (g:easycomplete_winborder ? 2 : 0)
      let opt.width = float2nr(right_avail) - (g:easycomplete_winborder ? 2 : 0)
    else
      " 左侧空间较大
      let opt.col = 0
      let opt.width = float2nr(left_avail)
    endif
  endif

  let l:screen_line = winline() + (win_screenpos(win_getid())[0] - 1)
  let screen_enc = (win_screenpos(win_getid())[0] - 1)
  if l:screen_line <= pum_pos.row
    " 菜单向下展开
    let opt.row = pum_pos.row
    let opt.row = winline() + screen_enc
  else
    " 菜单向上展开
    let opt.row = l:screen_line - opt.height - 1
    let opt.row -= (g:easycomplete_winborder ? 2 : 0)
  endif

  if s:is_nvim
    call easycomplete#popup#close("popup")
    call s:NVimShow(opt, "popup", '')
  elseif s:is_vim
    call s:VimShow(opt, "popup", '')
  endif
endfunction

" info: content
" buftype: float/popup
" ft: filetype
function! s:InitBuf(info, buftype, ft)
  let ft = empty(a:ft) ?  getbufvar(bufnr(), "&filetype") : a:ft
  if empty(ft)
    let ft = "txt"
  endif
  if !s:buf[a:buftype]
    if s:is_vim
      noa let s:buf[a:buftype] = bufadd('')
      noa call bufload(s:buf[a:buftype])
      noa call setbufvar(s:buf[a:buftype], '&filetype', ft)
    elseif s:is_nvim
      let s:buf[a:buftype] = nvim_create_buf(v:false, v:true)
      call nvim_buf_set_option(s:buf[a:buftype], 'filetype', ft)
      call nvim_buf_set_option(s:buf[a:buftype], 'syntax', 'on')
    endif
    call setbufvar(s:buf[a:buftype], '&buflisted', 0)
    call setbufvar(s:buf[a:buftype], '&buftype', 'nofile')
    call setbufvar(s:buf[a:buftype], '&undolevels', -1)
  endif

  if s:is_nvim
    call nvim_buf_set_lines(s:buf[a:buftype], 0, -1, v:false, a:info)
  elseif s:is_vim
    noa silent call deletebufline(s:buf[a:buftype], 1, '$')
    noa silent call setbufline(s:buf[a:buftype], 1, a:info)
  endif
endfunction

function! s:StopVisualAsyncRun()
  if exists('s:popup_visual_delay') && s:popup_visual_delay > 0
    call timer_stop(s:popup_visual_delay)
  endif
endfunction

function! s:StartPopupAsyncRun(method, args, times)
  let s:popup_visual_delay = timer_start(a:times,
        \ { -> easycomplete#util#call(function(a:method), a:args)})
endfunction

" windowtype: float/popup
" float_type: lint/signature
function! s:VimShow(opt, windowtype, float_type)
  if s:is_nvim | return | endif
  let opt = {
        \ 'filetype': a:opt.filetype,
        \ 'line': a:opt.row + 1,
        \ 'col': a:opt.col + 1,
        \ 'maxwidth': a:opt.width,
        \ 'maxheight': a:opt.height,
        \ 'firstline': 0,
        \ 'fixed': 1,
        \ }
  if exists('a:opt.highlight')
    let opt.highlight = a:opt.highlight
  else
    let opt.highlight = 'Pmenu'
  endif

  " TODO: 在 iTerm2 下，执行 popup_move/popup_setoptions/popup_create 会造成
  " complete menu 的闪烁，原因未知
  let winid = g:easycomplete_popup_win[a:windowtype]
  if opt.filetype == "lua"
    " lua documentation 中包含大量注释，妨碍阅读，改成 help
    let opt.filetype = "help"
  endif
  if winid != 0
    call setwinvar(winid, '&wincolor', opt.highlight)
    call popup_setoptions(winid, opt)
    call popup_show(winid)
  else
    noa let winid = popup_create(s:buf[a:windowtype], opt)
    noa let g:easycomplete_popup_win[a:windowtype] = winid
    " ano silent call setwinvar(winid, '&scrolloff', 1)
    " ano silent call setwinvar(winid, 'float', 1)
    " ano silent call setwinvar(winid, '&number', 0)
    " call setwinvar(winid, '&list', 0)
    " call setwinvar(winid, '&cursorcolumn', 0)
    " call setwinvar(winid, '&colorcolumn', 0)
    " call setwinvar(winid, '&wrap', 1)
    " call setwinvar(winid, '&linebreak', 1)
    " call setwinvar(winid, '&conceallevel', 2)
    call setwinvar(winid, '&foldenable', 0)
  endif
  " Popup and Signature
  if a:windowtype == 'popup'
    call easycomplete#util#execute(g:easycomplete_popup_win[a:windowtype], "set nowrap")
  endif
  if a:windowtype == 'popup' || (a:windowtype == "float" && a:float_type == "signature")
    call setbufvar(winbufnr(winid), '&filetype', opt.filetype)
    call easycomplete#ui#ApplyMarkdownSyntax(winid)
  elseif a:windowtype == "float" && a:float_type == "lint"
    let bgcolor = easycomplete#ui#GetBgColor("CursorLine")
    let fgcolor = s:GetSignGuifgAtCurrentLine()
    if fgcolor == "NONE"
      let fgcolor = easycomplete#ui#GetFgColor("Comment")
    endif
    call easycomplete#ui#hi("EasyLintStyle", fgcolor, bgcolor, "")
    call setwinvar(winid, '&wincolor', "EasyLintStyle")
  else
    " Lint
    call setbufvar(winbufnr(winid), '&filetype', 'txt')
  endif
endfunction

function! s:GetSignGuifgAtCurrentLine()
  let l:current_line = line('.')
  let l:signs = sign_getplaced(bufnr(), {'group': 'g999'})
  if empty(l:signs[0]['signs'])
    return "NONE"
  endif

  let l:find_ln = 0
  " 四种：errro warnning information hint
  let l:text_hl = ""
  for item in l:signs[0]['signs']
    if item["lnum"] == l:current_line
      let l:find_ln = item["lnum"]
      let l:text_hl = item["name"]
      break
    endif
  endfor

  if l:find_ln == 0
    return "NONE"
  endif

  let real_name = substitute(l:text_hl,"_holder","","g")
  let group_style = get(g:easycomplete_diagnostics_config, real_name, {"fg_color":"NONE"})
  let fgcolor = get(group_style, "fg_color")
  return fgcolor
endfunction

" windowtype 有两类：
" 1. float: 函数参数说明 alert(I) 和 lint。通过 float_type 来区分 （lint，signature）
" 2. popup：用来显示 pum 的 info
function! s:NVimShow(opt, windowtype, float_type)
  if s:is_vim | return | endif
  let l:filetype = &filetype == "lua" ? "help" : &filetype
  " let hl_str = 'Normal:Pmenu,NormalNC:Pmenu'
  let opt = a:opt
  " pum info
  if g:easycomplete_winborder && (a:windowtype == "popup")
    let opt.border = g:easycomplete_info_border_style
  endif
  " signature
  if g:easycomplete_winborder && (a:windowtype == "float" && a:float_type == "signature")
    let opt.border = g:easycomplete_info_border_style
  endif
  if has_key(opt, "filetype")
    unlet opt.filetype
  endif
  if has_key(opt, "highlight")
    unlet opt.highlight
  endif
  noa let winid = nvim_open_win(s:buf[a:windowtype], v:false, opt)
  let g:easycomplete_popup_win[a:windowtype] = winid
  if a:windowtype == "popup" || (a:windowtype == "float" && a:float_type == "signature")
    call setwinvar(winid, '&winhl', 'Normal:Pmenu,NormalNC:Pmenu,Search:Normal,Error:Pmenu,Search:EasyNone')
    call setwinvar(winid, '&spell', 0)
  elseif a:windowtype == "float" && a:float_type == "lint"
    let bgcolor = easycomplete#ui#GetBgColor("CursorLine")
    let fgcolor = s:GetSignGuifgAtCurrentLine()
    if fgcolor == "NONE"
      let fgcolor = easycomplete#ui#GetFgColor("Comment")
    endif
    call easycomplete#ui#hi("EasyLintStyle", fgcolor, bgcolor, "")
    call setwinvar(winid, '&winhl', 'Normal:Pmenu,NormalNC:EasyLintStyle,Search:EasyNone')
  else
    call setwinvar(winid, '&winhl', 'Normal:Pmenu,NormalNC:Pmenu,Search:EasyNone')
  endif
  if has('nvim-0.5.0')
    call setwinvar(g:easycomplete_popup_win[a:windowtype], '&scrolloff', 0)
    call setwinvar(g:easycomplete_popup_win[a:windowtype], '&spell', 0)
    if a:windowtype == 'popup'
      call setwinvar(g:easycomplete_popup_win[a:windowtype], '&wrap', 0)
    endif
  endif
  if a:windowtype == 'popup' && exists("&pumblend")
    call setwinvar(g:easycomplete_popup_win[a:windowtype], '&winblend', &pumblend)
  endif
  try
    call easycomplete#util#execute(g:easycomplete_popup_win[a:windowtype], "TSBufDisable highlight")
  catch
  endtry
  " Popup and Signature
  if a:windowtype == 'popup' || (a:windowtype == "float" && a:float_type == "signature")
    call setbufvar(winbufnr(winid), '&filetype', l:filetype)
  else
    " Lint
    call setbufvar(winbufnr(winid), '&filetype', 'txt')
  endif
  if a:windowtype == "float" && a:float_type == "signature"
    if has("nvim-0.9.0")
      call setbufvar(winbufnr(winid), '&filetype', 'markdown')
      call setbufvar(winbufnr(winid), '&conceallevel', 3)
    endif
    call easycomplete#ui#ApplyMarkdownSyntax(winid)
  endif
endfunction

function! easycomplete#popup#reopen()
  call easycomplete#popup#close("popup")
  call easycomplete#popup#DoPopup(s:info, g:easycomplete_popup_delay)
endfunction

function! easycomplete#popup#visiable()
  if g:easycomplete_popup_win["popup"] || g:easycomplete_popup_win["float"]
    return v:true
  endif
  return v:false
endfunction

function! easycomplete#popup#CloseLintPopup()
  if easycomplete#popup#LintPopupVisible()
    call s:CloseByWindowType("float")
  endif
endfunction

" 把所有的 buf 都清空，以便所有关闭的 window 都被内存回收
function! easycomplete#popup#free()
  if !g:easycomplete_popup_win["popup"] && s:buf["popup"]
    execute 'bwipeout' . s:buf["popup"]
    let s:buf["popup"] = 0
  endif
  if !g:easycomplete_popup_win["float"] && s:buf["float"]
    execute 'bwipeout' . s:buf["float"]
    let s:buf["float"] = 0
  endif
endfunction

function! s:CloseByWindowType(win_type)
  let windowtype = a:win_type
  if s:is_vim
    if g:easycomplete_popup_win[windowtype]
      call popup_close(g:easycomplete_popup_win[windowtype])
      let g:easycomplete_popup_win[windowtype] = 0
    endif
  else
    if g:easycomplete_popup_win[windowtype]
      let id = win_id2win(g:easycomplete_popup_win[windowtype])
      if id > 0
        let winid = g:easycomplete_popup_win[windowtype]
        " 这里的hack有一定的隐患，这里的timer有可能给completedone事件带来干扰
        " ref: #281
        if !(g:easycomplete_pum_noselect)
          let delay = 20
        else
          let delay = 30
        endif
        call timer_start(delay, { -> s:NvimCloseFloatWithPum(winid, windowtype) })
      endif
      let g:easycomplete_popup_win[windowtype] = 0
      let s:last_winargs = []
    endif
  endif
endfunction

function! easycomplete#popup#close(...)
  "call setwinvar(winid, '&hlsearch', s:hlsearch)
  if empty(a:000)
    if g:easycomplete_popup_win["popup"]
      call easycomplete#popup#close("popup")
    endif
    if g:easycomplete_popup_win["float"]
      call easycomplete#popup#close("float")
    endif
    return
  endif
  let windowtype = a:1
  if windowtype == "float" &&
        \ bufnr() != expand("<abuf>") &&
        \ !empty(expand("<abuf>")) &&
        \ ((g:env_is_vim && pumvisible()) || g:env_is_nvim && easycomplete#pum#visible()) &&
        \ easycomplete#util#InsertMode()
    return
  endif
  call s:CloseByWindowType(windowtype)
  if windowtype == "float"
    let s:float_type = ""
    let s:float_opt = {}
  endif
endfunction

function! s:NvimCloseFloatWithPum(winid, windowtype)
  if nvim_win_is_valid(a:winid)
    call nvim_win_close(a:winid, 1)
  endif
  if easycomplete#pum#visible() && s:IsOverlay()
    let winid = g:easycomplete_popup_win['float']
    if winid != 0
      if nvim_win_is_valid(winid)
        call nvim_win_close(winid, 1)
      endif
    endif
  endif
endfunction

function! easycomplete#popup#DisplayWidth(lines, max_width)
  let width = 0
  for line in a:lines
    let w = strdisplaywidth(line)
    if w < a:max_width
      if w > width
        let width = w
      endif
    else
      let width = a:max_width
    endif
  endfor
  return width
endfunction

function! easycomplete#popup#DisplayHeight(lines, width, type)
  " 1 for padding
  let height = 1
  " for line in a:lines
  "   let height += (strdisplaywidth(line) + a:width - 1) / a:width
  " endfor
  let height = len(a:lines) + 1
  if a:type == "float"
    let max_height = s:float_max_height
  else
    let max_height = s:popup_max_height
  endif
  return height > max_height ? max_height : height
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! s:trace(...)
  return call('easycomplete#util#trace', a:000)
endfunction

function! s:AsyncRun(...)
  return call('easycomplete#util#AsyncRun', a:000)
endfunction

function! s:debug(...)
  return call('easycomplete#util#debug', a:000)
endfunction
