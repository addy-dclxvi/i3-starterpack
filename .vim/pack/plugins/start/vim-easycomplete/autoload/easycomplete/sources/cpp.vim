function! easycomplete#sources#cpp#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'clangd',
      \ 'cmd': {server_info->[easycomplete#installer#GetCommand(a:opt['name'])]},
      \ 'initialization_options':{
      \    'cache': {'directory': '/tmp/clangd/cache'},
      \    'completion': {'detailedLabel': v:false }
      \  },
      \ 'allowlist': a:opt['whitelist'],
      \ })
endfunction

function! easycomplete#sources#cpp#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#cpp#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction

function! easycomplete#sources#cpp#filter(matches, ctx)
  let ctx = a:ctx
  let matches = map(copy(a:matches), function("easycomplete#util#FunctionSurffixMap"))
  let matches_ret = map(copy(matches), function("s:CppItemPrefixHandling"))
  return matches_ret
endfunction

function! s:CppItemPrefixHandling(key, val)
  " `•clockid_t` -> `clockid_t`
  " ` std::chrono` -> `std::chrono`
  let item = a:val
  let first_char = strcharpart(item['abbr'], 0, 1)
  let abbr = item['abbr']
  if char2nr(first_char) == 32 " 首字符是空格
    let item['abbr'] = substitute(abbr, "^\\s\\+\\(.\\{\-}\\)$","\\1","g")
  elseif strlen(first_char) > 1
    let item['abbr'] = strcharpart(abbr, 1)
  endif
  return item
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction
