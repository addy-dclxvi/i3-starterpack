function! easycomplete#sources#php#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'intelephense',
      \ 'cmd': {server_info->[easycomplete#installer#GetCommand(a:opt['name']), '--stdio']},
      \ 'root_uri':{server_info -> easycomplete#util#GetDefaultRootUri()},
      \ 'config': {'refresh_pattern': '\(\$[a-zA-Z0-9_:]*\|\k\+\)$'},
      \ 'allowlist': a:opt["whitelist"],
      \ })
endfunction

function! easycomplete#sources#php#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#php#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction

function! easycomplete#sources#php#filter(matches, ctx)
  let ctx = a:ctx
  let matches = a:matches
  let matches = map(copy(matches), function("easycomplete#util#FunctionSurffixMap"))
  return matches
endfunction
