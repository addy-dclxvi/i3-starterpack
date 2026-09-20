" TODO 仍未调通，应该是 cmake-languageserver 本身的 bug
" 参考：https://github.com/regen100/cmake-language-server/issues/9
function! easycomplete#sources#cmake#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'cmake',
      \ 'cmd': [easycomplete#installer#GetCommand(a:opt['name'])],
      \ 'root_uri':{ server_info -> easycomplete#util#GetDefaultRootUri() },
      \ 'initialization_options': {'buildDirectory': 'build'},
      \ 'allowlist': a:opt['whitelist'],
      \ })
endfunction

function! easycomplete#sources#cmake#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#cmake#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction


