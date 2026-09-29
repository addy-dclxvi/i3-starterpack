function! easycomplete#action#hover#do()
  call s:do()
endfunction

function! easycomplete#action#hover#close()
  call easycomplete#popup#close("signature")
endfunction

function! s:do()
  let all_plugins = easycomplete#GetAllPlugins()
  if has_key(all_plugins, "ts") && easycomplete#sources#deno#IsTSOrJSFiletype() &&
        \ !easycomplete#sources#deno#IsDenoProject()
    let ts = get(all_plugins, "ts", {})
    let ts_filetypes = ts["whitelist"]
    if index(ts_filetypes, &filetype) >= 0
      call easycomplete#sources#ts#hover()
      return
    endif
  endif

  let l:servers = easycomplete#lsp#get_allowed_servers()
  if empty(l:servers) | return | endif
  let l:server = l:servers[0]
  let has_provider = easycomplete#lsp#HasProvider(l:server, "hoverProvider")
  if has_provider == 0
    if s:Has_Shift_K_Map()
      exec "h ". expand('<cword>')
    endif
    return
  endif

  let l:position = easycomplete#lsp#get_position()
  call easycomplete#lsp#send_request(l:server, {
        \ 'method': 'textDocument/hover',
        \ 'params': {
        \   'textDocument': easycomplete#lsp#get_text_document_identifier(),
        \   'position': l:position,
        \ },
        \ 'on_notification': function('s:HandleLspCallback', [l:server]),
        \ })
endfunction

function! s:Has_Shift_K_Map()
  let maps = execute('map <s-k>')
  if maps =~ "EasyCompleteHover"
    return v:true
  else
    return v:false
  endif
endfunction

function! s:HandleLspCallback(server, data) abort
  try
    if easycomplete#lsp#client#is_error(a:data['response'])
      call easycomplete#lsp#utils#error('Failed ' . a:server)
      call s:flush()
      if s:Has_Shift_K_Map()
        exec "h ". expand('<cword>')
      endif
      return
    endif

    if !has_key(a:data['response'], 'result')
      call s:flush()
      if s:Has_Shift_K_Map()
        exec "h ". expand('<cword>')
      endif
      return
    endif

    let local_msg = s:get(a:data,"response","result","contents","value")
    if empty(local_msg)
      call s:log("No hover informations!")
      if s:Has_Shift_K_Map()
        exec "h ". expand('<cword>')
      endif
      return
    endif
    let content = substitute(local_msg, "```\\w\\+", "", "g")
    let content = substitute(content, "```", "", "g")
    let content = split(content, "\\n")
    let content = s:RemoveTrailingEmptyStrings(content)
    if !empty(content)
      call easycomplete#popup#float(content, 'Pmenu', 0, "", [0, 0], 'signature')
    elseif s:Has_Shift_K_Map()
      exec "h ". expand('<cword>')
    endif
    return
  catch
    call easycomplete#HoverNothing(v:exception)
  endtry
endfunction

function! s:RemoveTrailingEmptyStrings(list)
  return easycomplete#util#RemoveTrailingEmptyStrings(a:list)
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
