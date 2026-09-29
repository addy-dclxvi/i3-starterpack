function! easycomplete#sources#bash#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'bashls',
      \ 'cmd': [easycomplete#installer#GetCommand(a:opt['name']), 'start'],
      \ 'root_uri':{ server_info -> easycomplete#util#GetDefaultRootUri() },
      \ 'allowlist': a:opt['whitelist'],
      \ 'config': {'refresh_pattern': '\([a-zA-Z0-9_-]\+\|\k\+\)$'},
      \ })
endfunction

function! easycomplete#sources#bash#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#bash#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction

