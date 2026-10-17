" Chained completion that works as I want!
" Maintainer: Lifepillar <lifepillar@lifepillar.me>
" License: MIT

let s:save_cpo = &cpo
set cpo&vim

fun! mucomplete#auto#enable()
  let s:v_char_expr = get(b:, 'mucomplete_empty_text_auto', get(g:, 'mucomplete#empty_text_auto', 0))
        \                 ? '\m\p'
        \                 : '\m\S'
  if get(g:, 'mucomplete#completion_delay', 0) > 1 && has('timers')
    call mucomplete#timer#enable()
  else
    augroup MUcompleteAuto
      autocmd!
      autocmd InsertCharPre * noautocmd call mucomplete#auto#insertcharpre()
      if get(g:, 'mucomplete#completion_delay', 0)
        autocmd TextChangedI * noautocmd call mucomplete#auto#ic_auto_complete()
        autocmd  CursorHoldI * noautocmd call mucomplete#auto#auto_complete()
      else
        autocmd TextChangedI * noautocmd call mucomplete#auto#auto_complete()
      endif
    augroup END
  endif
endf

fun! mucomplete#auto#disable()
  if exists('#MUcompleteAuto')
    autocmd! MUcompleteAuto
    augroup! MUcompleteAuto
  endif
  unlet! s:v_char_expr
endf

fun! mucomplete#auto#toggle()
  if exists('#MUcompleteAuto')
    call mucomplete#auto#disable()
    echomsg '[MUcomplete] Auto off'
  else
    call mucomplete#auto#enable()
    echomsg '[MUcomplete] Auto on'
  endif
endf

if has('patch-8.0.0283')
  let s:insertcharpre = 0

  fun! mucomplete#auto#insertcharpre()
    let s:insertcharpre = !pumvisible() && (v:char =~# s:v_char_expr)
  endf

  fun! mucomplete#auto#ic_auto_complete()
    " In Insert completion mode, CursorHoldI in not invoked.
    " With delay on, wait for timer to expire (if using timers).
    if mode(1) ==# 'ic' && get(g:, 'mucomplete#reopen_immediately', 1)
      call mucomplete#auto_complete()
    endif
  endf

  fun! mucomplete#auto#auto_complete()
    if s:insertcharpre || mode(1) ==# 'ic'
      let s:insertcharpre = 0
      call mucomplete#auto_complete()
    endif
  endf

  let &cpo = s:save_cpo
  unlet s:save_cpo

  finish
endif

" Code for Vim 8.0.0282 and older
if !(get(g:, 'mucomplete#no_popup_mappings', 0) || get(g:, 'mucomplete#no_mappings', 0) || get(g:, 'no_plugin_maps', 0))
  if !hasmapto('<plug>(MUcompletePopupCancel)', 'i')
    call mucomplete#map('imap', '<c-e>', '<plug>(MUcompletePopupCancel)')
  endif
  if !hasmapto('<plug>(MUcompletePopupAccept)', 'i')
    call mucomplete#map('imap', '<c-y>', '<plug>(MUcompletePopupAccept)')
  endif
  if !hasmapto('<plug>(MUcompleteCR)', 'i')
    call mucomplete#map('imap', '<cr>', '<plug>(MUcompleteCR)')
  endif
endif

let s:cancel_auto = 0
let s:insertcharpre = 0

fun! mucomplete#auto#popup_exit(keys)
  let s:cancel_auto = pumvisible()
  return a:keys
endf

fun! mucomplete#auto#insertcharpre()
  let s:insertcharpre = (v:char =~# '\m\S')
endf

fun! mucomplete#auto#ic_auto_complete()
  if s:cancel_auto
    let s:cancel_auto = 0
    return
  endif
  if !s:insertcharpre
    call mucomplete#auto_complete()
  endif
endf

fun! mucomplete#auto#auto_complete()
  if s:cancel_auto
    let [s:cancel_auto, s:insertcharpre] = [0,0]
    return
  endif
  if s:insertcharpre
    let s:insertcharpre = 0
    call mucomplete#auto_complete()
  endif
endf

let &cpo = s:save_cpo
unlet s:save_cpo

