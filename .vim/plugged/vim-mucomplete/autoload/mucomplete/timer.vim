" Chained completion that works as I want!
" Maintainer: Lifepillar <lifepillar@lifepillar.me>
" License: MIT

let s:save_cpo = &cpo
set cpo&vim

if !has('timers')
  fun! mucomplete#timer#stop()
  endf
  let &cpo = s:save_cpo
  unlet s:save_cpo
  finish
endif

fun! mucomplete#timer#enable()
  augroup MUcompleteAuto
    autocmd!
    autocmd InsertCharPre * noautocmd call mucomplete#timer#restart()
    autocmd TextChangedI  * noautocmd call mucomplete#auto#ic_auto_complete()
    autocmd InsertLeave   * noautocmd call mucomplete#timer#stop()
  augroup END
endf

fun! mucomplete#timer#restart()
  call mucomplete#auto#insertcharpre()
  if exists('s:completion_timer')
    call timer_stop(s:completion_timer)
  endif
  let s:completion_timer = timer_start(get(g:, 'mucomplete#completion_delay', 150), 'mucomplete#timer#complete')
endf

fun! mucomplete#timer#stop()
  if exists('s:completion_timer')
    call timer_stop(s:completion_timer)
    unlet s:completion_timer
  endif
endf

fun! mucomplete#timer#complete(tid)
  unlet s:completion_timer
  if !pumvisible()
    call mucomplete#auto#auto_complete()
  endif
endf

let &cpo = s:save_cpo
unlet s:save_cpo

