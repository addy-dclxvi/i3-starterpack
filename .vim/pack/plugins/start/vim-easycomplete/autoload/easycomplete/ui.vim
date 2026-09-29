let s:easycomplete_search_bg_color = ""
let s:easycomplete_search_fg_color = ""

" markdown syntax {{{
function! easycomplete#ui#ApplyMarkdownSyntax(winid)
  " 默认 Popup 的 Markdown 文档都基于 help syntax
  let regin_cmd = join(["syntax region NewCodeBlock matchgroup=Conceal start=/\%(``\)\@!`/ ",
                \ "matchgroup=Conceal end=/\%(``\)\@!`/ containedin=TOP concealends"],"")
  let original_filetype = getwinvar(a:winid, "&filetype")
  if has("nvim")
    if has("nvim-0.9.0")
      let exec_cmd = [
            \ 'syntax region markdownRule matchgroup=Conceal start=/\%(``\)\@!`/ matchgroup=Conceal end=/\%(``\)\@!`/ concealends',
            \ 'syntax region markdownCode matchgroup=Conceal start=/\%(||\)\@!|/ matchgroup=Conceal end=/\%(||\)\@!|/ concealends',
            \ "hi markdownRule cterm=underline gui=underline",
            \ ]
    else
      let exec_cmd = [
            \ "hi helpCommand cterm=underline gui=underline ctermfg=White guifg=White",
            \ "silent! syntax clear NewCodeBlock",
            \ regin_cmd,
            \ "hi! link NewCodeBlock helpCommand",
            \ "let &filetype='help'",
            \ ]
    endif
  else
    let exec_cmd = [
          \ "hi helpCommand cterm=underline gui=underline ctermfg=White guifg=White",
          \ "silent! syntax clear NewCodeBlock",
          \ regin_cmd,
          \ "hi! link NewCodeBlock helpCommand",
          \ "let &filetype='" . original_filetype . "'",
          \ ]
  endif
  try
    call easycomplete#util#execute(a:winid, exec_cmd)
  catch
    echom v:exception
  endtry
endfunction " }}}

function! easycomplete#ui#HighlightGroupExists(group)
  try
    call execute("hi " . a:group)
  catch /411/
    return v:false
  endtry
  return v:true
endfunction

" Get back ground color form a GroupName {{{
function! easycomplete#ui#GetBgColor(name)
  return easycomplete#ui#GetHiColor(a:name, "bg")
endfunction "}}}

" Get back ground color form a GroupName {{{
function! easycomplete#ui#GetFgColor(name)
  return easycomplete#ui#GetHiColor(a:name, "fg")
endfunction "}}}

" Get color from a scheme group {{{
function! easycomplete#ui#GetHiColor(hiName, sufix)
  let sufix = empty(a:sufix) ? "bg" : a:sufix
  let hlString = easycomplete#ui#HighlightArgs(a:hiName)
  let my_color = "NONE"
  if empty(hlString) | return my_color | endif
  if easycomplete#util#IsGui()
    " Gui color name
    let my_color = matchstr(hlString,"\\(\\sgui" . sufix . "=\\)\\@<=#\\{-}\\w\\+")
    if empty(my_color)
      let linksGroup = matchstr(hlString, "\\(links\\sto\\s\\+\\)\\@<=\\w\\+")
      if !empty(linksGroup)
        let my_color = easycomplete#ui#GetHiColor(linksGroup, a:sufix)
      endif
    endif
  else
    let my_color= matchstr(hlString,"\\(\\scterm" .sufix. "=\\)\\@<=\\w\\+")
  endif

  if my_color == "" || my_color == "NONE"
    return "NONE"
  endif

  " if my_color =~ '^\d\+$'
  "   return str2nr(my_color)
  " endif

  return my_color
endfunction " }}}

" Hilight {{{
function! easycomplete#ui#HighlightArgs(name)
  try
    let val = 'hi ' . substitute(split(execute('hi ' . a:name), '\n')[0], '\<xxx\>', '', '')
  catch /411/
    return ""
  endtry
  return val
endfunction "}}}

" Set color {{{
function! easycomplete#ui#hi(group, fg, bg, attr)
  let prefix = easycomplete#util#IsGui() ? "gui" : "cterm"
  if !empty(a:fg) && a:fg != -1
    call execute(join(['hi', a:group, prefix . "fg=" . a:fg ], " "))
  endif
  if !empty(a:bg) && a:bg != -1
    call execute(join(['hi', a:group, prefix . "bg=" . a:bg ], " "))
  endif
  if exists("a:attr") && !empty(a:attr) && a:attr != ""
    call execute(join(['hi', a:group, prefix . "=" . a:attr ], " "))
  endif
endfunction " }}}

" ClearSyntax {{{
function! easycomplete#ui#ClearSyntax(group)
  try
    execute printf('silent! syntax clear %s', a:group)
  catch /.*/
  endtry
endfunction " }}}

function! easycomplete#ui#qfhl() " {{{
  if easycomplete#ui#GetHiColor("qfLineNr", "fg") == 'NONE'
    hi qfLineNr ctermfg=LightBlue guifg=#6d96bf
  endif
endfunction " }}}

function! easycomplete#ui#HighlightWordUnderCursor() " {{{
  if empty(g:easycomplete_cursor_word_hl) | return | endif
  let disabled_ft = ["help", "qf", "fugitive", "nerdtree", "gundo", "diff", "fzf", "floaterm"]
  if &diff || &buftype == "terminal" || index(disabled_ft, &filetype) >= 0
    return
  endif
  let l:is_in_search_word = s:IsSearchWord()
  if l:is_in_search_word
    3match none
    return
  endif
  let curr_char = getline(".")[col(".")-1]
  if curr_char !~# '[[:punct:][:blank:]]' || curr_char == "_"
    if empty(s:easycomplete_search_bg_color)
      let bgcolor = easycomplete#ui#GetBgColor("Search")
    else
      let bgcolor = s:easycomplete_search_bg_color
    endif
    if empty(s:easycomplete_search_fg_color)
      let fgcolor = easycomplete#ui#GetFgColor("Search")
    else
      let fgcolor = s:easycomplete_search_fg_color
    endif
    let prefix_bg_key = easycomplete#util#IsGui() ? "guibg" : "ctermbg"
    let append_bg_str = l:is_in_search_word ? join([prefix_bg_key, bgcolor], "=") : join([prefix_bg_key, "NONE"], "=")
    let prefix_fg_key = easycomplete#util#IsGui() ? "guifg" : "ctermfg"
    let append_fg_str = l:is_in_search_word ? join([prefix_fg_key, fgcolor], "=") : join([prefix_fg_key, "NONE"], "=")
    exec "hi clear EasyMatchWord"
    exec "hi EasyMatchWord cterm=underline gui=underline " . append_bg_str . " " . append_fg_str
    try
      let cur_search_word = histget("search")
      exec '3match' 'EasyMatchWord' '/\V\<'.expand('<cword>').'\>/'
    catch
      " do nothing
    endtry
  else
    3match none
  endif
endfunction

function! easycomplete#ui#CmdlineCR()
  if (!exists("b:cs_searched") || b:cs_searched == v:false) && (getcmdtype() == '/' || getcmdtype() == '?')
    let b:cs_searched = v:true
  endif
  return "\<CR>"
endfunction

function! easycomplete#ui#TrackSearchNext()
  if !exists("b:cs_searched") || b:cs_searched == v:false
    let b:cs_searched = v:true
  endif
  let b:cs_searched = v:true
  return "n"
endfunction

function! easycomplete#ui#TrackSearchPrev()
  if !exists("b:cs_searched") || b:cs_searched == v:false
    let b:cs_searched = v:true
  endif
  let b:cs_searched = v:true
  return "N"
endfunction

function! easycomplete#ui#TrackSearchGlobal()
  if !exists("b:cs_searched") || b:cs_searched == v:false
    let b:cs_searched = v:true
  endif
  let b:cs_searched = v:true
  return "*"
endfunction

function! easycomplete#ui#HiFloatBorder()
  if g:easycomplete_pum_pretty_style == 1
    let l:bg = easycomplete#ui#GetBgColor("Normal")
    call easycomplete#ui#hi("Pmenu", "", l:bg, {})
    call easycomplete#ui#hi("FloatBorder", "", l:bg, {})
    call easycomplete#ui#hi("PmenuSBar", "", l:bg, {})
    call easycomplete#ui#hi("PmenuExtra", "", l:bg, {})
    call easycomplete#ui#hi("PmenuKind", "", l:bg, {})
  endif
endfunction

" error, warning, information, hint
function! easycomplete#ui#DiagColor(str_type)
  if a:str_type == "error"
    let color = easycomplete#ui#GetFgColor("DiagnosticFloatingError")
    if color == "NONE" | let color = "#FF0000" | endif
  elseif a:str_type == "warning"
    let color = easycomplete#ui#GetFgColor("DiagnosticFloatingWarn")
    if color == "NONE" | let color = "#FFFF00" | endif
  elseif a:str_type == "information"
    let color = easycomplete#ui#GetFgColor("DiagnosticFloatingInfo")
    if color == "NONE" | let color = "#5FFFAF" | endif
  elseif a:str_type == "hint"
    let color = easycomplete#ui#GetFgColor("DiagnosticFloatingHint")
    if color == "NONE" | let color = "#8787FF" | endif
  endif
  return color
endfunction

function! s:IsSearchWord()
  if !exists("b:cs_searched")
    let b:cs_searched = v:false
  endif
  if b:cs_searched == v:false
    return v:false
  endif
  let current_word = expand('<cword>')
  let search_word = histget("search")
  let search_word = substitute(search_word, "^\\\\\<", "", "g")
  let search_word = substitute(search_word, "\\\\\>$", "", "g")
  let search_word = s:SpecialTrim(search_word)
  if &ignorecase
    return current_word =~ search_word
  else
    return current_word =~# search_word
  endif
endfunction " }}}

function! s:SpecialTrim(search_word)
  " 去掉字符串开头的非字母数字字符
  let result = substitute(a:search_word, '^\W\+', '', '')
  " 去掉字符串结尾的非字母数字字符
  let result = substitute(result, '\W\+$', '', '')
  return result
endfunction

" console {{{
function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction " }}}

" log {{{
function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction " }}}

" get {{{
function! s:get(...)
  return call('easycomplete#util#get', a:000)
endfunction " }}}
