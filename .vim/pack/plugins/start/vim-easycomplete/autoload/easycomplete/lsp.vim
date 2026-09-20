let s:enabled = 0
let s:fixendofline_exists = exists('+fixendofline')
let s:Stream = easycomplete#lsp#callbag#makeSubject()
let s:already_setup = 0
let s:servers = {} " { lsp_id, server_info, init_callbacks, init_result, buffers: { path: { changed_tick } }
let s:last_command_id = 0
let s:notification_callbacks = [] " { name, callback }
let s:undefined_token = '__callbag_undefined__'
let s:str_type = type('')
let s:diagnostics_state = {}
let b:easycomplete_lsp_plugin = {}
let b:lsp_job_id = 0

let s:default_symbol_kinds = {
      \ '1': 'file',
      \ '2': 'module',
      \ '3': 'namespace',
      \ '4': 'package',
      \ '5': 'class',
      \ '6': 'method',
      \ '7': 'property',
      \ '8': 'field',
      \ '9': 'constructor',
      \ '10': 'enum',
      \ '11': 'interface',
      \ '12': 'function',
      \ '13': 'variable',
      \ '14': 'constant',
      \ '15': 'string',
      \ '16': 'number',
      \ '17': 'boolean',
      \ '18': 'array',
      \ '19': 'object',
      \ '20': 'key',
      \ '21': 'null',
      \ '22': 'enum member',
      \ '23': 'struct',
      \ '24': 'event',
      \ '25': 'operator',
      \ '26': 'type parameter',
      \ }

let s:default_completion_item_kinds = {
      \ '1': 'text',
      \ '2': 'method',
      \ '3': 'function',
      \ '4': 'constructor',
      \ '5': 'field',
      \ '6': 'variable',
      \ '7': 'class',
      \ '8': 'interface',
      \ '9': 'module',
      \ '10': 'property',
      \ '11': 'unit',
      \ '12': 'value',
      \ '13': 'enum',
      \ '14': 'keyword',
      \ '15': 'snippet',
      \ '16': 'color',
      \ '17': 'file',
      \ '18': 'reference',
      \ '19': 'folder',
      \ '20': 'enum member',
      \ '21': 'constant',
      \ '22': 'struct',
      \ '23': 'event',
      \ '24': 'operator',
      \ '25': 'type parameter',
      \ }

" This hold previous content for each language servers to make
" DidChangeTextDocumentParams. The key is buffer numbers:
"    {
"      1: {
"        "golsp": [ "first-line", "next-line", ... ],
"        "bingo": [ "first-line", "next-line", ... ]
"      },
"      2: {
"        "pyls": [ "first-line", "next-line", ... ]
"      }
"    }
let s:file_content = {}

augroup lsp_silent
  " autocmd!
  " autocmd User lsp_setup silent
  " autocmd User lsp_register_server silent
  " autocmd User lsp_unregister_server silent
  " autocmd User lsp_server_init silent
  " autocmd User lsp_server_exit silent
  " autocmd User lsp_complete_done silent
  " autocmd User lsp_float_opened silent
  " autocmd User lsp_float_closed silent
  " autocmd User lsp_buffer_enabled silent
  " autocmd User lsp_diagnostics_updated silent
  " autocmd User lsp_progress_updated silent
augroup END

function! easycomplete#lsp#enable()
  call s:register_events()
  let b:easycomplete_lsp_plugin = easycomplete#util#GetLspPlugin()
endfunction

function! s:register_events() abort
  augroup lsp
    autocmd!
  augroup END

  augroup lsp
    autocmd!
    autocmd BufNewFile * call s:on_text_document_did_open()
    autocmd BufReadPost * call s:on_text_document_did_open()
    autocmd BufWritePost * call s:on_text_document_did_save()
    autocmd BufWinLeave * call s:on_text_document_did_close()
    autocmd BufUnload * call s:on_text_document_did_unload()
  augroup END
  for l:bufnr in range(1, bufnr('$'))
    if bufexists(l:bufnr) && bufloaded(l:bufnr)
      call s:on_text_document_did_open(l:bufnr)
    endif
  endfor
endfunction

function! s:on_text_document_did_unload()
  " #227 TODO jayli 继续验证多文件共享lsp server 还是独占 lsp server
  if g:easycomplete_shared_lsp_server
    return
  endif
  let l:buf = expand('<abuf>')
  let l:job = easycomplete#util#GetBufJob(l:buf)
  call s:errlog('[LOG]','s:on_text_document_did_unload()', l:buf)
  let plugin_name = easycomplete#util#GetLspPluginName(l:buf)
  call easycomplete#lsp#client#stop(l:job)
  call easycomplete#util#DeleteBufJob(l:buf)
endfunction

function! s:on_text_document_did_close() abort
  let l:buf = bufnr('%')
  if getbufvar(l:buf, '&buftype') ==# 'terminal' | return | endif
endfunction

function! s:on_text_document_did_save() abort
endfunction

function! s:on_text_document_did_open(...) abort
  let l:buf = a:0 > 0 ? a:1 : bufnr('%')
  if getbufvar(l:buf, '&buftype') ==# 'terminal' | return | endif
  if getcmdwintype() !=# '' | return | endif
  call s:errlog('[LOG]', 's:on_text_document_did_open()', l:buf, &filetype, getcwd(), easycomplete#lsp#utils#get_buffer_uri(l:buf))

  for l:server_name in easycomplete#lsp#get_allowed_servers(l:buf)
    call s:ensure_flush(l:buf, l:server_name, function('s:fire_lsp_buffer_enabled', [l:server_name, l:buf]))
  endfor
endfunction

function! easycomplete#lsp#ensure_flush_all()
  let l:buf = bufnr('%')
  if getbufvar(l:buf, '&buftype') ==# 'terminal' | return | endif
  if getcmdwintype() !=# '' | return | endif
  for l:server_name in easycomplete#lsp#get_allowed_servers(l:buf)
    call s:ensure_flush(l:buf, l:server_name, function('s:Noop'))
  endfor
endfunction

function! s:fire_lsp_buffer_enabled(server_name, buf, ...) abort
  if a:buf == bufnr('%')
    " doautocmd <nomodeline> User lsp_buffer_enabled
  else
    " Not using ++once in autocmd for compatibility of VIM8.0
    let l:cmd = printf('autocmd BufEnter <buffer=%d> doautocmd <nomodeline> User lsp_buffer_enabled', a:buf)
  endif
endfunction

function! easycomplete#lsp#register_server(server_info) abort
  let l:server_name = a:server_info['name']
  if has_key(s:servers, l:server_name)
    call s:errlog("[LOG]", 'lsp#register_server', 'server already registered', l:server_name)
    " #227 TODO jayli
    if g:easycomplete_shared_lsp_server
      return
    endif
  endif
  let s:servers[l:server_name] = {
        \ 'server_info': a:server_info,
        \ 'lsp_id': 0,
        \ 'buffers': {},
        \ }
  call s:errlog('[LOG]', 'easycomplete#lsp#register_server', 'server registered', l:server_name)
  " doautocmd <nomodeline> User lsp_register_server
endfunction

function! easycomplete#lsp#get_server_capabilities(server_name) abort
  let l:server = s:servers[a:server_name]
  return has_key(l:server, 'init_result') ? l:server['init_result']['result']['capabilities'] : {}
endfunction

" call easycomplete#lsp#get_allowed_servers()
" call easycomplete#lsp#get_allowed_servers(bufnr('%'))
" call easycomplete#lsp#get_allowed_servers('typescript')
function! easycomplete#lsp#get_allowed_servers(...) abort
  if a:0 == 0
    let l:buffer_filetype = &filetype
  else
    if type(a:1) == type('')
      let l:buffer_filetype = a:1
    else
      let l:buffer_filetype = getbufvar(a:1, '&filetype')
    endif
  endif

  " TODO: cache active servers per buffer
  let l:active_servers = []

  for l:server_name in keys(s:servers)
    let l:server_info = s:servers[l:server_name]['server_info']
    let l:blocked = 0

    if has_key(l:server_info, 'blocklist')
      let l:blocklistkey = 'blocklist'
    else
      let l:blocklistkey = 'blacklist'
    endif
    if has_key(l:server_info, l:blocklistkey)
      for l:filetype in l:server_info[l:blocklistkey]
        if l:filetype ==? l:buffer_filetype || l:filetype ==# '*'
          let l:blocked = 1
          break
        endif
      endfor
    endif

    if l:blocked
      continue
    endif

    if has_key(l:server_info, 'allowlist')
      let l:allowlistkey = 'allowlist'
    else
      let l:allowlistkey = 'whitelist'
    endif
    if has_key(l:server_info, l:allowlistkey)
      for l:filetype in l:server_info[l:allowlistkey]
        if l:filetype ==? l:buffer_filetype || l:filetype ==# '*'
          let l:active_servers += [l:server_name]
          break
        endif
      endfor
    endif
  endfor

  return l:active_servers
endfunction

function! s:Noop(...) abort
endfunction

function! easycomplete#lsp#send_request(server_name, request) abort
  let l:ctx = {
        \ 'server_name': a:server_name,
        \ 'request': copy(a:request),
        \ 'cb': has_key(a:request, 'on_notification') ? a:request['on_notification'] : function('s:Noop'),
        \ }

  let l:ctx['dispose'] = easycomplete#lsp#callbag#pipe(
        \ easycomplete#lsp#request(a:server_name, a:request),
        \ easycomplete#lsp#callbag#subscribe({
        \   'next':{d->l:ctx['cb'](d)},
        \   'error':{e->s:send_request_error(l:ctx, e)},
        \   'complete':{->s:send_request_dispose(l:ctx)},
        \ })
        \)
endfunction

" function! lsp#internal#diagnostics#state#_enable() abort
function! easycomplete#lsp#diagnostics_enable(opt) abort
  let Callback = a:opt.callback
  let s:Dispose = easycomplete#lsp#callbag#pipe(
        \ easycomplete#lsp#callbag#merge(
        \   easycomplete#lsp#callbag#pipe(
        \       easycomplete#lsp#stream(),
        \       easycomplete#lsp#callbag#filter({x->has_key(x, 'server') && has_key(x, 'response')
        \           && get(x['response'], 'method', '') ==# 'textDocument/publishDiagnostics'}),
        \       easycomplete#lsp#callbag#tap({x->Callback(x['server'], x['response'])}),
        \   ),
        \   easycomplete#lsp#callbag#pipe(
        \       easycomplete#lsp#stream(),
        \       easycomplete#lsp#callbag#filter({x->has_key(x, 'server') && has_key(x, 'response')
        \           && get(x['response'], 'method', '') ==# '$/vimlsp/lsp_server_exit' }),
        \       easycomplete#lsp#callbag#tap({x->s:on_exit(x['response'])}),
        \   ),
        \ ),
        \ easycomplete#lsp#callbag#subscribe(),
        \ )

  call s:notify_diagnostics_update()
endfunction

" 这个函数还有什么用
" call s:notify_diagnostics_update()
" call s:notify_diagnostics_update('server')
" call s:notify_diagnostics_update('server', 'uri')
function! s:notify_diagnostics_update(...) abort
  let l:data = { 'server': '$vimlsp', 'response': { 'method': '$/vimlsp/lsp_diagnostics_updated', 'params': {} } }
  " if a:0 > 0 | let l:data['response']['params']['server'] = a:1 | endif
  " if a:0 > 1 | let l:data['response']['params']['uri'] = a:2 | endif
  call easycomplete#lsp#stream(1, l:data)
  " doautocmd <nomodeline> User lsp_diagnostics_updated
endfunction

function! easycomplete#lsp#notify_diagnostics_update()
  call s:notify_diagnostics_update()
endfunction

function! easycomplete#lsp#has_signature_help_provider(server_name) abort
  let l:capabilities = easycomplete#lsp#get_server_capabilities(a:server_name)
  if !empty(l:capabilities) && has_key(l:capabilities, 'signatureHelpProvider')
    return 1
  endif
  return 0
endfunction

function! s:get_parameter_doc(parameter) abort
  if !has_key(a:parameter, 'documentation')
    return ''
  endif

  let l:doc = copy(a:parameter['documentation'])
  if type(l:doc) == type({})
    let l:doc['value'] = printf('***%s*** - %s', a:parameter['label'], l:doc['value'])
    return l:doc
  endif
  return printf('***%s*** - %s', a:parameter['label'], l:doc)
endfunction


function! easycomplete#lsp#get_text_document_identifier(...) abort
  let l:buf = a:0 > 0 ? a:1 : bufnr('%')
  return { 'uri': easycomplete#lsp#utils#get_buffer_uri(l:buf) }
endfunction

function! s:send_request_dispose(ctx) abort
  " dispose function may not have been created so check before calling
  if has_key(a:ctx, 'dispose')
    call a:ctx['dispose']()
  endif
endfunction

function! s:send_request_error(ctx, error) abort
  call a:ctx['cb'](a:error)
  call s:send_request_dispose(a:ctx)
endfunction

function! s:subscribeListener(data, source) abort
  call a:source(0, function('s:subscribeSourceCallback', [a:data]))
  return function('s:subscribeDispose', [a:data])
endfunction

function! s:subscribeDispose(data, ...) abort
  if has_key(a:data, 'talkback') | call a:data['talkback'](2, easycomplete#lsp#callbag#undefined()) | endif
endfunction

function! s:subscribeSourceCallback(data, t, d) abort
  if a:t == 0 | let a:data['talkback'] = a:d | endif
  if a:t == 1 && has_key(a:data, 'next') | call a:data['next'](a:d) | endif
  if a:t == 1 || a:t == 0 | call a:data['talkback'](1, easycomplete#lsp#callbag#undefined()) | endif
  if a:t == 2 && s:isUndefined(a:d) && has_key(a:data, 'complete') | call a:data['complete']() | endif
  if a:t == 2 && !s:isUndefined(a:d) && has_key(a:data, 'error') | call a:data['error'](a:d) | endif
endfunction

function! s:isUndefined(d) abort
  return type(a:d) == s:str_type && a:d ==# s:undefined_token
endfunction

function! easycomplete#lsp#request(server_name, request) abort
  let l:ctx = {
        \ 'server_name': a:server_name,
        \ 'request': copy(a:request),
        \ 'request_id': 0,
        \ 'done': 0,
        \ 'cancelled': 0,
        \ }
  return easycomplete#lsp#callbag#create(function('s:request_create', [l:ctx]))
endfunction

function! s:request_create(ctx, next, error, complete) abort
  let a:ctx['next'] = a:next
  let a:ctx['error'] = a:error
  let a:ctx['complete'] = a:complete
  let a:ctx['bufnr'] = get(a:ctx['request'], 'bufnr', bufnr('%'))
  let a:ctx['request']['on_notification'] = function('s:request_on_notification', [a:ctx])
  call easycomplete#lsp#utils#step#start([
        \ {s->s:ensure_flush(a:ctx['bufnr'], a:ctx['server_name'], s.callback)},
        \ {s->s:is_step_error(s) ? s:request_error(a:ctx, s.result[0]) : s:request_send(a:ctx) },
        \ ])
  return function('s:request_cancel', [a:ctx])
endfunction

function! s:request_cancel(ctx) abort
  if a:ctx['cancelled'] | return | endif
  let a:ctx['cancelled'] = 1
  if a:ctx['request_id'] <= 0 || a:ctx['done'] | return | endif " we have not made the request yet or request is complete, so nothing to cancel
  if easycomplete#lsp#get_server_status(a:ctx['server_name']) !=# 'running' | return | endif " if server is not running we cant send the request
  " send the actual cancel request
  let a:ctx['dispose'] = easycomplete#lsp#callbag#pipe(
          \ easycomplete#lsp#notification(a:ctx['server_name'], {
          \   'method': '$/cancelRequest',
          \   'params': { 'id': a:ctx['request_id'] },
          \ }),
          \ easycomplete#lsp#callbag#subscribe({
          \   'error':{e->s:send_request_dispose(a:ctx)},
          \   'complete':{->s:send_request_dispose(a:ctx)},
          \ })
          \)
endfunction

function! easycomplete#lsp#notification(server_name, request) abort
  return easycomplete#lsp#callbag#lazy(function('s:send_notification', [a:server_name, a:request]))
endfunction

" Returns the current status of all servers (if called with no arguments) or
" the given server (if given an argument). Can be one of "unknown server",
" "exited", "starting", "failed", "running", "not running"
function! easycomplete#lsp#get_server_status(...) abort
  if a:0 == 0
    let l:strs = map(keys(s:servers), {k, v -> v . ': ' . s:server_status(v)})
    return join(l:strs, "\n")
  else
    return s:server_status(a:1)
  endif
endfunction

function! s:request_send(ctx) abort
  if a:ctx['cancelled'] | return | endif " caller already unsubscribed so don't bother sending request
  let a:ctx['request_id'] = s:send_request(a:ctx['server_name'], a:ctx['request'])
endfunction

function! s:request_error(ctx, error) abort
  if a:ctx['cancelled'] | return | endif " caller already unsubscribed so don't bother notifying
  let a:ctx['done'] = 1
  call a:ctx['error'](a:error)
endfunction

function! s:is_step_error(s) abort
  return easycomplete#lsp#client#is_error(a:s.result[0]['response'])
endfunction

function! s:ensure_init(buf, server_name, cb) abort
  let l:server = s:servers[a:server_name]

  if has_key(l:server, 'init_result')
    let l:msg = s:new_rpc_success('lsp server already initialized', { 'server_name': a:server_name, 'init_result': l:server['init_result'] })
    " call s:errlog("[LOG]", l:msg)
    call a:cb(l:msg)
    return
  endif

  if has_key(l:server, 'init_callbacks')
    " waiting for initialize response
    call add(l:server['init_callbacks'], a:cb)
    let l:msg = s:new_rpc_success('waiting for lsp server to initialize', { 'server_name': a:server_name })
    " call s:errlog("[LOG]", l:msg)
    return
  endif

  " server has already started, but not initialized
  let l:server_info = l:server['server_info']
  if has_key(l:server_info, 'root_uri')
    let l:root_uri_type = type(l:server_info['root_uri'])
    if l:root_uri_type == v:t_list
      let l:root_uri_o = l:server_info['root_uri'][0]
    elseif l:root_uri_type == v:t_string
      let l:root_uri_o = l:server_info['root_uri']
    else
      let l:root_uri_o = l:server_info['root_uri'](l:server_info)
    endif
  else
    let l:root_uri_o = ""
  endif

  let l:root_uri = l:root_uri_o
  if empty(l:root_uri)
    let l:root_uri = easycomplete#lsp#utils#get_default_root_uri()
  endif
  let l:server['server_info']['_root_uri_resolved'] = l:root_uri

  if has_key(l:server_info, 'capabilities')
    let l:capabilities = l:server_info['capabilities']
  else
    let l:capabilities = call(function('easycomplete#lsp#default_get_supported_capabilities'), [l:server_info])
  endif
  if easycomplete#util#GetCurrentPluginName() == "go"
    call remove(l:capabilities["textDocument"], "typeHierarchy")
  endif

  let l:request = {
        \   'method': 'initialize',
        \   'params': {
        \     'processId': getpid(),
        \     'clientInfo': { 'name': 'vim-lsp' },
        \     'capabilities': l:capabilities,
        \     'rootUri': l:root_uri,
        \     'rootPath': easycomplete#lsp#utils#uri_to_path(l:root_uri),
        \     'trace': 'off',
        \   },
        \ }

  if has_key(l:server_info, 'initialization_options')
    let l:request.params['initializationOptions'] = l:server_info['initialization_options']
  endif

  let l:server['init_callbacks'] = [a:cb]
  call s:send_request(a:server_name, l:request)
endfunction

function! s:send_request(server_name, data) abort
  let l:lsp_id = s:servers[a:server_name]['lsp_id']
  let l:data = copy(a:data)
  if has_key(l:data, 'on_notification')
    let l:data['on_notification'] = '---funcref---'
  endif
  return easycomplete#lsp#client#send_request(l:lsp_id, a:data)
  " call s:errlog('[LOG]', 'lsp request --->', l:lsp_id, a:server_name, l:data)
endfunction

function! s:throw_step_error(s) abort
  call a:s.callback(a:s.result[0])
endfunction

function! s:ensure_flush(buf, server_name, cb) abort
  call easycomplete#lsp#utils#step#start([
        \ {s->s:ensure_start(a:buf, a:server_name, s.callback)},
        \ {s->s:is_step_error(s) ? s:throw_step_error(s) : s:ensure_init(a:buf, a:server_name, s.callback)},
        \ {s->s:is_step_error(s) ? s:throw_step_error(s) : s:ensure_conf(a:buf, a:server_name, s.callback)},
        \ {s->s:is_step_error(s) ? s:throw_step_error(s) : s:ensure_open(a:buf, a:server_name, s.callback)},
        \ {s->s:is_step_error(s) ? s:throw_step_error(s) : s:ensure_changed(a:buf, a:server_name, s.callback)},
        \ {s->a:cb(s.result[0])}
        \ ])
endfunction

function! s:ensure_changed(buf, server_name, cb) abort
  let l:server = s:servers[a:server_name]
  let l:path = easycomplete#lsp#utils#get_buffer_uri(a:buf)

  let l:buffers = l:server['buffers']
  if !has_key(l:buffers, l:path)
    let l:msg = s:new_rpc_success('file is not managed', { 'server_name': a:server_name, 'path': l:path })
    call s:errlog("[ERR]ensure_changed", l:msg)
    call a:cb(l:msg)
    return
  endif
  let l:buffer_info = l:buffers[l:path]

  let l:changed_tick = getbufvar(a:buf, 'changedtick')

  if l:buffer_info['changed_tick'] == l:changed_tick
    let l:msg = s:new_rpc_success('not dirty', { 'server_name': a:server_name, 'path': l:path })
    call s:errlog("[ERR]ensure_changed", l:msg)
    call a:cb(l:msg)
    return
  endif

  let l:buffer_info['changed_tick'] = l:changed_tick
  let l:buffer_info['version'] = l:buffer_info['version'] + 1

  call s:send_notification(a:server_name, {
        \ 'method': 'textDocument/didChange',
        \ 'params': {
        \   'textDocument': s:get_versioned_text_document_identifier(a:buf, l:buffer_info),
        \   'contentChanges': s:text_changes(a:buf, a:server_name),
        \ }
        \ })
  " call lsp#ui#vim#folding#send_request(a:server_name, a:buf, 0)
  call easycomplete#lsp#folding#send_request(a:server_name, a:buf, 0)

  let l:msg = s:new_rpc_success('textDocument/didChange sent', { 'server_name': a:server_name, 'path': l:path })
  " call s:errlog("[LOG]", l:msg)
  call a:cb(l:msg)
endfunction

function! s:get_text_document_change_sync_kind(server_name) abort
  let l:capabilities = easycomplete#lsp#get_server_capabilities(a:server_name)
  if !empty(l:capabilities) && has_key(l:capabilities, 'textDocumentSync')
    if type(l:capabilities['textDocumentSync']) == type({})
      if  has_key(l:capabilities['textDocumentSync'], 'change') && type(l:capabilities['textDocumentSync']['change']) == type(1)
        let l:val = l:capabilities['textDocumentSync']['change']
        return l:val >= 0 && l:val <= 2 ? l:val : 1
      else
        return 1
      endif
    elseif type(l:capabilities['textDocumentSync']) == type(1)
      return l:capabilities['textDocumentSync']
    else
      return 1
    endif
  endif
  return 1
endfunction

function! s:text_changes(buf, server_name) abort
  let l:sync_kind = s:get_text_document_change_sync_kind(a:server_name)

  " When syncKind is None, return null for contentChanges.
  if l:sync_kind == 0
    return v:null
  endif

  " When syncKind is Incremental and previous content is saved.
  if l:sync_kind == 2 && has_key(s:file_content, a:buf)
    " compute diff
    let l:old_content = s:get_last_file_content(a:buf, a:server_name)
    let l:new_content = s:get_lines(a:buf)
    let l:changes = s:diff_compute(l:old_content, l:new_content)
    if empty(l:changes.text) && l:changes.rangeLength ==# 0
      return []
    endif
    call s:update_file_content(a:buf, a:server_name, l:new_content)
    return [l:changes]
  endif

  let l:new_content = s:get_lines(a:buf)
  let l:changes = {'text': join(l:new_content, "\n")}
  call s:update_file_content(a:buf, a:server_name, l:new_content)
  return [l:changes]
endfunction

function! s:get_versioned_text_document_identifier(buf, buffer_info) abort
  return {
        \ 'uri': easycomplete#lsp#utils#get_buffer_uri(a:buf),
        \ 'version': a:buffer_info['version'],
        \ }
endfunction

function! s:get_fixendofline(buf) abort
  let l:eol = getbufvar(a:buf, '&endofline')
  let l:binary = getbufvar(a:buf, '&binary')

  if s:fixendofline_exists
    let l:fixeol = getbufvar(a:buf, '&fixendofline')

    if !l:binary
      " When 'binary' is off and 'fixeol' is on, 'endofline' is not used
      "
      " When 'binary' is off and 'fixeol' is off, 'endofline' is used to
      " remember the presence of a <EOL>
      return l:fixeol || l:eol
    else
      " When 'binary' is on, the value of 'fixeol' doesn't matter
      return l:eol
    endif
  else
    " When 'binary' is off the value of 'endofline' is not used
    "
    " When 'binary' is on 'endofline' is used to remember the presence of
    " a <EOL>
    return !l:binary || l:eol
  endif
endfunction

function! s:get_lines(buf) abort
  let l:lines = getbufline(a:buf, 1, '$')
  if s:get_fixendofline(a:buf)
    let l:lines += ['']
  endif
  return l:lines
endfunction

function! s:ensure_open(buf, server_name, cb) abort
  let l:server = s:servers[a:server_name]
  let l:path = easycomplete#lsp#utils#get_buffer_uri(a:buf)

  if empty(l:path)
    let l:msg = s:new_rpc_success('ignore open since not a valid uri', { 'server_name': a:server_name, 'path': l:path })
    " call s:errlog("[LOG]", l:msg)
    call a:cb(l:msg)
    return
  endif

  let l:buffers = l:server['buffers']

  if has_key(l:buffers, l:path)
    let l:msg = s:new_rpc_success('already opened', { 'server_name': a:server_name, 'path': l:path })
    " call s:errlog("[LOG]", l:msg)
    call a:cb(l:msg)
    return
  endif

  call s:update_file_content(a:buf, a:server_name, s:get_lines(a:buf))
  let l:buffer_info = { 'changed_tick': getbufvar(a:buf, 'changedtick'), 'version': 1, 'uri': l:path }
  let l:buffers[l:path] = l:buffer_info

  call s:send_notification(a:server_name, {
        \ 'method': 'textDocument/didOpen',
        \ 'params': {
        \   'textDocument': s:get_text_document(a:buf, a:server_name, l:buffer_info)
        \ },
        \ })

  call easycomplete#lsp#folding#send_request(a:server_name, a:buf, 0)

  let l:msg = s:new_rpc_success('textDocument/open sent', { 'server_name': a:server_name, 'path': l:path, 'filetype': getbufvar(a:buf, '&filetype') })
  " call s:errlog("[LOG]", l:msg)
  call a:cb(l:msg)
endfunction

function! s:update_file_content(buf, server_name, new) abort
  if !has_key(s:file_content, a:buf)
    let s:file_content[a:buf] = {}
  endif
  call s:errlog("[LOG]", 's:update_file_content()', a:buf)
  let s:file_content[a:buf][a:server_name] = a:new
endfunction

function! easycomplete#lsp#HasProvider(...)
  return call('s:has_provider', a:000)
endfunction

function! s:has_provider(server_name, ...) abort
  let l:value = easycomplete#lsp#get_server_capabilities(a:server_name)
  for l:provider in a:000
    if empty(l:value) || type(l:value) != type({}) || !has_key(l:value, l:provider)
      return 0
    endif
    let l:value = l:value[l:provider]
  endfor
  return (type(l:value) == type(v:true) && l:value == v:true) || type(l:value) == type({})
endfunction

function! s:folding_send_request(server_name, buf, sync) abort
  if !s:has_provider(a:server_name, 'foldingRangeProvider')
    return
  endif

  if has('textprop')
    call s:set_textprops(a:buf)
  endif

  call easycomplete#lsp#send_request(a:server_name, {
        \ 'method': 'textDocument/foldingRange',
        \ 'params': {
        \   'textDocument': easycomplete#lsp#get_text_document_identifier(a:buf)
        \ },
        \ 'on_notification': function('s:handle_fold_request', [a:server_name]),
        \ 'sync': a:sync,
        \ 'bufnr': a:buf
        \ })
endfunction

function! s:handle_fold_request(server, data) abort
  if easycomplete#lsp#client#is_error(a:data) || !has_key(a:data, 'response') || !has_key(a:data['response'], 'result')
    return
  endif

  let l:result = a:data['response']['result']

  if type(l:result) != type([])
    return
  endif

  let l:uri = a:data['request']['params']['textDocument']['uri']
  let l:path = easycomplete#lsp#utils#uri_to_path(l:uri)
  let l:bufnr = bufnr(l:path)

  if l:bufnr < 0
    return
  endif

  if !has_key(s:folding_ranges, a:server)
    let s:folding_ranges[a:server] = {}
  endif
  let s:folding_ranges[a:server][l:bufnr] = l:result

  " Set 'foldmethod' back to 'expr', which forces a re-evaluation of
  " 'foldexpr'. Only do this if the user hasn't changed 'foldmethod',
  " and this is the correct buffer.
  for l:winid in win_findbuf(l:bufnr)
    if getwinvar(l:winid, '&foldmethod') ==# 'expr'
      call setwinvar(l:winid, '&foldmethod', 'expr')
    endif
  endfor
endfunction

function! s:set_textprops(buf) abort
  " Use zero-width text properties to act as a sort of "mark" in the buffer.
  " This is used to remember the line numbers at the time the request was
  " sent. We will let Vim handle updating the line numbers when the user
  " inserts or deletes text.

  " Skip if the buffer doesn't exist. This might happen when a buffer is
  " opened and quickly deleted.
  if !bufloaded(a:buf) | return | endif

  " Create text property, if not already defined
  silent! call prop_type_add(s:textprop_name, {'bufnr': a:buf})
  let l:line_count = s:get_line_count_buf(a:buf)
  " First, clear all markers from the previous run
  call prop_remove({'type': s:textprop_name, 'bufnr': a:buf}, 1, l:line_count)

  " Add markers to each line
  let l:i = 1
  while l:i <= l:line_count
    call prop_add(l:i, 1, {'bufnr': a:buf, 'type': s:textprop_name, 'id': l:i})
    let l:i += 1
  endwhile
endfunction

function! s:get_line_count_buf(buf) abort
  if !has('patch-8.1.1967')
    return line('$')
  endif
  let l:winids = win_findbuf(a:buf)
  return empty(l:winids) ? line('$') : line('$', l:winids[0])
endfunction

function! s:get_text_document_text(buf, server_name) abort
  return join(s:get_last_file_content(a:buf, a:server_name), "\n")
endfunction

function! s:get_last_file_content(buf, server_name) abort
  if has_key(s:file_content, a:buf) && has_key(s:file_content[a:buf], a:server_name)
    return s:file_content[a:buf][a:server_name]
  endif
  return []
endfunction

function! s:get_text_document(buf, server_name, buffer_info) abort
  let l:server = s:servers[a:server_name]
  let l:server_info = l:server['server_info']
  let l:language_id = has_key(l:server_info, 'languageId') ?  l:server_info['languageId'](l:server_info) : &filetype
  return {
        \ 'uri': easycomplete#lsp#utils#get_buffer_uri(a:buf),
        \ 'languageId': l:language_id,
        \ 'version': a:buffer_info['version'],
        \ 'text': s:get_text_document_text(a:buf, a:server_name),
        \ }
endfunction

function! s:ensure_conf(buf, server_name, cb) abort
  let l:server = s:servers[a:server_name]
  let l:server_info = l:server['server_info']
  if has_key(l:server_info, 'workspace_config')
    let l:workspace_config = l:server_info['workspace_config']
    call s:send_notification(a:server_name, {
          \ 'method': 'workspace/didChangeConfiguration',
          \ 'params': {
          \   'settings': l:workspace_config,
          \ }
          \ })
  endif
  let l:msg = s:new_rpc_success('configuration sent', { 'server_name': a:server_name })
  call a:cb(l:msg)
endfunction

function! s:ensure_start(buf, server_name, cb) abort
  let l:path = easycomplete#lsp#utils#get_buffer_path(a:buf)

  if easycomplete#lsp#utils#is_remote_uri(l:path)
    let l:msg = s:new_rpc_error('ignoring start server due to remote uri', { 'server_name': a:server_name, 'uri': l:path})
    call s:errlog("[ERR]s:ensure_start", l:msg)
    call a:cb(l:msg)
    return
  endif

  let l:server = s:servers[a:server_name]
  let l:server_info = l:server['server_info']
  if l:server['lsp_id'] > 0
    let l:msg = s:new_rpc_success('server already started', { 'server_name': a:server_name })
    " call s:errlog("[LOG]", l:msg)
    call a:cb(l:msg)
    return
  endif

  if has_key(l:server_info, 'tcp')
    let l:tcp = l:server_info['tcp'](l:server_info)
    let l:lsp_id = easycomplete#lsp#client#start({
          \ 'tcp': l:tcp,
          \ 'on_stderr': function('s:on_stderr', [a:server_name]),
          \ 'on_exit': function('s:on_exit', [a:server_name]),
          \ 'on_notification': function('s:on_notification', [a:server_name]),
          \ 'on_request': function('s:on_request', [a:server_name]),
          \ })
  elseif has_key(l:server_info, 'cmd')
    let l:cmd_type = type(l:server_info['cmd'])
    if l:cmd_type == v:t_list
      let l:cmd = l:server_info['cmd']
    else
      let l:cmd = l:server_info['cmd'](l:server_info)
    endif

    if empty(l:cmd)
      let l:msg = s:new_rpc_error('ignore server start since cmd is empty', { 'server_name': a:server_name })
      call s:errlog("[ERR]ignore server start since cmd is empty", l:msg)
      call a:cb(l:msg)
      return
    endif
    call s:errlog("[LOG]", 'Starting server', a:server_name, l:cmd)
    " call s:console("0", l:server_info)
    let l:lsp_id = easycomplete#lsp#client#start({
          \ 'cmd': l:cmd,
          \ 'on_stderr': function('s:on_stderr', [a:server_name]),
          \ 'on_exit': function('s:on_exit', [a:server_name]),
          \ 'on_notification': function('s:on_notification', [a:server_name]),
          \ 'on_request': function('s:on_request', [a:server_name]),
          \ })
  endif

  if l:lsp_id > 0
    let l:server['lsp_id'] = l:lsp_id
    let b:lsp_job_id = l:lsp_id
    let l:msg = s:new_rpc_success('started lsp server successfully', { 'server_name': a:server_name, 'lsp_id': l:lsp_id })
    " call s:errlog("[LOG]", l:msg)
    call a:cb(l:msg)
  else
    let l:msg = s:new_rpc_error('failed to start server', { 'server_name': a:server_name, 'cmd': l:cmd })
    " call s:errlog("[LOG]", l:msg)
    let b:lsp_job_id = 0
    call a:cb(l:msg)
  endif
  " TODO Jayli
  " l:lsp_id 需要被记录到全局变量中，以便buf关闭时一起关闭
  " lsp server 跟 buf 是一一绑定的关系，跟window没关系
  " 关闭的时候需要考虑多个 window 绑定一个 bufnr 的情况，要判断一下是否还存在
  " 别的 bufnr 是当前 window的 buf
  call easycomplete#util#SetCurrentBufJob(l:lsp_id)
  " call s:console('add new job ' . fnamemodify(expand('%'), ':p'))
endfunction

function! s:on_request(server_name, id, request) abort
  let l:stream_data = { 'server': a:server_name, 'request': a:request }
  call easycomplete#lsp#stream(1, l:stream_data) " notify stream before callbacks

  if a:request['method'] ==# 'workspace/applyEdit'
    call s:workspace_edit_apply_workspace_edit(a:request['params']['edit'])
    call s:send_response(a:server_name, { 'id': a:request['id'], 'result': { 'applied': v:true } })
  elseif a:request['method'] ==# 'workspace/configuration'
    let l:response_items = map(a:request['params']['items'], { key, val -> s:workspace_config_get_value(a:server_name, val) })
    call s:send_response(a:server_name, { 'id': a:request['id'], 'result': l:response_items })
  elseif a:request['method'] ==# 'window/workDoneProgress/create'
    call s:send_response(a:server_name, { 'id': a:request['id'], 'result': v:null})
  else
    " TODO: for now comment this out until we figure out a better solution.
    " We need to comment this out so that others outside of vim-lsp can
    " hook into the stream and provide their own response.
    " " Error returned according to json-rpc specification.
    " call s:send_response(a:server_name, { 'id': a:request['id'], 'error': { 'code': -32601, 'message': 'Method not found' } })
  endif
endfunction

function! s:send_response(server_name, data) abort
  let l:lsp_id = s:servers[a:server_name]['lsp_id']
  let l:data = copy(a:data)
  " call s:errlog("[LOG]", 'sendrequest --->', l:lsp_id, a:server_name, l:data)
  call easycomplete#lsp#client#send_response(l:lsp_id, a:data)
endfunction

function! s:workspace_edit_apply_workspace_edit(workspace_edit) abort
  let l:loclist_items = []

  if has_key(a:workspace_edit, 'documentChanges')
    for l:text_document_edit in a:workspace_edit['documentChanges']
      let l:loclist_items += s:_apply(l:text_document_edit['textDocument']['uri'], l:text_document_edit['edits'])
    endfor
  elseif has_key(a:workspace_edit, 'changes')
    for [l:uri, l:text_edits] in items(a:workspace_edit['changes'])
      let l:loclist_items += s:_apply(l:uri, l:text_edits)
    endfor
  endif
endfunction

"
" _apply
"
function! s:_apply(uri, text_edits) abort
  call easycomplete#lsp#utils#text_edit#apply_text_edits(a:uri, a:text_edits)
  return easycomplete#lsp#utils#text_edit#_lsp_to_vim_list(a:uri, a:text_edits)
endfunction

function! easycomplete#lsp#get_position(...) abort
  let l:line = line('.')
  let l:char = easycomplete#lsp#utils#to_char('%', l:line, col('.'))
  return { 'line': l:line - 1, 'character': l:char }
endfunction

function! s:workspace_config_get_value(server_name, item) abort
  try
    let l:server_info = easycomplete#lsp#get_server_info(a:server_name)
    let l:config = l:server_info['workspace_config']

    for l:section in split(a:item['section'], '\.')
      let l:config = l:config[l:section]
    endfor

    return l:config
  catch
    return v:null
  endtry
endfunction

function! easycomplete#lsp#get_server_info(server_name) abort
  return s:servers[a:server_name]['server_info']
endfunction

function! s:on_notification(server_name, id, data, event) abort
  " echom '>>>> on_notification ' . string(a:data)
  " call s:errlog("[LOG]", 'lsp response <---', a:id, a:server_name)
  let l:response = a:data['response']
  let l:server = s:servers[a:server_name]
  let l:server_info = l:server['server_info']

  let l:stream_data = { 'server': a:server_name, 'response': l:response }
  if has_key(a:data, 'request')
    let l:stream_data['request'] = a:data['request']
  endif
  call easycomplete#lsp#stream(1, l:stream_data) " notify stream before callbacks

  if easycomplete#lsp#client#is_server_instantiated_notification(a:data)
    if has_key(l:response, 'method')
      if l:response['method'] ==# 'textDocument/semanticHighlighting'
        " call lsp#ui#vim#semantic#handle_semantic(a:server_name, a:data)
      endif
    endif
  else
    let l:request = a:data['request']
    let l:method = l:request['method']
    if l:method ==# 'initialize'
      call s:handle_initialize(a:server_name, a:data)
    endif
  endif

  for l:callback_info in s:notification_callbacks
    call l:callback_info.callback(a:server_name, a:data)
  endfor
endfunction

function! s:handle_initialize(server_name, data) abort
  let l:response = a:data['response']
  let l:server = s:servers[a:server_name]

  if has_key(l:server, 'exited')
    unlet l:server['exited']
  endif

  let l:init_callbacks = l:server['init_callbacks']
  unlet l:server['init_callbacks']

  if !easycomplete#lsp#client#is_error(l:response)
    let l:server['init_result'] = l:response
    " Delete cache of trigger chars
    if has_key(b:, 'lsp_signature_help_trigger_character')
      unlet b:lsp_signature_help_trigger_character
    endif
  else
    let l:server['failed'] = l:response['error']
    call easycomplete#lsp#utils#error('Failed to initialize ' . a:server_name .
          \ ' with error ' . l:response['error']['code'] . ': ' . l:response['error']['message'])
  endif
  call s:send_notification(a:server_name, { 'method': 'initialized', 'params': {} })
  for l:Init_callback in l:init_callbacks
    call l:Init_callback(a:data)
  endfor
  " doautocmd <nomodeline> User lsp_server_init
endfunction

function! s:send_notification(server_name, data) abort
  let l:lsp_id = s:servers[a:server_name]['lsp_id']
  let l:data = copy(a:data)
  if has_key(l:data, 'on_notification')
    let l:data['on_notification'] = '---funcref---'
  endif
  " call s:errlog("[LOG]", 'notification --->', l:lsp_id, a:server_name)
  call easycomplete#lsp#client#send_notification(l:lsp_id, a:data)
endfunction

function! s:on_stderr(server_name, id, data, event) abort
  " call s:errlog("[ERR]", 'notification <---(stderr)', a:id, a:server_name, a:data)
endfunction

function! s:on_exit(...) abort
  let server_name = string(a:1)
  let id = exists('a:2') ? a:2 : v:null
  let data = exists('a:3') ? a:3 : v:null
  let event = exists('a:4') ? a:4 : v:null
  " call s:console('exit', a:000)
  if has_key(s:servers, server_name)
    let l:server = s:servers[server_name]
    let l:server['lsp_id'] = 0
    let l:server['buffers'] = {}
    let l:server['exited'] = 1
    if has_key(l:server, 'init_result')
      unlet l:server['init_result']
    endif
    call easycomplete#lsp#stream(1, { 'server': '$vimlsp',
          \ 'response': { 'method': '$/vimlsp/lsp_server_exit', 'params': { 'server': server_name } } })
    " doautocmd <nomodeline> User lsp_server_exit
  endif
endfunction

function! easycomplete#lsp#stream(...) abort
  if a:0 == 0
    return easycomplete#lsp#callbag#share(s:Stream)
  else
    call s:Stream(a:1, a:2)
  endif
endfunction

function! s:shareFactory(data, start, sink) abort
  if a:start != 0 | return | endif
  call add(a:data['sinks'], a:sink)
  let a:data['talkback'] = function('s:shareTalkbackCallback', [a:data, a:sink])
  if len(a:data['sinks']) == 1
    call a:data['source'](0, function('s:shareSourceCallback', [a:data, a:sink]))
    return
  endif
  call a:sink(0, a:data['talkback'])
endfunction

function! s:shareSourceCallback(data, sink, t, d) abort
  if a:t == 0
    let a:data['sourceTalkback'] = a:d
    call a:sink(0, a:data['talkback'])
  else
    for l:S in a:data['sinks']
      call l:S(a:t, a:d)
    endfor
  endif
  if a:t == 2
    let a:data['sinks'] = []
  endif
endfunction

function! s:shareTalkbackCallback(data, sink, t, d) abort
  if a:t == 2
    let l:i = 0
    let l:found = 0
    while l:i < len(a:data['sinks'])
      if a:data['sinks'][l:i] == a:sink
        let l:found = 1
        break
      endif
      let l:i += 1
    endwhile

    if l:found
      call remove(a:data['sinks'], l:i)
    endif

    if empty(a:data['sinks'])
      call a:data['sourceTalkback'](2, easycomplete#lsp#callbag#undefined())
    endif
  else
    call a:data['sourceTalkback'](a:t, a:d)
  endif
endfunction

function! s:new_rpc_success(message, data) abort
  return {
        \ 'response': {
        \     'message': a:message,
        \     'data': extend({ '__data__': 'vim-lsp'}, a:data),
        \   }
        \ }
endfunction

function! s:new_rpc_error(message, data) abort
  return {
        \ 'response': {
        \     'error': {
        \       'code': 0,
        \       'message': a:message,
        \       'data': extend({ '__error__': 'vim-lsp'}, a:data),
        \     },
        \   }
        \ }
endfunction

function! s:request_on_notification(ctx, id, data, event) abort
  if a:ctx['cancelled'] | return | endif " caller already unsubscribed so don't bother notifying
  let a:ctx['done'] = 1
  call a:ctx['next'](extend({ 'server_name': a:ctx['server_name'] }, a:data))
  call a:ctx['complete']()
endfunction

function! easycomplete#lsp#default_get_supported_capabilities(server_info) abort
  " Sorted alphabetically
  return {
        \   'textDocument': {
        \       'callHierarchy': {
        \           'dynamicRegistration': v:false,
        \       },
        \       'codeAction': {
        \         'dynamicRegistration': v:false,
        \         'codeActionLiteralSupport': {
        \           'codeActionKind': {
        \             'valueSet': ['', 'quickfix', 'refactor', 'refactor.extract', 'refactor.inline', 'refactor.rewrite', 'source', 'source.organizeImports'],
        \           }
        \         },
        \         'isPreferredSupport': v:true,
        \         'disabledSupport': v:true,
        \       },
        \       'codeLens': {
        \           'dynamicRegistration': v:false,
        \       },
        \       'completion': {
        \           'dynamicRegistration': v:false,
        \           'completionItem': {
        \              'documentationFormat': ['markdown', 'plaintext'],
        \              'snippetSupport': v:false,
        \              'resolveSupport': {
        \                  'properties': ['additionalTextEdits','documentation','detail']
        \              }
        \           },
        \           'completionItemKind': {
        \              'valueSet': s:get_completion_item_kinds()
        \           }
        \       },
        \       'declaration': {
        \           'dynamicRegistration': v:false,
        \           'linkSupport' : v:true
        \       },
        \       'definition': {
        \           'dynamicRegistration': v:false,
        \           'linkSupport' : v:true
        \       },
        \       'documentHighlight': {
        \           'dynamicRegistration': v:false,
        \       },
        \       'documentSymbol': {
        \           'dynamicRegistration': v:false,
        \           'symbolKind': {
        \              'valueSet': s:get_symbol_kinds()
        \           },
        \           'hierarchicalDocumentSymbolSupport': v:false,
        \           'labelSupport': v:false
        \       },
        \       'foldingRange': {
        \           'dynamicRegistration': v:false,
        \           'lineFoldingOnly': v:true,
        \           'rangeLimit': 5000,
        \       },
        \       'formatting': {
        \           'dynamicRegistration': v:false,
        \       },
        \       'hover': {
        \           'dynamicRegistration': v:false,
        \           'contentFormat': ['markdown', 'plaintext'],
        \       },
        \       'inlayHint': {
        \           'dynamicRegistration': v:false,
        \       },
        \       'implementation': {
        \           'dynamicRegistration': v:false,
        \           'linkSupport' : v:true
        \       },
        \       'publishDiagnostics': {
        \           'relatedInformation': v:true,
        \       },
        \       'rangeFormatting': {
        \           'dynamicRegistration': v:false,
        \       },
        \       'references': {
        \           'dynamicRegistration': v:false,
        \       },
        \       'rename': {
        \           'dynamicRegistration': v:false,
        \           'prepareSupport': v:true,
        \           'prepareSupportDefaultBehavior': 1
        \       },
        \       'semanticTokens': {
        \           'dynamicRegistration': v:false,
        \           'requests': {
        \               'range': v:false,
        \               'full':  v:false
        \           },
        \           'tokenTypes': [
        \               'type', 'class', 'enum', 'interface', 'struct',
        \               'typeParameter', 'parameter', 'variable', 'property',
        \               'enumMember', 'event', 'function', 'method', 'macro',
        \               'keyword', 'modifier', 'comment', 'string', 'number',
        \               'regexp', 'operator'
        \           ],
        \           'tokenModifiers': [],
        \           'formats': ['relative'],
        \           'overlappingTokenSupport': v:false,
        \           'multilineTokenSupport': v:false,
        \           'serverCancelSupport': v:false
        \       },
        \       'signatureHelp': {
        \           'dynamicRegistration': v:false,
        \       },
        \       'synchronization': {
        \           'didSave': v:true,
        \           'dynamicRegistration': v:false,
        \           'willSave': v:false,
        \           'willSaveWaitUntil': v:false,
        \       },
        \       'typeDefinition': {
        \           'dynamicRegistration': v:false,
        \           'linkSupport' : v:true
        \       },
        \       'typeHierarchy': {
        \           'dynamicRegistration': v:false
        \       },
        \   },
        \   'window': {
        \       'workDoneProgress':  v:false,
        \   },
        \   'workspace': {
        \       'applyEdit': v:true,
        \       'configuration': v:true,
        \       'symbol': {
        \           'dynamicRegistration': v:false,
        \       },
        \       'workspaceFolders':  v:false,
        \   },
        \ }
endfunction

function! s:get_completion_item_kinds() abort
  return map(keys(s:default_completion_item_kinds), {idx, key -> str2nr(key)})
endfunction

function! s:get_symbol_kinds() abort
  return map(keys(s:default_symbol_kinds), {idx, key -> str2nr(key)})
endfunction

function! s:diff_compute(old, new) abort
  let [l:start_line, l:start_char] = s:FirstDifference(a:old, a:new)
  let [l:end_line, l:end_char] =
        \ s:LastDifference(a:old[l:start_line :], a:new[l:start_line :], l:start_char)

  let l:text = s:ExtractText(a:new, l:start_line, l:start_char, l:end_line, l:end_char)
  let l:length = s:Length(a:old, l:start_line, l:start_char, l:end_line, l:end_char)

  let l:adj_end_line = len(a:old) + l:end_line
  let l:adj_end_char = l:end_line == 0 ? 0 : strchars(a:old[l:end_line]) + l:end_char + 1

  let l:result = { 'range': {'start': {'line': l:start_line, 'character': l:start_char},
        \ 'end': {'line': l:adj_end_line, 'character': l:adj_end_char}},
        \ 'text': l:text,
        \ 'rangeLength': l:length,
        \}

  return l:result
endfunction

" Finds the line and character of the first different character between two
" list of Strings.
function! s:FirstDifference(old, new) abort
  let l:line_count = min([len(a:old), len(a:new)])
  if l:line_count == 0 | return [0, 0] | endif
  for l:i in range(l:line_count)
    if a:old[l:i] !=# a:new[l:i] | break | endif
  endfor
  if l:i >= l:line_count
    return [l:line_count - 1, strchars(a:old[l:line_count - 1])]
  endif
  let l:old_line = a:old[l:i]
  let l:new_line = a:new[l:i]
  let l:length = min([strchars(l:old_line), strchars(l:new_line)])
  let l:j = 0
  while l:j < l:length
    if strgetchar(l:old_line, l:j) != strgetchar(l:new_line, l:j) | break | endif
    let l:j += 1
  endwhile
  return [l:i, l:j]
endfunction

function! s:LastDifference(old, new, start_char) abort
  let l:line_count = min([len(a:old), len(a:new)])
  if l:line_count == 0 | return [0, 0] | endif
  for l:i in range(-1, -1 * l:line_count, -1)
    if a:old[l:i] !=# a:new[l:i] | break | endif
  endfor
  if l:i <= -1 * l:line_count
    let l:i = -1 * l:line_count
    let l:old_line = strcharpart(a:old[l:i], a:start_char)
    let l:new_line = strcharpart(a:new[l:i], a:start_char)
  else
    let l:old_line = a:old[l:i]
    let l:new_line = a:new[l:i]
  endif
  let l:old_line_length = strchars(l:old_line)
  let l:new_line_length = strchars(l:new_line)
  let l:length = min([l:old_line_length, l:new_line_length])
  let l:j = -1
  while l:j >= -1 * l:length
    if  strgetchar(l:old_line, l:old_line_length + l:j) !=
          \ strgetchar(l:new_line, l:new_line_length + l:j)
      break
    endif
    let l:j -= 1
  endwhile
  return [l:i, l:j]
endfunction

function! s:ExtractText(lines, start_line, start_char, end_line, end_char) abort
  if a:start_line == len(a:lines) + a:end_line
    if a:end_line == 0 | return '' | endif
    let l:line = a:lines[a:start_line]
    let l:length = strchars(l:line) + a:end_char - a:start_char + 1
    return strcharpart(l:line, a:start_char, l:length)
  endif
  let l:result = strcharpart(a:lines[a:start_line], a:start_char) . "\n"
  for l:line in a:lines[a:start_line + 1:a:end_line - 1]
    let l:result .= l:line . "\n"
  endfor
  if a:end_line != 0
    let l:line = a:lines[a:end_line]
    let l:length = strchars(l:line) + a:end_char + 1
    let l:result .= strcharpart(l:line, 0, l:length)
  endif
  return l:result
endfunction

function! s:Length(lines, start_line, start_char, end_line, end_char) abort
  let l:adj_end_line = len(a:lines) + a:end_line
  if l:adj_end_line >= len(a:lines)
    let l:adj_end_char = a:end_char - 1
  else
    let l:adj_end_char = strchars(a:lines[l:adj_end_line]) + a:end_char
  endif
  if a:start_line == l:adj_end_line
    return l:adj_end_char - a:start_char + 1
  endif
  let l:result = strchars(a:lines[a:start_line]) - a:start_char + 1
  let l:line = a:start_line + 1
  while l:line < l:adj_end_line
    let l:result += strchars(a:lines[l:line]) + 1
    let l:line += 1
  endwhile
  let l:result += l:adj_end_char + 1
  return l:result
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction

function! s:errlog(...)
  return call('easycomplete#util#errlog', a:000)
endfunction

function! s:log(...)
  return
endfunction

