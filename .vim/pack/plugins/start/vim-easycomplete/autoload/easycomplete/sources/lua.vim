let g:sumneko_lua_language_server_workspace_config = {
        \  'Lua': {
        \    'color': {
        \      'mode': 'Semantic'
        \    },
        \    'completion': {
        \      'callSnippet': 'Disable',
        \      'enable': v:true,
        \      'keywordSnippet': 'Replace'
        \    },
        \    'develop': {
        \      'debuggerPort': 11412,
        \      'debuggerWait': v:false,
        \      'enable': v:false
        \    },
        \    'diagnostics': {
        \      'enable': v:true,
        \      'globals': '',
        \      'severity': {}
        \    },
        \    'hover': {
        \      'enable': v:true,
        \      'viewNumber': v:true,
        \      'viewString': v:true,
        \      'viewStringMax': 1000
        \    },
        \    'runtime': {
        \      'path': ['?.lua', '?/init.lua', '?/?.lua'],
        \      'version': 'Lua 5.3'
        \    },
        \    'signatureHelp': {
        \      'enable': v:true
        \    },
        \    'workspace': {
        \      'ignoreDir': [],
        \      'maxPreload': 1000,
        \      'preloadFileSize': 100,
        \      'useGitIgnore': v:true
        \    }
        \  },
        \  "sumneko-lua": {
        \    'enableNvimLuaDev': v:true
        \  }
        \ }

function! easycomplete#sources#lua#constructor(opt, ctx)
  let config_param = ""
  let config_path = easycomplete#util#GetConfigPath(a:opt["name"])
  if easycomplete#util#FileExists(config_path)
    let config_param = "--configpath=" . config_path
  endif
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'sumneko_lua',
      \ 'cmd': [easycomplete#installer#GetCommand(a:opt['name']), config_param],
      \ 'root_uri':{server_info -> easycomplete#util#GetDefaultRootUri()},
      \ 'config': {},
      \ 'workspace_config': g:sumneko_lua_language_server_workspace_config,
      \ 'allowlist': a:opt["whitelist"],
      \ })
endfunction

function! easycomplete#sources#lua#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#lua#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction

function! easycomplete#sources#lua#filter(matches, ctx)
  let ctx = a:ctx
  let matches = a:matches
  " if ctx['typed'] =~ '\(\w\+\.\)\{-1,}$' " LoaDotTyping bugfix for #196
  "   call filter(matches, function("s:LuaHack_S_DotFilter"))
  " endif
  let matches = map(copy(matches), function("s:LuaHack_A_DotMap"))
  let matches = map(copy(matches), function("easycomplete#util#FunctionSurffixMap"))
  return matches
endfunction

function! s:LuaHack_A_DotMap(key, val)
  if has_key(a:val, "abbr") && has_key(a:val, "word")
        \ && stridx(get(a:val, "word"), ".") > 0
    let ctx = easycomplete#context()
    let lua_typing_word = s:GetLuaTypingWordWithDot()
    if ctx["char"] == "."
      let a:val.word = substitute(get(a:val, "word"), "^" . lua_typing_word, "", "g")
      let a:val.abbr = a:val.word
    else
      let word = easycomplete#util#GetTypingWord()
      let a:val.word = substitute(get(a:val, "word"), "^" . lua_typing_word[:-1 * ( 1 + strlen(word))], "", "g")
      let a:val.abbr = a:val.word
    endif
    let lua_typing_word = s:GetLuaTypingWordWithDot()
  endif
  return a:val
endfunction

function! s:LuaHack_S_DotFilter(key, val)
  if has_key(a:val, "abbr") && has_key(a:val, "word")
        \ && stridx(get(a:val, "word"), ".") > 0
    let lua_typing_word = s:GetLuaTypingWordWithDot()
    return stridx(get(a:val, "word"), lua_typing_word) == 0
  else
    return v:false
  endif
endfunction

function! s:GetLuaTypingWordWithDot()
  let start = col('.') - 1
  let line = getline('.')
  let width = 0
  let regx = '[a-zA-Z0-9_.:]'
  while start > 0 && line[start - 1] =~ regx
    let start = start - 1
    let width = width + 1
  endwhile
  let word = strpart(line, start, width)
  return word
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! s:get(...)
  return call('easycomplete#util#get', a:000)
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction
