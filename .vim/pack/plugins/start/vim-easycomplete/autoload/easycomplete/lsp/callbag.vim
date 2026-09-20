" https://github.com/prabirshrestha/callbag.vim#72acf412812da633cb570fcb971064177719cf35
"    :CallbagEmbed path=autoload/lsp/callbag.vim namespace=lsp#callbag

let s:undefined_token = '__callbag_undefined__'
let s:str_type = type('')

function! easycomplete#lsp#callbag#undefined() abort
  return s:undefined_token
endfunction

function! easycomplete#lsp#callbag#isUndefined(d) abort
  return type(a:d) == s:str_type && a:d ==# s:undefined_token
endfunction

function! s:noop(...) abort
endfunction

function! s:createArrayWithSize(size, defaultValue) abort
  let l:i = 0
  let l:array = []
  while l:i < a:size
    call add(l:array, a:defaultValue)
    let l:i = l:i + 1
  endwhile
  return l:array
endfunction

" merge() {{{
function! easycomplete#lsp#callbag#merge(...) abort
  let l:data = { 'sources': a:000 }
  return function('s:mergeFactory', [l:data])
endfunction

function! s:mergeFactory(data, start, sink) abort
  if a:start != 0 | return | endif
  let a:data['sink'] = a:sink
  let a:data['n'] = len(a:data['sources'])
  let a:data['sourceTalkbacks'] = []
  let a:data['startCount'] = 0
  let a:data['endCount'] = 0
  let a:data['ended'] = 0
  let a:data['talkback'] = function('s:mergeTalkbackCallback', [a:data])
  let l:i = 0
  while l:i < a:data['n']
    if a:data['ended'] | return | endif
    call a:data['sources'][l:i](0, function('s:mergeSourceCallback', [a:data, l:i]))
    let l:i += 1
  endwhile
endfunction

function! s:mergeTalkbackCallback(data, t, d) abort
  if a:t == 2 | let a:data['ended'] = 1 | endif
  let l:i = 0
  while l:i < a:data['n']
    if l:i < len(a:data['sourceTalkbacks']) && a:data['sourceTalkbacks'][l:i] != 0
      call a:data['sourceTalkbacks'][l:i](a:t, a:d)
    endif
    let l:i += 1
  endwhile
endfunction

function! s:mergeSourceCallback(data, i, t, d) abort
  if a:t == 0
    call insert(a:data['sourceTalkbacks'], a:d, a:i)
    let a:data['startCount'] += 1
    if a:data['startCount'] == 1 | call a:data['sink'](0, a:data['talkback']) | endif
  elseif a:t == 2 && !easycomplete#lsp#callbag#isUndefined(a:d)
    let a:data['ended'] = 1
    let l:j = 0
    while l:j < a:data['n']
      if l:j != a:i && l:j < len(a:data['sourceTalkbacks']) && a:data['sourceTalkbacks'][l:j] != 0
        call a:data['sourceTalkbacks'][l:j](2, easycomplete#lsp#callbag#undefined())
      endif
      let l:j += 1
    endwhile
    call a:data['sink'](2, a:d)
  elseif a:t == 2
    let a:data['sourceTalkbacks'][a:i] = 0
    let a:data['endCount'] += 1
    if a:data['endCount'] == a:data['n'] | call a:data['sink'](2, easycomplete#lsp#callbag#undefined()) | endif
  else
    call a:data['sink'](a:t, a:d)
  endif
endfunction
" }}}
"
" filter() {{{
function! easycomplete#lsp#callbag#filter(condition) abort
  let l:data = { 'condition': a:condition }
  return function('s:filterCondition', [l:data])
endfunction

function! s:filterCondition(data, source) abort
  let a:data['source'] = a:source
  return function('s:filterConditionSource', [a:data])
endfunction

function! s:filterConditionSource(data, start, sink) abort
  if a:start != 0 | return | endif
  let a:data['sink'] = a:sink
  call a:data['source'](0, function('s:filterSourceCallback', [a:data]))
endfunction

function! s:filterSourceCallback(data, t, d) abort
  if a:t == 0
    let a:data['talkback'] = a:d
    call a:data['sink'](a:t, a:d)
  elseif a:t == 1
    if a:data['condition'](a:d)
      call a:data['sink'](a:t, a:d)
    else
      call a:data['talkback'](1, easycomplete#lsp#callbag#undefined())
    endif
  else
    call a:data['sink'](a:t, a:d)
  endif
endfunction
" }}}

" tap() {{{
function! easycomplete#lsp#callbag#tap(...) abort
  let l:data = {}
  if a:0 > 0 && type(a:1) == type({}) " a:1 { next, error, complete }
    if has_key(a:1, 'next') | let l:data['next'] = a:1['next'] | endif
    if has_key(a:1, 'error') | let l:data['error'] = a:1['error'] | endif
    if has_key(a:1, 'complete') | let l:data['complete'] = a:1['complete'] | endif
  else " a:1 = next, a:2 = error, a:3 = complete
    if a:0 >= 1 | let l:data['next'] = a:1 | endif
    if a:0 >= 2 | let l:data['error'] = a:2 | endif
    if a:0 >= 3 | let l:data['complete'] = a:3 | endif
  endif
  return function('s:tapFactory', [l:data])
endfunction

function! s:tapFactory(data, source) abort
  let a:data['source'] = a:source
  return function('s:tapSouceFactory', [a:data])
endfunction

function! s:tapSouceFactory(data, start, sink) abort
  if a:start != 0 | return | endif
  let a:data['sink'] = a:sink
  call a:data['source'](0, function('s:tapSourceCallback', [a:data]))
endfunction

function! s:tapSourceCallback(data, t, d) abort
  if a:t == 1 && has_key(a:data, 'next') | call a:data['next'](a:d) | endif
  if a:t == 2 && easycomplete#lsp#callbag#isUndefined(a:d) && has_key(a:data, 'complete') | call a:data['complete']() | endif
  if a:t == 2 && !easycomplete#lsp#callbag#isUndefined(a:d) && has_key(a:data, 'error') | call a:data['error'](a:d) | endif
  call a:data['sink'](a:t, a:d)
endfunction
" }}}

" mark
" pipe() {{{
function! easycomplete#lsp#callbag#pipe(...) abort
  let l:Res = a:1
  let l:i = 1
  while l:i < a:0
    let l:Res = a:000[l:i](l:Res)
    let l:i = l:i + 1
  endwhile
  return l:Res
endfunction
" }}}

" mark
" makeSubject() {{{
function! easycomplete#lsp#callbag#makeSubject() abort
  let l:data = { 'sinks': [] }
  return function('s:makeSubjectFactory', [l:data])
endfunction

function! s:makeSubjectFactory(data, t, d) abort
  if a:t == 0
    let l:Sink = a:d
    call add(a:data['sinks'], l:Sink)
    call l:Sink(0, function('s:makeSubjectSinkCallback', [a:data, l:Sink]))
  else
    let l:zinkz = copy(a:data['sinks'])
    let l:i = 0
    let l:n = len(l:zinkz)
    while l:i < l:n
      let l:Sink = l:zinkz[l:i]
      let l:j = -1
      let l:found = 0
      for l:Item in a:data['sinks']
        let l:j += 1
        if l:Item == l:Sink
          let l:found = 1
          break
        endif
      endfor

      if l:found
        call l:Sink(a:t, a:d)
      endif
      let l:i += 1
    endwhile
  endif
endfunction

function! s:makeSubjectSinkCallback(data, Sink, t, d) abort
  if a:t == 2
    let l:i = -1
    let l:found = 0
    for l:Item in a:data['sinks']
      let l:i += 1
      if l:Item == a:Sink
        let l:found = 1
        break
      endif
    endfor
    if l:found
      call remove(a:data['sinks'], l:i)
    endif
  endif
endfunction
" }}}

" mark
" create() {{{
function! easycomplete#lsp#callbag#create(...) abort
  let l:data = {}
  if a:0 > 0
    let l:data['prod'] = a:1
  endif
  return function('s:createProd', [l:data])
endfunction

function! s:createProd(data, start, sink) abort
  if a:start != 0 | return | endif
  let a:data['sink'] = a:sink
  if !has_key(a:data, 'prod') || type(a:data['prod']) != type(function('s:noop'))
    call a:sink(0, function('s:noop'))
    call a:sink(2, easycomplete#lsp#callbag#undefined())
    return
  endif
  let a:data['end'] = 0
  call a:sink(0, function('s:createSinkCallback', [a:data]))
  if a:data['end'] | return | endif
  let a:data['clean'] = a:data['prod'](function('s:createNext', [a:data]), function('s:createError', [a:data]), function('s:createComplete', [a:data]))
endfunction

function! s:createSinkCallback(data, t, ...) abort
  if !a:data['end']
    let a:data['end'] = (a:t == 2)
    if a:data['end'] && has_key(a:data, 'clean') && type(a:data['clean']) == type(function('s:noop'))
      call a:data['clean']()
    endif
  endif
endfunction

function! s:createNext(data, d) abort
  if !a:data['end'] | call a:data['sink'](1, a:d) | endif
endfunction

function! s:createError(data, e) abort
  if !a:data['end'] && !easycomplete#lsp#callbag#isUndefined(a:e)
    let a:data['end'] = 1
    call a:data['sink'](2, a:e)
  endif
endfunction

function! s:createComplete(data) abort
  if !a:data['end']
    let a:data['end'] = 1
    call a:data['sink'](2, easycomplete#lsp#callbag#undefined())
  endif
endfunction
" }}}

" mark
" lazy() {{{
function! easycomplete#lsp#callbag#lazy(F) abort
  let l:data = { 'F': a:F }
  return function('s:lazyFactory', [l:data])
endfunction

function! s:lazyFactory(data, start, sink) abort
  if a:start != 0 | return | endif
  let a:data['sink'] = a:sink
  let a:data['unsubed'] = 0
  call a:data['sink'](0, function('s:lazySinkCallback', [a:data]))
  call a:data['sink'](1, a:data['F']())
  if !a:data['unsubed'] | call a:data['sink'](2, easycomplete#lsp#callbag#undefined()) | endif
endfunction

function! s:lazySinkCallback(data, t, d) abort
  if a:t == 2 | let a:data['unsubed'] = 1 | endif
endfunction
" }}}

" mark
" subscribe() {{{
function! easycomplete#lsp#callbag#subscribe(...) abort
  let l:data = {}
  if a:0 > 0 && type(a:1) == type({}) " a:1 { next, error, complete }
    if has_key(a:1, 'next') | let l:data['next'] = a:1['next'] | endif
    if has_key(a:1, 'error') | let l:data['error'] = a:1['error'] | endif
    if has_key(a:1, 'complete') | let l:data['complete'] = a:1['complete'] | endif
  else " a:1 = next, a:2 = error, a:3 = complete
    if a:0 >= 1 | let l:data['next'] = a:1 | endif
    if a:0 >= 2 | let l:data['error'] = a:2 | endif
    if a:0 >= 3 | let l:data['complete'] = a:3 | endif
  endif
  return function('s:subscribeListener', [l:data])
endfunction

function! s:subscribeListener(data, source) abort
  call a:source(0, function('s:subscribeSourceCallback', [a:data]))
  return function('s:subscribeDispose', [a:data])
endfunction

function! s:subscribeSourceCallback(data, t, d) abort
  if a:t == 0 | let a:data['talkback'] = a:d | endif
  if a:t == 1 && has_key(a:data, 'next') | call a:data['next'](a:d) | endif
  if a:t == 1 || a:t == 0 | call a:data['talkback'](1, easycomplete#lsp#callbag#undefined()) | endif
  if a:t == 2 && easycomplete#lsp#callbag#isUndefined(a:d) && has_key(a:data, 'complete') | call a:data['complete']() | endif
  if a:t == 2 && !easycomplete#lsp#callbag#isUndefined(a:d) && has_key(a:data, 'error') | call a:data['error'](a:d) | endif
endfunction

function! s:subscribeDispose(data, ...) abort
  if has_key(a:data, 'talkback') | call a:data['talkback'](2, easycomplete#lsp#callbag#undefined()) | endif
endfunction
" }}}

" mark
" {{{
function! easycomplete#lsp#callbag#share(source) abort
  let l:data = { 'source': a:source, 'sinks': [] }
  return function('s:shareFactory', [l:data])
endfunction

function! s:shareFactory(data, start, sink) abort
  if a:start != 0 | return | endif
  call add(a:data['sinks'], a:sink)

  let a:data['talkback'] = function('s:shareTalkbackCallback', [a:data, a:sink])

  if len(a:data['sinks']) == 1
    call a:data['source'](0, function('s:shareSourceCallback', [a:data, a:sink]))
    return
  endif

  call a:sink(0, a:data['talkback'])
endfunction

function! s:shareTalkbackCallback(data, sink, t, d) abort
  if a:t == 2
    let l:i = 0
    let l:found = 0
    while l:i < len(a:data['sinks'])
      if a:data['sinks'][l:i] == a:sink
        let l:found = 1
        break
      endif
      let l:i += 1
    endwhile

    if l:found
      call remove(a:data['sinks'], l:i)
    endif

    if empty(a:data['sinks'])
      call a:data['sourceTalkback'](2, easycomplete#lsp#callbag#undefined())
    endif
  else
    call a:data['sourceTalkback'](a:t, a:d)
  endif
endfunction

function! s:shareSourceCallback(data, sink, t, d) abort
  if a:t == 0
    let a:data['sourceTalkback'] = a:d
    call a:sink(0, a:data['talkback'])
  else
    for l:S in a:data['sinks']
      call l:S(a:t, a:d)
    endfor
  endif
  if a:t == 2
    let a:data['sinks'] = []
  endif
endfunction
" }}}
"
" vim:ts=2:sw=2:ai:foldmethod=marker:foldlevel=0:
