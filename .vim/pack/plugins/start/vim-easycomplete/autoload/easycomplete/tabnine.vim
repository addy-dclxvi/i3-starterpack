" ./sources/tn.vim 负责pum匹配，这里只负责做代码联想提示
" tabnine suggestion 和 tabnine complete 共享一个 job
" tabnine suggestion 只支持 nvim

let s:tabnine_toolkit = easycomplete#util#HasLua() ? v:lua.require("easycomplete.tabnine") : v:null
" 临时存放 suggest 或者 complete
let b:tabnine_typing_type = ""
let s:tabnine_hint_snippet = []

function easycomplete#tabnine#ready()
  if g:env_is_vim
    return v:false
  endif
  if !easycomplete#util#HasLua()
    return v:false
  endif
  if !easycomplete#ok('g:easycomplete_tabnine_enable')
    return v:false
  endif
  if !easycomplete#ok('g:easycomplete_tabnine_suggestion')
    return v:false
  endif
  if !easycomplete#installer#LspServerInstalled("tn")
    return v:false
  endif
  return v:true
endfunction

function! easycomplete#tabnine#fire()
  if (g:env_is_vim && pumvisible()) || (g:env_is_nvim && easycomplete#pum#visible())
    return
  endif
  if !easycomplete#tabnine#ready()
    return
  endif
  " 不是空格除外的最后一个字符
  if !s:IsLastChar()
    return
  endif
  if easycomplete#IsBacking()
    return
  endif
  " 不是魔术指令
  if getline('.')[0:col('.')] =~ "\\s\\{-}TabNine::\\(config\\|sem\\)$"
    return
  endif

  call s:flush()
  call easycomplete#tabnine#SuggestFlagSet()
  call easycomplete#sources#tn#SimpleTabNineRequest()
endfunction

function! easycomplete#tabnine#SuggestFlagSet()
  let b:tabnine_typing_type = "suggest"
  call timer_start(800, { -> easycomplete#tabnine#SuggestFlagClear()})
endfunction

function! easycomplete#tabnine#SuggestFlagClear()
  let b:tabnine_typing_type = ""
endfunction

function! easycomplete#tabnine#TypingType()
  if exists("b:tabnine_typing_type")
    return b:tabnine_typing_type
  else
    return ""
  endif
endfunction

function! easycomplete#tabnine#LoadingStart()
  if easycomplete#tabnine#ready()
    call s:tabnine_toolkit.loading_start()
  endif
endfunction

function! easycomplete#tabnine#LoadingStop()
  if easycomplete#tabnine#ready()
    call s:tabnine_toolkit.loading_stop()
  endif
endfunction

function! easycomplete#tabnine#SuggestFlagCheck()
  if !exists("b:tabnine_typing_type")
    return v:false
  endif
  if b:tabnine_typing_type == "suggest"
    call easycomplete#tabnine#SuggestFlagClear()
    return v:true
  endif
  return v:false
endfunction

function! s:flush()
  if exists("s:tabnine_hint_snippet") && empty(s:tabnine_hint_snippet)
    return
  endif
  if !easycomplete#tabnine#ready()
    return
  endif
  call s:tabnine_toolkit.delete_hint()
  call easycomplete#tabnine#SuggestFlagClear()
  call easycomplete#tabnine#LoadingStop()
  let s:tabnine_hint_snippet = []
endfunction

function! easycomplete#tabnine#flush()
  call s:flush()
endfunction

function! easycomplete#tabnine#Callback(res_array)
  if easycomplete#util#NotInsertMode()
    call s:flush()
    return
  endif
  let l:snippet = s:GetSnippets(a:res_array)
  let l:snippet_array = easycomplete#tabnine#ParseSnippets2Array(l:snippet)
  call s:tabnine_toolkit.show_hint(l:snippet_array)
  let s:tabnine_hint_snippet = deepcopy(l:snippet_array)
endfunction

function! easycomplete#tabnine#SnippetReady()
  return exists("s:tabnine_hint_snippet") && !empty(s:tabnine_hint_snippet)
endfunction

" 返回一个标准数组，提示和显示都用这一份数据
function! easycomplete#tabnine#ParseSnippets2Array(code_block)
  let l:lines = split(a:code_block, "\n")
  return l:lines
endfunction

function! s:nr()
  call appendbufline(bufnr(""), line("."), "")
  call cursor(line(".") + 1, 1)
endfunction

function! easycomplete#tabnine#insert()
  let l:tabnine_hint_snippet = s:tabnine_hint_snippet
  call s:flush()
  try
    let l:lines = l:tabnine_hint_snippet
    if len(l:lines) == 1 " 单行插入
      if getline('.') == ""
        call execute("normal! \<Esc>")
        call setbufline(bufnr(""), line("."), l:lines[0])
        call cursor(line('.'), len(l:lines[0]))
        call s:RemainInsertMode()
      else
        call feedkeys(l:lines[0], 'i')
      endif
    elseif len(l:lines) > 1 " 多行插入
      call execute("normal! \<Esc>")
      let curr_line_nr = line('.')
      let curr_line_str = getline(".")
      call setbufline(bufnr(""), line("."), curr_line_str . l:lines[0])
      for line in l:lines[1:]
        call s:nr()
        call setbufline(bufnr(""), line("."), line)
      endfor

      let end_line_nr = curr_line_nr + len(l:lines) - 1
      call cursor(end_line_nr, len(getline(end_line_nr)))
      call s:RemainInsertMode()
      redraw
    endif
  catch
    echom v:exception
  endtry
endfunction

function! s:RemainInsertMode()
  if mode() == "i"
    call feedkeys("\<Esc>A", 'in')
  else
    call execute("normal! A")
  endif
  call easycomplete#zizz()
endfunction

function! s:GetSnippets(res_array)
  let res = get(a:res_array, "results", [])
  if empty(res) | return [] | endif
  let new_prefix = ""
  let percent = 0
  for item in res
    let item_new_prefix = get(item, "new_prefix", "")
    if has_key(item, 'completion_metadata')
      let item_percent_str = easycomplete#util#get(item, 'completion_metadata', 'detail')
    else
      let item_percent_str = get(item, 'detail', "   ")
    endif
    let item_percent = str2nr(matchstr(item_percent_str, "\\d\\+"))
    if item_percent == percent
      if len(new_prefix) <= len(item_new_prefix)
        let new_prefix = item_new_prefix
      endif
    elseif item_percent > percent
      let new_prefix = item_new_prefix
      let percent = item_percent
    endif
  endfor
  " remove old prefix
  let old_prefix = get(a:res_array, "old_prefix", "")
  return new_prefix[len(old_prefix):]
endfunction

function! s:IsLastChar()
  let current_col = col('.')
  let current_line = getline('.')
  if current_col - 1 == len(current_line)
    return v:true
  endif
  let rest_of_line = current_line[current_col - 1:]
  if rest_of_line =~ "^\\s\\+$"
    return v:true
  else
    return v:false
  endif
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction
