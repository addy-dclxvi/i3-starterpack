let s:zig_default_cmp_kws = []

function! easycomplete#sources#zig#constructor(opt, ctx)
  call easycomplete#RegisterLspServer(a:opt, {
      \ 'name': 'zls',
      \ 'cmd': [easycomplete#installer#GetCommand(a:opt['name']), '--config-path',
      \         easycomplete#installer#LspServerDir() . '/zig/zls.json'],
      \ 'allowlist': a:opt['whitelist'],
      \ 'root_uri':{server_info->easycomplete#util#GetDefaultRootUri()},
      \ })
endfunction

function! easycomplete#sources#zig#completor(opt, ctx) abort
  return easycomplete#DoLspComplete(a:opt, a:ctx)
endfunction

" zig 默认情况下，顶格敲第一个字符时返回为空，原因未知
" 每次zls返回的都是全量数据，这里缓存补救一下，首次有返回值时
" 立即缓存起来
function! easycomplete#sources#zig#filter(items, ctx)
  let l:items = []
  if empty(s:zig_default_cmp_kws)
    let s:zig_default_cmp_kws = deepcopy(a:items)
  endif
  if len(a:ctx['typing']) == 1 && a:ctx["col"] == 2
    " 顶格敲第一个字符
    if empty(a:items)
      let l:items = s:zig_default_cmp_kws
    else
      let l:items = a:items
    endif
  else " 其他情况直接返回lsp的结果
    let l:items = a:items
  endif
  return l:items
endfunction

function! easycomplete#sources#zig#GotoDefinition(...)
  return easycomplete#DoLspDefinition(["zig","zon"])
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction
