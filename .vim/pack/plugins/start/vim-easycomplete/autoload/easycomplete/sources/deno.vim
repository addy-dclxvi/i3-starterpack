let s:file_extensions = ["js","jsx","ts","tsx","mjs","ejs"]

function! easycomplete#sources#deno#constructor(opt, ctx)
  if easycomplete#sources#deno#ok()
    call easycomplete#RegisterLspServer(a:opt, {
          \ 'name': 'denols',
          \ 'cmd': {server_info->[easycomplete#installer#GetCommand(a:opt['name']), 'lsp', '--unstable']},
          \ 'root_uri':{server_info -> easycomplete#util#GetDefaultRootUri()},
          \ 'initialization_options' : {
          \   'enable': v:true,
          \   'lint': v:true,
          \   'unstable': v:true,
          \   'importMap': v:null,
          \   'codeLens': {
          \     'implementations': v:true,
          \     'references': v:true,
          \     'referencesAllFunctions': v:true,
          \     'test': v:true,
          \     'testArgs': ['--allow-all'],
          \   },
          \   "suggest": {
          \     "autoImports": v:true,
          \     "completeFunctionCalls": v:true,
          \     "names": v:true,
          \     "paths": v:true,
          \     "imports": {
          \       "autoDiscover": v:false,
          \       "hosts": {
          \         "https://deno.land/": v:true,
          \       },
          \     },
          \   },
          \   'config': v:null,
          \   'internalDebug': v:false,
          \  },
          \ 'config': {'refresh_pattern': '\(\$[a-zA-Z0-9_:]*\|\k\+\)$'},
          \ 'allowlist': a:opt["whitelist"],
          \ 'blocklist' : [],
          \ 'workspace_config' : {},
          \ 'semantic_highlight' : {},
          \ })
    call easycomplete#UnRegisterSource("ts")

    augroup easycomplete#DenoCommand
      command! DenoCache :call easycomplete#sources#deno#cache()
    augroup END
  endif
endfunction

function! easycomplete#sources#deno#ok()
  if easycomplete#sources#deno#IsTSOrJSFiletype() && easycomplete#sources#deno#IsDenoProject()
    return v:true
  else
    return v:false
  endif
endfunction

function! easycomplete#sources#deno#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

function! easycomplete#sources#deno#GotoDefinition(...)
  return easycomplete#DoLspDefinition()
endfunction

function! easycomplete#sources#deno#cache()
  if !easycomplete#sources#deno#ok()
    call s:log("Please do `deno cache` under a deno project!")
    return
  endif
  let current_file = easycomplete#util#GetCurrentFullName()
  let deno_command = easycomplete#installer#GetCommand("deno")
  let exec_command = deno_command . " cache " . current_file
  let current_dir = fnamemodify(expand('%'), ':p:h')
  if g:env_is_vim
    bo 5new
    call s:log('deno cache ' . current_file . ' ......')
    let l:bufnr = term_start(exec_command, {
        \ 'hidden' : 0,
        \ 'curwin' : 1,
        \ 'term_name':'deno_cache',
        \ })
    let l:job = term_getjob(l:bufnr)
    if l:job != v:null
      call job_setoptions(l:job, {'exit_cb': function('s:CachePost', [])})
    endif
  else
    bo 5new
    call termopen(exec_command, {
        \ 'cwd': current_dir,
        \ 'hidden' : 0,
        \ 'term_rows': 5,
        \ 'term_name':'deno_cache',
        \ 'on_exit': function('s:CachePost', []),
        \ })
    startinsert
  endif
endfunction

function! s:CachePost(job, code, ...) abort
  call easycomplete#util#timer_start('easycomplete#util#info', ['`deno cache` Finished!'], 10)
endfunction

function! easycomplete#sources#deno#filter(matches, ctx)
  let ctx = a:ctx
  let matches = a:matches
  let matches = map(copy(matches), function("easycomplete#util#FunctionSurffixMap"))
  return matches
endfunction

function! easycomplete#sources#deno#IsTSOrJSFiletype()
  if index(s:file_extensions, easycomplete#util#extention()) >= 0
    return v:true
  else
    return v:false
  endif
endfunction

function! easycomplete#sources#deno#IsDenoProject()
  if !easycomplete#sources#deno#IsTSOrJSFiletype() | return v:false | endif
  let current_file_path = easycomplete#util#GetCurrentFullName()
  let current_file_dir = fnamemodify(expand('%'), ':p:h')
  let ts_project_patterns = ["package.json", "tsconfig.json"]
  let deno_project_patterns = ["deno.json", "deno.jsonc", "import_map.json"]
  " 当存在 node_modules 时的情况要排除
  if isdirectory(current_file_dir . "/node_modules")
    return v:false
  endif
  for package_file in ts_project_patterns + deno_project_patterns
    let project_package_file = easycomplete#util#FindNearestParentFile(current_file_path, package_file)
    if !empty(project_package_file) && s:HasNodeMudulesDir(project_package_file)
      return v:false
    endif
  endfor
  " 存在 deno 配置文件
  for package_file in deno_project_patterns
    let project_package_file = easycomplete#util#FindNearestParentFile(current_file_path, package_file)
    if !empty(project_package_file)
      return v:true
    endif
  endfor

  let vscode_config = easycomplete#util#FindNearestParentFile(current_file_path, '.vscode')
  if empty(vscode_config) | return v:false | endif
  let vscode_settings = findfile(vscode_config . "/settings.json")
  if empty(vscode_settings) | return v:false | endif
  let vscode_json_str = join(readfile(vscode_settings), "")
  try
    if has("nvim")
      let vscode_json_obj = json_decode(vscode_json_str)
    else
      let vscode_json_obj = js_decode(vscode_json_str)
    endif
  catch
    return v:false
  endtry
  if get(vscode_json_obj, "deno.enable", v:false)
    " TODO 还需做这这个判断  "deno.unstable": true
    if !get(vscode_json_obj, "deno.lint", v:false)
      let g:easycomplete_diagnostics_enable = 0
    endif
    return v:true
  endif
  return v:false
  " TODO 根据文件内容是否有 import http 来判断是否是 deno 文件
endfunction

function! s:HasNodeMudulesDir(package_file)
  if empty(a:package_file) | return v:false | endif
  let project_root = fnamemodify(a:package_file, ':p:h')
  if isdirectory(project_root . "/node_modules")
    return v:true
  else
    return v:false
  endif
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction

function! s:AsyncRun(...)
  return call('easycomplete#util#AsyncRun', a:000)
endfunction

function! s:StopAsyncRun(...)
  return call('easycomplete#util#StopAsyncRun', a:000)
endfunction
