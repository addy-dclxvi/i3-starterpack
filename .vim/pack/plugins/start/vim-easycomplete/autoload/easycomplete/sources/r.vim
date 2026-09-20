function! easycomplete#sources#r#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'r-languageserver',
      \ 'cmd': [easycomplete#installer#GetCommand(a:opt['name'])],
      \ 'allowlist': a:opt['whitelist'],
      \ 'root_uri':{server_info->easycomplete#util#GetDefaultRootUri()},
      \ })
endfunction

function! easycomplete#sources#r#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#r#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction
