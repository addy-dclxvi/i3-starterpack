
function! easycomplete#action#defination#do()
  call s:DefinationCalling()
endfunction

" LSP 的 GoToDefinition
function! easycomplete#action#defination#LspRequest() abort
  " typeDefinition => type definition
  let l:method = "definition"
  let l:operation = substitute(l:method, '\u', ' \l\0', 'g')
  let l:servers = easycomplete#util#FindLspServers()['server_names']
  if empty(l:servers)
    return v:false
  endif
  let l:server = easycomplete#util#FindLspServers()['server_names'][0]
  let l:plugin_name = easycomplete#GetPluginNameByLspName(l:server)
  if empty(easycomplete#installer#GetCommand(l:plugin_name))
    return v:false
  endif
  let l:ctx = { 'counter': len(l:server), 'list':[], 'jump_if_one': 1, 'mods': '', 'in_preview': 0 }

  let l:params = {
        \   'textDocument': easycomplete#lsp#get_text_document_identifier(),
        \   'position': easycomplete#lsp#get_position(),
        \ }
  call easycomplete#lsp#send_request(l:server, {
        \ 'method': 'textDocument/' . l:method,
        \ 'params': l:params,
        \ 'on_notification': function('s:HandleLspCallback', [l:ctx, l:server, l:operation]),
        \ })

  echo printf('Retrieving %s ...', l:operation)
  return v:true
endfunction

" 这里 ctx 的格式保留下来
" ctx = {counter, list, last_command_id, jump_if_one, mods, in_preview}
function! s:HandleLspCallback(ctx, server, type, data) abort
  if easycomplete#lsp#client#is_error(a:data['response']) || !has_key(a:data['response'], 'result')
    call s:log('Failed to retrieve '. a:type . ' for ' . a:server .
          \ ': ' . easycomplete#lsp#client#error_message(a:data['response']))
  else
    let a:ctx['list'] = a:ctx['list'] + easycomplete#lsp#utils#location#_lsp_to_vim_list(
          \   a:data['response']['result']
          \ )
  endif

  if empty(a:ctx['list'])
    call easycomplete#lsp#utils#error('No ' . a:type .' found')
  else
    call easycomplete#util#UpdateTagStack()
    let l:loc = a:ctx['list'][0]
    if len(a:ctx['list']) == 1 && a:ctx['jump_if_one'] && !a:ctx['in_preview']
      call easycomplete#lsp#utils#location#_open_vim_list_item(l:loc, a:ctx['mods'])
      echo 'Retrieved ' . a:type
      redraw
    elseif !a:ctx['in_preview']
      call setqflist([])
      call setqflist(a:ctx['list'])
      echo 'Retrieved ' . a:type
      botright copen
    else
      " do nothing
    endif
  endif
endfunction

function! s:DefinationCalling()
  if &filetype == "help"
    exec "tag ". expand('<cword>')
    return
  endif
  let l:ctx = easycomplete#context()
  let syntax_going = v:false
  let sources = easycomplete#GetAllPlugins()
  for item in keys(sources)
    if easycomplete#CompleteSourceReady(item)
      if has_key(get(sources, item), "gotodefinition")
        let syntax_going = s:GotoDefinitionByName(item, l:ctx)
        break
      endif
    endif
  endfor
  if syntax_going == v:false
    try
      exec "tag ". expand('<cword>')
    catch
      echom v:exception
    endtry
  endif
endfunction

function! s:GotoDefinitionByName(name, ctx)
  let sources = easycomplete#GetAllPlugins()
  let l:opt = get(sources, a:name)
  let b:gotodefinition = get(l:opt, "gotodefinition")
  if empty(b:gotodefinition)
    return v:false
  endif
  if type(b:gotodefinition) == 2 " type is function
    return b:gotodefinition(l:opt, a:ctx)
  endif
  if type(b:gotodefinition) == type("string") " type is string
    return call(b:gotodefinition, [l:opt, a:ctx])
  endif
  return v:false
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction
