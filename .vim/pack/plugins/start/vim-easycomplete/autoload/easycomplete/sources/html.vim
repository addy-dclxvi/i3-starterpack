function! easycomplete#sources#html#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'html',
      \ 'cmd': {server_info->[easycomplete#installer#GetCommand(a:opt['name']), '--stdio']},
      \ 'initialization_options':{'embeddedLanguages': {'css': v:true, 'javascript': v:true}},
      \ 'allowlist': a:opt["whitelist"],
      \ })
endfunction

function! easycomplete#sources#html#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#html#GotoDefinition(...)
  return easycomplete#DoLspDefinition(["html","htm","xhtml"])
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction
