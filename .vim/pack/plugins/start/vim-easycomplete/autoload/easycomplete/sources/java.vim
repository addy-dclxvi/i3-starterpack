function! easycomplete#sources#java#constructor(opt, ctx)
  " 注册 lsp
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'jdtls',
      \ 'cmd': {server_info->[easycomplete#installer#GetCommand(a:opt['name'])]},
      \ 'root_uri':{server_info -> easycomplete#util#GetDefaultRootUri()},
      \ 'allowlist': a:opt["whitelist"],
      \ })
endfunction

function! easycomplete#sources#java#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#java#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction
