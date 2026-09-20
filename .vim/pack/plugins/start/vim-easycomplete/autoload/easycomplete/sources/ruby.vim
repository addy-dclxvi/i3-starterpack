function! easycomplete#sources#ruby#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'solargraph',
      \ 'cmd': {server_info->[easycomplete#installer#GetCommand(a:opt['name']), 'stdio']},
      \ 'initialization_options':  {
      \     'diagnostics': 'true'
      \ },
      \ 'allowlist': a:opt["whitelist"],
      \ })
endfunction

function! easycomplete#sources#ruby#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#ruby#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction

