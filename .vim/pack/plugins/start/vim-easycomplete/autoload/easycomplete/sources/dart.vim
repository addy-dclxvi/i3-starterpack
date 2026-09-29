function! easycomplete#sources#dart#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'dartls',
      \ 'cmd': [easycomplete#installer#GetCommand(a:opt['name'])],
      \ 'root_uri':{ server_info -> easycomplete#util#GetDefaultRootUri() },
      \ 'initialization_options': v:null,
      \ 'allowlist': a:opt['whitelist'],
      \ 'config': {},
      \ 'semantic_highlight': {},
      \ 'workspace_config': {
      \    "dart": {
      \      "enableSdkFormatter": v:false,
      \      "analysisExcludedFolders": v:false,
      \      "showTodos": v:false,
      \      "enableSnippets": v:false,
      \    },
      \  },
      \ })
endfunction

function! easycomplete#sources#dart#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#dart#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction


