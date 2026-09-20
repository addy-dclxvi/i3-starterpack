
let s:server_name = ""
let s:changes = v:null

function! easycomplete#action#rename#do()
  if easycomplete#popup#visiable()
    call easycomplete#popup#close()
    call timer_start(90, { -> s:do() })
  else
    call s:do()
  endif
endfunction

function! s:do()
  let l:request_params = { 'context': { 'includeDeclaration': v:false } }
  let l:server_names = easycomplete#util#FindLspServers()['server_names']
  if empty(l:server_names)
    call s:DoTSRename()
    return
  endif
  let l:server_name = l:server_names[0]
  if !easycomplete#lsp#HasProvider(l:server_name, 'renameProvider')
    call s:log('[LSP References]: renameProvider is not supported')
    call s:errlog("[ERR]", '[LSP References]: renameProvider is not supported')
    return
  endif

  let s:server_name = l:server_name
  call easycomplete#input#pop("", function("s:InputCallback"))
endfunction

function! s:InputCallback(old_text, new_text)
  call easycomplete#lsp#send_request(s:server_name, {
        \   'method': 'textDocument/rename',
        \   'params': {
        \     'textDocument': easycomplete#lsp#get_text_document_identifier(),
        \     'position': easycomplete#lsp#get_position(),
        \     'newName' : a:new_text,
        \   },
        \   'on_notification': function('s:HandleLspCallback', [s:server_name]),
        \   })
endfunction

function! s:DoTSRename()
  call easycomplete#input#pop("", function("easycomplete#sources#ts#rename"))
endfunction

function! s:HandleLspCallback(server_name, data)
  let changes = s:get(a:data, "response", "result", "changes")
  if empty(changes)
    call s:log("Nothing to be changed")
    call s:errlog("[LOG]", "[rename], Nothing to be changed")
    return
  endif

  let s:changes = changes
  if s:HasExternalFiles(changes)
    call easycomplete#confirm#pop("Do you want to modify external files which are not in vim buffers?",
          \ function("s:ConfirmCallback"))
  else
    call s:ConfirmCallback(v:null, 0)
  endif
endfunction

function! s:ConfirmCallback(error, res)
  if !empty(a:error)
    call s:log(a:error)
    return
  endif
  if empty(s:changes)
    return
  endif
  let changes = s:changes
  let modify_ext_files = a:res == 1 ? v:true : v:false
  let changed_count = 0
  call setqflist([], 'r')
  for filename in changes->keys()
    let file_edits = s:get(changes, filename)
    let fullfname = easycomplete#util#TrimFileName(filename)
    for item in file_edits
      let lnum = s:get(item, "range", "start", "line") + 1
      let col_start = s:get(item, "range", "start", "character") + 1
      let col_end = s:get(item, "range", "end", "character")
      let new_text = s:get(item, "newText")
      let success_status = easycomplete#util#TextEdit(fullfname, lnum, col_start, col_end, new_text, modify_ext_files)
      if success_status !=# 0
        let changed_count += 1
        let bufnr = bufnr(bufname(fullfname))
        call setqflist([{
          \  'filename': fullfname,
          \  'lnum':     lnum,
          \  'col':      col_start,
          \  'text':     getbufline(bufnr, lnum, lnum)[0],
          \  'valid':    0,
          \ }], "a")
      endif
    endfor
  endfor
  if len(getqflist()) > 0
    call easycomplete#util#info("Changed", changed_count, "locations!","Use `:wa` to save all changes,",
          \ "`:cclose` or `:CleanLog` to close changelist, `:copen` to open changelist")
    call timer_start(50, { -> easycomplete#util#SideOpenQFWindow()})
  else
    call easycomplete#util#info("[LS] Changed", changed_count, "locations!")
  endif
  call s:flush()
endfunction

function! s:HasExternalFiles(changes)
  let changes = a:changes
  let flag = v:false
  let buflist = easycomplete#util#GetBufListWithFileName()
  for filename in changes->keys()
    let file_edits = s:get(changes, filename)
    let fullfname = easycomplete#util#TrimFileName(filename)
    if index(buflist, fullfname) < 0
      let flag = v:true
      break
    endif
  endfor
  return flag
endfunction

function! s:flush()
  call easycomplete#action#rename#flush()
endfunction

function! easycomplete#action#rename#flush()
  let s:changes = v:null
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! s:get(...)
  return call('easycomplete#util#get', a:000)
endfunction

function! s:errlog(...)
  return call('easycomplete#util#errlog', a:000)
endfunction
