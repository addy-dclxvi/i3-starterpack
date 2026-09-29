function! easycomplete#sources#py#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'pylsp',
      \ 'cmd': {server_info->[easycomplete#installer#GetCommand(a:opt['name'])]},
      \ 'root_uri':{server_info -> easycomplete#util#GetDefaultRootUri()},
      \ 'allowlist': a:opt["whitelist"],
      \ })
endfunction

function! easycomplete#sources#py#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#py#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction

function! easycomplete#sources#py#filter(matches, ctx)
  let ctx = a:ctx
  let matches = a:matches
  let matches = map(copy(matches), function("easycomplete#util#FunctionSurffixMap"))
  return matches
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction
