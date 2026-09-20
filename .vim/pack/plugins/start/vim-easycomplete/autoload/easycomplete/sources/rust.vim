function! easycomplete#sources#rust#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'rust_analyzer',
      \ 'cmd': [easycomplete#installer#GetCommand(a:opt['name'])],
      \ 'root_uri':{server_info -> easycomplete#util#GetDefaultRootUri()},
      \ 'allowlist': a:opt["whitelist"],
      \ 'initialization_options': {
      \     'completion': {
      \       'autoimport': { 'enable': v:true },
      \     },
      \     'diagnostics': {
      \       'enable': v:true,
      \       'warningsAsInfo': v:true
      \     },
      \     'cargo': {
      \       'buildScripts': {
      \         'enable': v:false,
      \       },
      \       'loadOutDirsFromCheck': v:true
      \     },
      \     'procMacro': {
      \       'enable': v:true,
      \     },
      \     "cachePriming": {
      \       "enable": v:false
      \     },
      \     "check": {
      \       "allTargets": v:false
      \     },
      \     "checkOnSave": v:false,
      \     "experimental": {
      \       "procAttrMacros": v:true
      \     }
      \ },
      \ 'config': {},
      \ 'workspace_config' : {},
      \ 'semantic_highlight' : {}
      \ })
endfunction

function! easycomplete#sources#rust#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#rust#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction
