" Chained completion that works as I want!
" Maintainer: Lifepillar <lifepillar@lifepillar.me>
" License: MIT

let s:save_cpo = &cpo
set cpo&vim

let s:pathsep = exists('+shellslash') && !&shellslash
      \ ? (get(g:, 'mucomplete#use_only_windows_paths', 0) ? '[\\]' : '[/\\]')
      \ : '[/]'

fun! mucomplete#compat#yes_you_can(t)
  return 1
endf

fun! mucomplete#compat#default(t)
  return a:t =~# '\m\k\{'.get(g:, 'mucomplete#minimum_prefix_length', 2).'\}$' ||
        \ (g:mucomplete_with_key && (get(b:, 'mucomplete_empty_text', get(g:, 'mucomplete#empty_text', 0)) || a:t =~# '\m\k$'))
endf

fun! mucomplete#compat#dict(t)
  return strlen(&dictionary) > 0 && (a:t =~# '\m\a\a$' || (g:mucomplete_with_key && a:t =~# '\m\a$'))
endf

fun! mucomplete#compat#file(t)
  return a:t =~# '\m\%(\%(\f\&[^/\\]\)'.s:pathsep.'\|\%(^\|\s\|\f\|["'']\)'.s:pathsep.'\%(\f\&[^/\\]\)\+\)$'
        \     || (g:mucomplete_with_key && a:t =~# '\m\%(\~\|\%(^\|\s\|\f\|["'']\)'.s:pathsep.'\)\f*$')
endf

fun! mucomplete#compat#omni(t)
  return strlen(&l:omnifunc) > 0 && mucomplete#compat#default(a:t)
endf

fun! mucomplete#compat#spel(t)
  return &l:spell && !empty(&l:spelllang) && a:t =~# '\m'.g:mucomplete#spel#regex.'\{3}$'
endf

fun! mucomplete#compat#tags(t)
  return !empty(tagfiles()) && mucomplete#compat#default(a:t)
endf

fun! mucomplete#compat#thes(t)
  return strlen(&thesaurus) > 0 && a:t =~# '\m\a\a\a$'
endf

fun! mucomplete#compat#user(t)
  return strlen(&l:completefunc) > 0 && mucomplete#compat#default(a:t)
endf

fun! mucomplete#compat#list(t)
  return a:t =~# '\m\S\{'.get(g:, 'mucomplete#minimum_prefix_length', 2).'\}$' ||
        \ (g:mucomplete_with_key && (s:complete_empty_text || t =~# '\m\S$'))
endf

fun! mucomplete#compat#path(t)
  return a:t =~# '\m\%(\%(\f\&[^/\\]\)'.s:pathsep.'\|\%(^\|\s\|\f\|["'']\)'.s:pathsep.'\%(\f\&[^/\\]\|\s\)\+\)$'
        \     || (g:mucomplete_with_key && a:t =~# '\m\%(\~\|\%(^\|\s\|\f\|["'']\)'.s:pathsep.'\)\%(\f\|\s\)*$')
endf

fun! mucomplete#compat#nsnp(t)
  return get(g:, 'loaded_neosnippet', 0) && mucomplete#compat#default(a:t)
endf

fun! mucomplete#compat#snip(t)
  return get(g:, 'loaded_snips', 0) && mucomplete#compat#default(a:t)
endf

fun! mucomplete#compat#ulti(t)
  return get(g:, 'did_plugin_ultisnips', 0) && mucomplete#compat#default(a:t)
endf

fun! mucomplete#compat#omni_c(t)
  return strlen(&l:omnifunc) > 0 && a:t =~# '\m\%(\k\{'.get(g:, 'mucomplete#minimum_prefix_length', 2).'\}\|\S->\|\S\.\)$'
        \ || (g:mucomplete_with_key && (s:complete_empty_text || a:t =~# '\m\%(\k\|\S->\|\S\.\)$'))
endf

fun! mucomplete#compat#omni_python(t)
  return a:t =~# '\m\%(\k\{'.get(g:, 'mucomplete#minimum_prefix_length', 2).'\}\|\k\.\)$'
        \ || (g:mucomplete_with_key && (get(b:, 'mucomplete_empty_text', get(g:, 'mucomplete#empty_text', 0)) || a:t =~# '\m\%(\k\|\.\)$'))
endf

fun! mucomplete#compat#omni_xml(t)
  return strlen(&l:omnifunc) > 0 && a:t =~# '\m\%(\k\{'.get(g:, 'mucomplete#minimum_prefix_length', 2).'\}\|</\)$'
        \ || (g:mucomplete_with_key && (s:complete_empty_text || a:t =~# '\m\%(\k\|</\)$'))
endf

if get(g:, 'mucomplete#force_manual', 0)
  fun! s:fm(f)
    fun! s:foo(t)
      return g:mucomplete_with_key && a:f(a:t)
    endf
    return funcref('s:foo')
  endf
else
  fun! s:fm(f)
    return a:f
  endf
endif

fun! mucomplete#compat#can_complete()
  let l:cc = get(g:, 'mucomplete#can_complete', {}) " Get user's settings, then merge them with defaults
  let l:can_complete = extend({
        \ 'default' : extend({
        \     'c-n' :  s:fm(function('mucomplete#compat#default')),
        \     'c-p' :  s:fm(function('mucomplete#compat#default')),
        \     'cmd' :  s:fm(function('mucomplete#compat#default')),
        \     'defs':  s:fm(function('mucomplete#compat#default')),
        \     'dict':  s:fm(function('mucomplete#compat#dict')),
        \     'file':  s:fm(function('mucomplete#compat#file')),
        \     'incl':  s:fm(function('mucomplete#compat#default')),
        \     'keyn':  s:fm(function('mucomplete#compat#default')),
        \     'keyp':  s:fm(function('mucomplete#compat#default')),
        \     'line':  s:fm(function('mucomplete#compat#default')),
        \     'list':  s:fm(function('mucomplete#compat#list')),
        \     'omni':  s:fm(function('mucomplete#compat#omni')),
        \     'spel':  s:fm(function('mucomplete#compat#spel')),
        \     'tags':  s:fm(function('mucomplete#compat#tags')),
        \     'thes':  s:fm(function('mucomplete#compat#thes')),
        \     'user':  s:fm(function('mucomplete#compat#user')),
        \     'path':  s:fm(function('mucomplete#compat#path')),
        \     'uspl':  s:fm(function('mucomplete#compat#spel')),
        \     'nsnp':  s:fm(function('mucomplete#compat#nsnp')),
        \     'snip':  s:fm(function('mucomplete#compat#snip')),
        \     'ulti':  s:fm(function('mucomplete#compat#ulti'))
        \   }, get(l:cc, 'default', {})),
        \       'c' : extend({ 'omni': s:fm(function('mucomplete#compat#omni_c')) },   get(l:cc, 'c',    {})),
        \     'cpp' : extend({ 'omni': s:fm(function('mucomplete#compat#omni_c')) },   get(l:cc, 'cpp',  {})),
        \    'html' : extend({ 'omni': s:fm(function('mucomplete#compat#omni_xml')) }, get(l:cc, 'html', {})),
        \     'xml' : extend({ 'omni': s:fm(function('mucomplete#compat#omni_xml')) }, get(l:cc, 'xml',  {})),
        \ }, l:cc, 'keep')
  " Special cases
  if has('python') || has('python3')
    call extend(extend(l:can_complete, { 'python': {} }, 'keep')['python'], { 'omni': s:fm(function('mucomplete#compat#omni_python')) }, 'keep')
  endif
  return l:can_complete
endf

let &cpo = s:save_cpo
unlet s:save_cpo

