" Chained completion that works as I want!
" Maintainer: Lifepillar <lifepillar@lifepillar.me>
" License: MIT

let s:save_cpo = &cpo
set cpo&vim

fun! s:show_current_method(abbr)
  unsilent echo '[MUcomplete]'
        \ get(a:abbr ? g:mucomplete#msg#short_methods : g:mucomplete#msg#methods,
        \     get(g:, 'mucomplete_current_method', ''), 'Custom method')
  let g:mucomplete_current_method = ''
  " Force placing the cursor back into the buffer
  " Without this, the cursor may get stuck in the command line after the
  " message is printed until another character is typed.
  " Note: this works only if the status line is visible!
  let &ro=&ro
endf

fun! s:notify_at_level(n)
  augroup MUcompleteNotifications
    autocmd!
    if a:n == 1
      autocmd User MUcompletePmenu call s:show_current_method(1)
      autocmd CompleteDone * echo "\r"
    elseif a:n == 2
      autocmd User MUcompletePmenu call s:show_current_method(0)
      autocmd CompleteDone * echo "\r"
    else " Status line
      autocmd User MUcompletePmenu let &ro=&ro
      autocmd CompleteDone * let g:mucomplete_current_method = '' | let &ro=&ro
    endif
  augroup END
endf

fun! s:shut_off_notifications()
  if exists('#MUcompleteNotifications')
    autocmd! MUcompleteNotifications
    augroup! MUcompleteNotifications
  endif
endf

fun! mucomplete#msg#set_notifications(n)
  if a:n > 0 && a:n < 4
    call s:notify_at_level(a:n)
  else
    call s:shut_off_notifications()
  endif
endf

let g:mucomplete#msg#methods = extend({
      \ "c-n" : "Keywords in 'complete' (search forwards)",
      \ "c-p" : "Keywords in 'complete' (search backwards)",
      \ "cmd" : "Vim commands",
      \ "defs": "Definitions or macros",
      \ "dict": "Keywords in 'dictionary'",
      \ "file": "File completion",
      \ "incl": "Keywords in the current and included files",
      \ "keyn": "Keywords in the current file (search forwards)",
      \ "keyp": "Keywords in the current file (search backwards)",
      \ "line": "Whole lines",
      \ "list": "Custom list of words",
      \ "nsnp": "Neosnippet snippets",
      \ "omni": "Omni completion ('omnifunc')",
      \ "path": "Path completion",
      \ "snip": "SnipMate snippets",
      \ "spel": "Spelling suggestions",
      \ "tags": "Tags completion",
      \ "thes": "Keywords in 'thesaurus'",
      \ "user": "User defined completion ('completefunc')",
      \ "ulti": "Ultisnips snippets",
      \ "uspl": "Improved spelling suggestions",
      \ }, get(g:, 'mucomplete#msg#methods', {}))

let g:mucomplete#msg#short_methods = extend({
      \ "c-n" : "keywords",
      \ "c-p" : "keywords",
      \ "cmd" : "vim",
      \ "defs": "definitions",
      \ "dict": "dictionary",
      \ "file": "files",
      \ "incl": "included files",
      \ "keyn": "buffer keywords",
      \ "keyp": "buffer keywords",
      \ "line": "whole lines",
      \ "list": "word list",
      \ "nsnp": "neosnippet",
      \ "omni": "omnifunc",
      \ "path": "paths",
      \ "snip": "snipmate",
      \ "spel": "spelling",
      \ "tags": "tags",
      \ "thes": "thesaurus",
      \ "user": "completefunc",
      \ "ulti": "ultisnips",
      \ "uspl": "spelling",
      \ }, get(g:, 'mucomplete#msg#short_methods', {}))

let &cpo = s:save_cpo
unlet s:save_cpo

