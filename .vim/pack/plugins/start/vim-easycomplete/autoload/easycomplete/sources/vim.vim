function! easycomplete#sources#vim#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'vimls',
      \ 'cmd': {server_info->[easycomplete#installer#GetCommand(a:opt['name']), '--stdio']},
      \ 'allowlist': a:opt["whitelist"],
      \ 'initialization_options': {
      \   'vimruntime': expand($VIMRUNTIME),
      \   'runtimepath': &rtp,
      \   'iskeyword': '@,48-57,_,192-255,-#',
      \   'indexes':{'runtime':v:true, 'gap':1, 'count':10, 'runtimepath': v:false},
      \   "projectRootPatterns" : ["strange-root-pattern", ".git", "autoload", "plugin"],
      \   'diagnostic': {"enable": v:true},
      \   'suggest': { 'fromVimruntime': v:false, 'fromRuntimepath': v:false}
      \ }
      \ })
endfunction

function! easycomplete#sources#vim#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#vim#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction

" hack for #98 #92
function! easycomplete#sources#vim#filter(matches, ctx)
  let ctx = a:ctx
  let matches = a:matches
  if ctx['typed'] =~ "s:\\w\\{-}$"
    " hack for vim-language-server:
    "   s:<Tab> 和 s:abc<Tab> 匹配回来的 insertText 不应该带上 "s:"
    "   g:b:l:a:v: 都是正确的，只有 s: 不正确
    "   需要修改 word 为 insertText.slice(2)
    let matches = map(copy(matches), function("s:VimHack_S_ColonMap"))
  endif
  if ctx['typed'] =~ '\(\w\+\.\)\{-1,}$' " VimDotTyping bugfix for #92
    call filter(matches, function("s:VimHack_S_DotFilter"))
  endif
  let matches = map(copy(matches), function("s:VimHack_A_DotMap"))
  let matches = map(copy(matches), function("easycomplete#util#FunctionSurffixMap"))
  return matches
endfunction

function! s:VimHack_S_DotFilter(key, val)
  if has_key(a:val, "abbr") && has_key(a:val, "word")
        \ && stridx(get(a:val, "word"), ".") > 0
    let vim_typing_word = s:VimHack_GetVimTypingWord()
    return stridx(get(a:val, "word"), vim_typing_word) == 0
  else
    return v:false
  endif
endfunction

function! s:VimHack_S_ColonMap(key, val)
  if has_key(a:val, "abbr") && has_key(a:val, "word")
        \ && get(a:val, "abbr") ==# get(a:val, "word")
        \ && matchstr(get(a:val, "word"), "^s:") ==  "s:"
    let a:val.word = get(a:val, "word")[2:]
  endif
  return a:val
endfunction

function! s:VimHack_A_DotMap(key, val)
  if has_key(a:val, "abbr") && has_key(a:val, "word")
        \ && stridx(get(a:val, "word"), ".") > 0
    let ctx = easycomplete#context()
    let vim_typing_word = s:VimHack_GetVimTypingWord()
    if ctx["char"] == "."
      let a:val.word = substitute(get(a:val, "word"), "^" . vim_typing_word, "", "g")
    else
      let word = easycomplete#util#GetTypingWord()
      let a:val.word = substitute(get(a:val, "word"), "^" . vim_typing_word[:-1 * ( 1 + strlen(word))], "", "g")
    endif
    let vim_typing_word = s:VimHack_GetVimTypingWord()
  endif
  return a:val
endfunction

function! s:VimHack_GetVimTypingWord()
  let start = col('.') - 1
  let line = getline('.')
  let width = 0
  let regx = '[a-zA-Z0-9_.:]'
  while start > 0 && line[start - 1] =~ regx
    let start = start - 1
    let width = width + 1
  endwhile
  let word = strpart(line, start, width)
  return word
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction
