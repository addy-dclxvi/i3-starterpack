
function! easycomplete#action#signature#do()
  call s:do()
endfunction

function! s:do()
  call easycomplete#action#signature#LspRequest()
  let all_plugins = easycomplete#GetAllPlugins()
  if has_key(all_plugins, "ts") && easycomplete#sources#deno#IsTSOrJSFiletype() &&
        \ !easycomplete#sources#deno#IsDenoProject()
    let ts = get(all_plugins, "ts", {})
    let ts_filetypes = ts["whitelist"]
    if index(ts_filetypes, &filetype) >= 0
      call easycomplete#sources#ts#signature()
    endif
  endif
endfunction

function! s:close()
  call easycomplete#popup#close("float")
endfunction

function! easycomplete#action#signature#LazyRunHandle()
  if !exists("b:signature_timer")
    let b:signature_timer = 0
  endif
  if b:signature_timer > 0
    call timer_stop(b:signature_timer)
    let b:signature_timer = 0
  endif
  let b:signature_timer = timer_start(100, { -> easycomplete#action#signature#handle() })
endfunction

function! easycomplete#action#signature#handle()
  let typed = s:GetTyped()
  if easycomplete#IsBacking()
    if easycomplete#action#signature#FireCondition()
      call s:do()
    else
      call s:close()
    endif
  else
    if trim(getline(".")) == ""
      call s:close()
    endif
    if typed =~ ")$"
      call s:close()
    elseif easycomplete#action#signature#FireCondition()
      call s:do()
    endif
    " call s:close()
  endif
  let b:signature_timer = 0
endfunction

function! easycomplete#action#signature#FireCondition()
  let l:typed = s:GetTyped()
  return l:typed =~ "\\w($" || (l:typed =~ "\\w(.*,$" && getline(".") =~ "(")
endfunction

function! s:GetTyped()
  let ctx = easycomplete#context()
  let linenr = 10
  if line(".") == 1
    let typed = trim(ctx["typed"])
  else
    let start_line_nr = line(".") - linenr <= 0 ? 0 : line(".") - linenr
    let lines = getline(start_line_nr, line(".") - 1)
    let prelines = trim(join(lines, " "))
    let typed = prelines . " " . trim(ctx["typed"])
  endif
  return typed
endfunction

function! easycomplete#action#signature#LspRequest() abort
  let l:servers = filter(easycomplete#lsp#get_allowed_servers(),
        \ 'easycomplete#lsp#has_signature_help_provider(v:val)')
  if len(l:servers) == 0
    return
  endif

  let l:position = easycomplete#lsp#get_position()
  for l:server in l:servers
    call easycomplete#lsp#send_request(l:server, {
          \ 'method': 'textDocument/signatureHelp',
          \ 'params': {
          \   'textDocument': easycomplete#lsp#get_text_document_identifier(),
          \   'position': l:position,
          \ },
          \ 'on_notification': function('s:HandleLspCallback', [l:server]),
          \ })
  endfor
  return
endfunction

function! s:HandleLspCallback(server, data) abort
  try
    if easycomplete#lsp#client#is_error(a:data['response'])
      call easycomplete#lsp#utils#error('Failed ' . a:server)
      call s:flush()
      return
    endif

    if !has_key(a:data['response'], 'result')
      call s:flush()
      return
    endif

    if !empty(a:data['response']['result']) && !empty(a:data['response']['result']['signatures'])
      " Get current signature.
      let l:signatures = get(a:data['response']['result'], 'signatures', [])
      let l:signature_index = get(a:data['response']['result'], 'activeSignature', 0)
      let l:signature = get(l:signatures, l:signature_index, {})
      if empty(l:signature)
        call s:flush()
        return
      endif

      " Signature label.
      let l:label = l:signature['label']
      " Mark current parameter.
      if has_key(a:data['response']['result'], 'activeParameter')
        let l:parameters = get(l:signature, 'parameters', [])
        let l:parameter_index = a:data['response']['result']['activeParameter']
        let l:parameter = get(l:parameters, l:parameter_index, {})
        let l:parameter_label = s:GetParameterLabel(l:signature, l:parameter)
        if !empty(l:parameter_label)
          let l:label = substitute(l:label, '\V\(' . escape(l:parameter_label, '\/?') . '\)', '`\1`', 'g')
        endif
      endif

      " 参数label
      let l:param = ""
      if exists('l:parameter')
        let l:parameter_doc = s:GetParameterLabel(l:signature,l:parameter)
        if !empty(l:parameter_doc)
          let l:param = l:parameter_doc
        endif
      endif

      " doc 正文
      let l:full_doc = {}
      if has_key(l:signature, 'documentation')
        let l:full_doc = get(l:signature, 'documentation', "")
      else
        if !exists('l:parameter')
          let l:parameter = {}
        endif
        let l:full_doc = get(l:parameter, "documentation", {})
      endif

      " l:param 一般是参数类型，似乎不用显示
      let l:param = ""
      call s:SignatureCallback(l:label, l:param, l:full_doc)
      return
    else
      " 无 signature 返回
    endif
  catch
    call s:log(v:exception)
  endtry
endfunction

function! easycomplete#action#signature#FireFloat(title,param,doc)
  call s:SignatureCallback(a:title, a:param, a:doc)
endfunction

function! s:SignatureCallback(title, param, doc)
  let title = a:title
  let param = a:param
  if type(a:doc) == type("")
    let content = a:doc
  else
    let content = empty(a:doc) ? "" : get(a:doc, "value", "")
  endif
  let content = substitute(content, "```\\w\\+", "", "g")
  let content = substitute(content, "```", "", "g")
  let content = split(content, "\\n")
  let offset = stridx(title, "`")
  if offset == -1
    let offset = stridx(title, "(")
  endif
  " signature 原来是 1 向上，我觉得有点干扰，改成了向下 0
  if g:easycomplete_signature_offset == 0
    let offset = 0
  endif
  call easycomplete#popup#float([title . param, '----'] + content,
                             \ 'Pmenu', 0, "", [0, 0 - offset], 'signature')
endfunction

function! easycomplete#action#signature#visible()
  return easycomplete#popup#SignatureVisible()
endfunction

function! s:GetParameterLabel(signature, parameter) abort
  if has_key(a:parameter, 'label')
    if type(a:parameter['label']) == type([])
      let l:string_range = a:parameter['label']
      return strcharpart(
            \ a:signature['label'],
            \ l:string_range[0],
            \ l:string_range[1] - l:string_range[0])
    endif
    return a:parameter['label']
  endif
  return ''
endfunction

function! s:flush()
  call easycomplete#popup#close("float")
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction
