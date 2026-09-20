function! easycomplete#sources#go#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'gopls',
      \ 'cmd': { server_info->[easycomplete#installer#GetCommand(a:opt['name'])] },
      \ 'root_uri':{ server_info -> easycomplete#util#GetDefaultRootUri() },
      \ 'initialization_options':  {
      \     'completeUnimported': v:true,
      \     'matcher': 'fuzzy',
      \     'codelenses': {
      \         'generate': v:true,
      \         'test': v:true,
      \     },
      \ },
      \ 'allowlist': a:opt["whitelist"],
      \ })
endfunction

function! easycomplete#sources#go#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#go#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction

function! easycomplete#sources#go#filter(matches, ctx)
  let ctx = a:ctx
  let matches = a:matches
  let matches = map(copy(matches), function("easycomplete#util#FunctionSurffixMap"))
  return matches
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction
