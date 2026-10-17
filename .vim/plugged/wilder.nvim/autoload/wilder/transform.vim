function! wilder#transform#lexical_sorter() abort
  return {ctx, xs -> wilder#transform#lexical_sort(ctx, 0, xs)}
endfunction

" opts and query are ignored
function! wilder#transform#lexical_sort(ctx, opts, xs, ...) abort
  return sort(copy(a:xs))
endfunction

function! wilder#transform#python_lexical_sorter() abort
  return {ctx, xs -> wilder#transform#python_lexical_sort(ctx, 0, xs)}
endfunction

" opts and query are ignored
function! wilder#transform#python_lexical_sort(ctx, opts, xs, ...) abort
  return {ctx -> _wilder_python_lexical_sort(ctx, a:xs)}
endfunction

function! wilder#transform#python_lexical_sorter() abort
  return {ctx, xs -> wilder#transform#python_lexical_sort(ctx, 0, xs)}
endfunction

" opts and query are ignored
function! wilder#transform#python_lexical_sort(ctx, opts, xs, ...) abort
  return {ctx -> _wilder_python_lexical_sort(ctx, a:xs)}
endfunction

function! wilder#transform#python_difflib_sorter(...) abort
  let l:opts = {
        \ 'quick': get(a:, 1, 1),
        \ 'case_sensitive': get(a:, 2, 1),
        \ }
  return {ctx, xs, query -> wilder#transform#python_difflib_sort(ctx, l:opts, xs, query)}
endfunction

function! wilder#transform#python_difflib_sort(ctx, opts, xs, query) abort
  return {ctx -> _wilder_python_difflib_sort(ctx, a:opts, a:xs, a:query)}
endfunction

function! wilder#transform#python_fuzzywuzzy_sorter(...) abort
  let l:opts = {
        \ 'partial': get(a:, 1, 1),
        \ }
  return {ctx, xs, query -> wilder#transform#python_fuzzywuzzy_sort(ctx, l:opts, xs, query)}
endfunction

function! wilder#transform#python_fuzzywuzzy_sort(ctx, opts, xs, query) abort
  return {ctx -> _wilder_python_fuzzywuzzy_sort(ctx, a:opts, a:xs, a:query)}
endfunction

" filters

function! wilder#transform#uniq_filter() abort
  return {ctx, xs -> wilder#transform#uniq_filt(ctx, 0, xs)}
endfunction

function! wilder#transform#uniq_filt(ctx, opts, xs, ...) abort
  let l:seen = {}
  let l:res = []

  for l:x in a:xs
    if !has_key(l:seen, l:x)
      let l:seen[l:x] = 1
      call add(l:res, l:x)
    endif
  endfor

  return l:res
endfunction

function! wilder#transform#python_uniq_filter() abort
  return {ctx, xs, -> wilder#transform#python_uniq_filt(ctx, 0, xs)}
endfunction

function! wilder#transform#python_uniq_filt(ctx, opts, xs, ...) abort
  return {ctx -> _wilder_python_uniq_filt(ctx, a:xs)}
endfunction

function! wilder#transform#fuzzy_filter(...) abort
  if wilder#options#get('use_python_remote_plugin')
    return call('wilder#python_fuzzy_filter', a:000)
  endif

  return wilder#transform#vim_fuzzy_filter()
endfunction

function! wilder#transform#fuzzy_filt(ctx, opts, candidates, query) abort
  if wilder#options#get('use_python_remote_plugin')
    return wilder#transform#python_fuzzy_filt(a:ctx, a:opts, a:candidates, a:query)
  endif

  return wilder#transform#vim_fuzzy_filt(a:ctx, a:opts, a:candidates, a:query)
endfunction

function! wilder#transform#vim_fuzzy_filter() abort
  return {ctx, xs, q -> wilder#vim_fuzzy_filt(ctx, {}, xs, q)}
endfunction

function! wilder#transform#vim_fuzzy_filt(ctx, opts, candidates, query) abort
  if empty(a:query)
    return a:candidates
  endif

  if exists('*matchfuzzy')
    return matchfuzzy(a:candidates, a:query)
  endif

  return s:vim_fuzzy_filt(a:ctx, a:candidates, a:query)
endfunction

function! s:vim_fuzzy_filt(ctx, candidates, query) abort
  if empty(a:query)
    return a:candidates
  endif

  " make fuzzy regex
  let l:split_query = split(a:query, '\zs')
  let l:i = 0
  let l:regex = '\V'
  while l:i < len(l:split_query)
    if l:i > 0
      let l:regex .= '\.\{-}'
    endif

    let l:c = l:split_query[l:i]

    if l:c ==# '\'
      let l:regex .= '\\'
    elseif l:c ==# toupper(l:c)
      let l:regex .= l:c
    else
      let l:regex .= '\%(' . l:c . '\|' . toupper(l:c) . '\)'
    endif

    let l:i += 1
  endwhile

  return filter(copy(a:candidates), {_, x -> match(x, l:regex) != -1})
endfunction

function! wilder#transform#python_fuzzy_filter(...) abort
  let l:opts = {
        \ 'engine': get(a:, 1, 're'),
        \ }
  return {ctx, xs, q -> wilder#transform#python_fuzzy_filt(ctx, l:opts, xs, q)}
endfunction

function! wilder#transform#python_fuzzy_filt(ctx, opts, candidates, query) abort
  if empty(a:query)
    return a:candidates
  endif

  let l:regex = wilder#transform#make_python_fuzzy_regex(a:query)

  return {ctx -> _wilder_python_fuzzy_filt(ctx, a:opts, a:candidates, l:regex)}
endfunction

function! wilder#transform#make_python_fuzzy_regex(query)
  let l:split_query = split(a:query, '\zs')

  let l:regex = ''
  let l:i = 0
  while l:i < len(l:split_query)
    if l:i > 0
      let l:regex .= '.*?'
    endif

    let l:c = l:split_query[l:i]

    if l:c ==# '\' ||
          \ l:c ==# '.' ||
          \ l:c ==# '^' ||
          \ l:c ==# '$' ||
          \ l:c ==# '*' ||
          \ l:c ==# '+' ||
          \ l:c ==# '?' ||
          \ l:c ==# '|' ||
          \ l:c ==# '(' ||
          \ l:c ==# ')' ||
          \ l:c ==# '{' ||
          \ l:c ==# '}' ||
          \ l:c ==# '[' ||
          \ l:c ==# ']'
      let l:regex .= '(\' . l:c . ')'
    elseif l:c ==# toupper(l:c)
      let l:regex .= '(' . l:c . ')'
    else
      let l:regex .= '(' . l:c . '|' . toupper(l:c) . ')'
    endif

    let l:i += 1
  endwhile

  return l:regex
endfunction

function! wilder#transform#python_fruzzy_filter(...) abort
  let l:opts = {
        \ 'limit': get(a:, 1, 1000),
        \ 'fruzzy_path': get(a:, 2, wilder#fruzzy_path()),
        \ }
  return {ctx, xs, q -> wilder#transform#python_fruzzy_filt(ctx, l:opts, xs, q)}
endfunction

function! wilder#transform#python_fruzzy_filt(ctx, opts, candidates, query) abort
  if empty(a:query)
    return a:candidates
  endif

  return {ctx -> _wilder_python_fruzzy_filt(ctx, a:opts, a:candidates, a:query)}
endfunction

function! wilder#transform#python_cpsm_filter(...) abort
  let l:opts = {
        \ 'cpsm_path': get(a:, 1, wilder#cpsm_path()),
        \ }
  return {ctx, xs, q -> wilder#transform#python_cpsm_filt(ctx, l:opts, xs, q)}
endfunction

function! wilder#transform#python_cpsm_filt(ctx, opts, candidates, query) abort
  if empty(a:query)
    return a:candidates
  endif

  return {ctx -> _wilder_python_cpsm_filt(ctx, a:opts, a:candidates, a:query)}
endfunction

function! wilder#transform#python_clap_filter(...) abort
  let l:opts = get(a:, 1, {})
  if !has_key(l:opts, 'clap_path')
    let l:opts.clap_path = wilder#clap_path()
  endif

  if !has_key(l:opts, 'use_rust')
    let l:use_rust = !empty(wilder#findfile('pythonx/clap/fuzzymatch_rs.so')) ||
          \ !empty(wilder#findfile('pythonx/clap/fuzzymatch_rs.dyn'))
    let l:opts.use_rust = l:use_rust
  endif

  return {ctx, xs, q -> wilder#transform#python_clap_filt(ctx, l:opts, xs, q)}
endfunction

function! wilder#transform#python_clap_filt(ctx, opts, candidates, query) abort
  if empty(a:query)
    return a:candidates
  endif

  return {ctx -> _wilder_python_clap_filt(ctx, a:opts, a:candidates, a:query)}
endfunction

function! wilder#transform#lua_fzy_filter() abort
  return {ctx, xs, q -> wilder#transform#lua_fzy_filt(ctx, 0, xs, q)}
endfunction

function! wilder#transform#lua_fzy_filt(ctx, opts, candidates, query) abort
  if empty(a:query)
    return a:candidates
  endif

  return luaeval('require("wilder.internal").fzy_filter(_A[1], _A[2])', [a:candidates, a:query])
endfunction
