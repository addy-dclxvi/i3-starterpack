function! wilder#cache#cache() abort
  return {
        \ '_cache': {},
        \ 'get': funcref('s:get'),
        \ 'set': funcref('s:set'),
        \ 'has_key': funcref('s:has_key'),
        \ 'clear': funcref('s:clear'),
        \ }
endfunction

function! s:get(key) dict abort
  return self['_cache'][a:key]
endfunction

function! s:set(key, value) dict abort
  let self['_cache'][a:key] = a:value
endfunction

function! s:has_key(key) dict abort
  return has_key(self['_cache'], a:key)
endfunction

function! s:clear() dict abort
  let self['_cache'] = {}
endfunction

function! wilder#cache#mru_cache(max_size) abort
  return {
        \ '_cache': {},
        \ '_queue': [],
        \ '_counts': {},
        \ '_max_size': a:max_size,
        \ 'get': funcref('s:mru_get'),
        \ 'set': funcref('s:mru_set'),
        \ 'has_key': funcref('s:has_key'),
        \ 'clear': funcref('s:mru_clear'),
        \ 'mru_update': funcref('s:mru_update'),
        \ }
endfunction

function! s:mru_get(key) dict abort
  return self['_cache'][a:key]
endfunction

function! s:mru_set(key, value) dict abort
  let self['_cache'][a:key] = a:value

  call self.mru_update(a:key)
endfunction

function! s:mru_clear() dict abort
  let self['_cache'] = {}
  let self['_queue'] = []
endfunction

function! s:mru_update(key) dict abort
  let l:queue = self['_queue']
  let l:counts = self['_counts']

  call add(l:queue, a:key)
  if !has_key(l:counts, a:key)
    let l:counts[a:key] = 1
  else
    let l:counts[a:key] += 1
  endif

  if len(l:queue) > self['_max_size']
    let l:removed_key = remove(l:queue, 0)
    let l:counts[l:removed_key] -= 1

    if l:counts[l:removed_key] == 0
      unlet l:counts[l:removed_key]
      unlet self['_cache'][l:removed_key]
    endif
  endif
endfunction
