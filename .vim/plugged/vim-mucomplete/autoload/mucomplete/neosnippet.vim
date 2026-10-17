" Chained completion that works as I want!
" Maintainer: Lifepillar <lifepillar@lifepillar.me>
" License: MIT

let s:save_cpo = &cpo
set cpo&vim

fun! mucomplete#neosnippet#complete() abort
  let l:snippets = filter(neosnippet#helpers#get_snippets(),
       \ "!get(v:val.options, 'oneshot', 0)")
  if empty(l:snippets)
    return ''
  endif
  let l:pat = matchstr(getline('.'), '\S\+\%'.col('.').'c')
  let l:candidates = map(filter(keys(l:snippets), 'stridx(v:val, l:pat) == 0'),
        \  '{
        \      "word": l:snippets[v:val]["word"],
        \      "menu": "[neosnippet] ". get(l:snippets[v:val], "menu_abbr", ""),
        \      "dup" : 1
        \   }')
  if !empty(l:candidates)
    call complete(col('.') - len(l:pat), l:candidates)
  endif
  return ''
endf


" Automatic expansion of snippets

fun! mucomplete#neosnippet#do_expand(keys)
  if get(v:completed_item, 'menu', '') =~# '[neosnippet]'
    return neosnippet#expand(v:completed_item['word'])
  endif
  return a:keys
endf

fun! mucomplete#neosnippet#expand_snippet(keys)
  return pumvisible()
        \ ? "\<c-y>\<c-r>=mucomplete#neosnippet#do_expand('')\<cr>"
        \ : a:keys
endf

let &cpo = s:save_cpo
unlet s:save_cpo

