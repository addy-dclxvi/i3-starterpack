function! easycomplete#sources#css#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
    \ 'name': 'cssls',
    \ 'cmd': [easycomplete#installer#GetCommand(a:opt['name']), '--stdio'],
    \ 'allowlist': a:opt['whitelist'],
    \ 'config': {'refresh_pattern': '\([a-zA-Z0-9_-]\+\)$'},
    \ })
endfunction

function! easycomplete#sources#css#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#css#GotoDefinition(...)
  return easycomplete#DoLspDefinition(["css","less","scss","sass"])
endfunction

