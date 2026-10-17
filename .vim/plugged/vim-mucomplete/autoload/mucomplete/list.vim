" Chained completion that works as I want!
" Maintainer: Lifepillar <lifepillar@lifepillar.me>
" License: MIT

let s:save_cpo = &cpo
set cpo&vim

if exists('*matchstrpos')
  fun! s:getword()
    return matchstrpos(getline('.'), '\S\+\%'.col('.').'c')
  endf
else
  fun! s:getword()
    return [matchstr(getline('.'), '\S\+\%'.col('.').'c'), match(getline('.'), '\S\+\%'.col('.').'c'), 0]
  endf
endif

fun! mucomplete#list#complete() abort
  let [l:word, l:col, l:_] = s:getword()
  let l:suggestions = mucomplete#list#completefunc(0, l:word)
  if !empty(l:suggestions)
    call complete(1 + l:col, l:suggestions)
  endif
  return ''
endf

fun! s:wordlist()
  return get(b:, 'mucomplete_wordlist',
        \    get(get(g:, 'mucomplete#wordlist', {}), getbufvar("%","&ft"),
        \        get(get(g:, 'mucomplete#wordlist', {}), 'default', [])))
endf

fun! mucomplete#list#completefunc(findstart, base)
  if a:findstart
    return match(getline('.'), '\S\+\%'.col('.').'c')
  else
    let l:res = []
    let l:len = len(s:wordlist())
    let l:lft = 0
    let l:rgt = l:len
    while l:lft < l:rgt  " Find the leftmost index matching base
      let l:i = (l:lft + l:rgt) / 2
      if s:wordlist()[l:i] < a:base
        let l:lft = l:i + 1
      else
        let l:rgt = l:i
      endif
    endwhile
    while l:lft < l:len && s:wordlist()[l:lft] =~ '^' . a:base
      call add(l:res, s:wordlist()[l:lft])
      let l:lft += 1
    endwhile
    return l:res
  endif
endfun

let &cpo = s:save_cpo
unlet s:save_cpo

