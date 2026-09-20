let s:folding_ranges = {}
let s:textprop_name = 'vim-lsp-folding-linenr'

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

function! easycomplete#lsp#folding#send_request(server_name, buf, sync) abort
  " if !easycomplete#lsp#capabilities#has_folding_range_provider(a:server_name)
  "     return
  " endif
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

function! s:errlog(...)
  return call('easycomplete#util#errlog', a:000)
endfunction
