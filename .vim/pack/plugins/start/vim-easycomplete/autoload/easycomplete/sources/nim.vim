function! easycomplete#sources#nim#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'nimls',
      \ 'cmd': {server_info->[easycomplete#installer#GetCommand(a:opt['name'])]},
      \ 'root_uri':{server_info -> easycomplete#util#GetDefaultRootUri()},
      \ 'initialization_options' : {'diagnostics': 'true'},
      \ 'allowlist': a:opt["whitelist"],
      \ })
endfunction

function! easycomplete#sources#nim#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#nim#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction

