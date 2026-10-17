" Chained completion that works as I want!
" Maintainer: Lifepillar <lifepillar@lifepillar.me>
" License: MIT

" Source this script to start profiling MUcomplete
let s:testdir = fnamemodify(resolve(expand('<sfile>:p')), ':h')
let s:mudir = fnamemodify(s:testdir, ':h')
execute 'lcd' s:testdir

fun! s:term_sendkeys(buf, what)
  call term_sendkeys(a:buf, a:what)
  call term_wait(a:buf)
  redraw
endf

fun! s:prepare_buffer(buf, commands)
  call s:term_sendkeys(a:buf, ":enew!\r") " Edit a new buffer
  for l:cmd in a:commands                 " Execute setup commands
    call s:term_sendkeys(a:buf, ":".l:cmd."\r")
  endfor
  call s:term_sendkeys(a:buf, "i")        " Enter Insert mode
endf

fun! s:type(buf, text, wpm)
  let l:d = string(60000 / (5 * a:wpm))
  let l:M = len(a:text)
  let l:i = 0
  while l:i < l:M
    let l:j = 0
    let l:N = len(a:text[l:i])
    while l:j < l:N
      call s:term_sendkeys(a:buf, a:text[l:i][l:j])
      execute "sleep" l:d."m"
      let l:j += 1
    endwhile
    call s:term_sendkeys(a:buf, "\r")
    let l:i += 1
  endwhile
  call s:term_sendkeys(a:buf, "\<c-[>")   " End in Normal mode
endf

" Launch a Vim instance
let s:termbuf = term_start([v:progpath,
      \ "-u", s:mudir."/troubleshooting_vimrc.vim",
      \ "--cmd", "profile start mucomplete-".strftime("%Y%m%d-%H%M").".profile",
      \ "--cmd", "profile! file */autoload/mucomplete.vim",
      \ "-c", "MUcompleteAutoOn",
      \ "-c", 'inoremap <expr> <cr> pumvisible() ? "<c-y><cr>" : "<cr>"',
      \ "-c", "set noshowmode shortmess+=c"], {
      \     "curwin": 0,
      \     "hidden": 0,
      \     "stoponexit": "kill",
      \     "term_name": "MUcomplete profiling",
      \     "term_cols": 80,
      \     "term_kill": "kill"
      \   }
      \ )
call term_wait(s:termbuf, 1000)
redraw!

" Test 0 - Warm up!
let s:text = ["jump jump jump jump!"]
call s:prepare_buffer(s:termbuf, [])
call s:type(s:termbuf, s:text, 60)

" Test 1
let s:text = readfile(s:mudir."/plugin/mucomplete.vim")
call map(s:text, { i,v -> substitute(v, '^\s*', '', '') })  " Remove leading space (for correct indentation)
call s:prepare_buffer(s:termbuf, ["set ft=vim", "setl nospell et formatoptions="])
call s:type(s:termbuf, s:text, 200)

" Test 2
let s:text = readfile(s:mudir."/Readme.md")
call s:prepare_buffer(s:termbuf, ["set ft=text", "setl spell spelllang=en"])
call s:type(s:termbuf, s:text, 400)

" Quit Vim
call s:term_sendkeys(s:termbuf, "ZQ")

