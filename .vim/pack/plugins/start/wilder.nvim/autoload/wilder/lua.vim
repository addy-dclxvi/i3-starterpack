let s:index = 0
let s:functions = {}
let s:token = 477094643697281 " random number

function! wilder#lua#call(f, ...) abort
  return wilder#lua#wrap(call(a:f, a:000))
endfunction

function! wilder#lua#wrap(t) abort
  if type(a:t) is v:t_string ||
        \ type(a:t) is v:t_number ||
        \ type(a:t) is v:t_bool ||
        \ a:t is v:null
    return a:t
  endif

  if type(a:t) is v:t_func
    return s:wrap_function(a:t)
  endif

  if type(a:t) is v:t_dict
    for l:key in keys(a:t)
      let l:Value = a:t[l:key]
      let a:t[l:key] = wilder#lua#wrap(l:Value)
    endfor
  endif

  " v:t_list
  return map(a:t, {_, x -> wilder#lua#wrap(x)})
endfunction

function! s:wrap_function(f) abort
  let l:index = s:index
  let s:index += 1

  let s:functions[l:index] = a:f
  return {
        \ 'index': l:index,
        \ 'name': get(a:f, 'name'),
        \ '__wilder_wrapped__': s:token,
        \ }
endfunction

function! wilder#lua#call_wrapped_function(index, ...) abort
  let l:F = s:functions[a:index]
  let l:Result = call(l:F, a:000)
  return wilder#lua#wrap(l:Result)
endfunction

function! wilder#lua#unref_wrapped_function(index) abort
  unlet s:functions[a:index]
endfunction

function! wilder#lua#_get_functions() abort
  return s:functions
endfunction
