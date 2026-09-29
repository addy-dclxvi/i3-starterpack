function! easycomplete#sources#xml#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'lemminx',
      \ 'cmd': [easycomplete#installer#GetCommand(a:opt['name'])],
      \ 'root_uri':{server_info -> easycomplete#util#GetDefaultRootUri()},
      \ 'initialization_options': {},
      \ 'allowlist': a:opt["whitelist"],
      \ })
endfunction

function! easycomplete#sources#xml#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#xml#GotoDefinition(...)
  return easycomplete#DoLspDefinition(["xml"])
endfunction

function! easycomplete#sources#xml#filter(matches, ctx)
  let ctx = easycomplete#context()
  let matches = a:matches
  if ctx['typed'] =~ "\\w:\\w\\{-}$" " x:y~ 的处理
    let matches = map(copy(matches), function("s:XmlHack_S_ColonMap"))
  elseif ctx['typed'] =~ "</$" " </> 的处理
    let matches = map(copy(matches), function("s:XmlHack_S_ColonMap"))
  endif
  let matches = map(copy(matches), function('s:XmlSnip'))
  return matches
endfunction

function! s:XmlSnip(key, val)
  return easycomplete#util#SnipMap(a:key, a:val)
endfunction

function! s:XmlHack_S_ColonMap(key, val)
  if has_key(a:val, "abbr") && has_key(a:val, "word")
        \ && get(a:val, "abbr") =~ "\\w\\:\\w\\{-}\\~$"
    let abbr = a:val.abbr
    let a:val.word = substitute(substitute(abbr, "^\\w\\{-}\\:", "", 'g'), "\\~$", "", 'g')
    let a:val.user_data = ""
  elseif has_key(a:val, "abbr") && has_key(a:val, "word")
        \ && trim(get(a:val, "word")) =~ "/[:a-zA-Z0-9]\\{-}>$"
    let word = trim(a:val.word)
    let a:val.word = substitute(word, "^<\\{-}/", "", 'g')
    let a:val.user_data = ""
  endif
  return a:val
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
