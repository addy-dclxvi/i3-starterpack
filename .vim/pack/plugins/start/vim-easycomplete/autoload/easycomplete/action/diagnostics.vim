" diagnostics

let s:response_ready = 0

function! easycomplete#action#diagnostics#do()
  " 确保从这里 fire 的 diagnostic 才会被更新渲染
  if easycomplete#util#GetLspPluginName() == "ts"
    call easycomplete#sources#ts#lint()
    return
  endif
  if !easycomplete#util#LspServerReady() | return | endif
  call easycomplete#lsp#notify_diagnostics_update()
  let s:response_ready = 0
  call easycomplete#lsp#ensure_flush_all()
  call easycomplete#util#timer_start('easycomplete#action#diagnostics#render',
        \ [], g:easycomplete_diagnostics_render_delay)
endfunction

function! easycomplete#action#diagnostics#HandleCallback(server, response)
  if getbufinfo(bufnr())[0].changed == 1
    call easycomplete#sign#flush()
  endif
  call easycomplete#sign#cache(a:response)
  let s:response_ready = 1
endfunction

function! easycomplete#action#diagnostics#render()
  if s:response_ready == 1
    call easycomplete#sign#render()
  else
    call timer_start(1000, { -> easycomplete#sign#render() })
  endif
endfunction

function! s:AsyncRun(...)
  return call('easycomplete#util#AsyncRun', a:000)
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction
