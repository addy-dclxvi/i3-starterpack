" Chained completion that works as I want!
" Maintainer: Lifepillar <lifepillar@lifepillar.me>
" License: MIT

let s:save_cpo = &cpo
set cpo&vim

if exists('*matchstrpos')
  fun! s:getword()
    return matchstrpos(getline('.'), g:mucomplete#spel#regex.'\+\%'.col('.').'c')
  endf
else
  fun! s:getword()
    return [matchstr(getline('.'), g:mucomplete#spel#regex.'\+\%'.col('.').'c'), match(getline('.'), g:mucomplete#spel#regex.'\+\%'.col('.').'c'), 0]
  endf
endif

fun! mucomplete#spel#complete() abort
  let [l:word, l:col, l:_] = s:getword()
  let l:suggestions = spellsuggest(
        \               get(g:, 'mucomplete#spel#good_words', 0)
        \               ? l:word
        \               : spellbadword(l:word)[0]
        \               , get(g:, 'mucomplete#spel#max', 25))
  if !empty(l:suggestions)
    call complete(1 + l:col, l:suggestions)
  endif
  return ''
endf

let &cpo = s:save_cpo
unlet s:save_cpo

