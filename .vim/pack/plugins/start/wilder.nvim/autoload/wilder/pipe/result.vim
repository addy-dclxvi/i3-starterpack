function! wilder#pipe#result#(...) abort
  let l:args = a:0 ? a:1 : {}
  return {ctx, x -> s:result_start(l:args, ctx, x)}
endfunction

function! s:result_start(args, ctx, x) abort
  let l:kvs = []
  for l:key in keys(a:args)
    call add(l:kvs, {'key': l:key, 'value': a:args[l:key]})
  endfor

  let l:result = type(a:x) isnot v:t_dict
        \ ? {'value': a:x}
        \ : a:x

  if empty(l:kvs)
    return l:result
  endif

  return s:result(l:kvs, a:ctx, l:result)
endfunction

function! s:result(kvs, ctx, result)
  if empty(a:kvs)
    return a:result
  endif

  let l:kvs = a:kvs

  while !empty(l:kvs)
    let l:kv = l:kvs[0]
    let l:kvs = l:kvs[1:]
    let l:key = l:kv.key
    let l:Value = l:kv.value

    if type(l:Value) is v:t_func
      let l:R = l:Value(a:ctx, get(a:result, l:key, v:null), get(a:result, 'data', {}))

      if type(l:R) is v:t_func
        return wilder#wait(l:R, {ctx, value ->
              \ wilder#resolve(ctx, s:result(l:kvs, ctx, s:add_key(a:result, l:key, value)))})
      endif

      let a:result[l:key] = l:R
    elseif type(l:Value) is v:t_list
      let a:result[l:key] = get(a:result, l:key, []) + l:Value
    elseif type(l:Value) is v:t_dict
      let a:result[l:key] = extend(get(a:result, l:key, {}), l:Value)
    else
      let a:result[l:key] = l:Value
    endif
  endwhile

  return a:result
endfunction

function! s:extend(ctx, key, value)
  let l:ctx = copy(a:ctx)
  let l:ctx[a:key] = extend(get(l:ctx, a:key, {}), a:value)
  return l:ctx
endfunction

function! s:add_key(result, key, value)
  let l:result = copy(a:result)
  let l:result[a:key] = a:value
  return l:result
endfunction

function! wilder#pipe#result#escape_output_result(chars) abort
  return wilder#result({
        \ 'output': ['wilder#pipe#result#escape_output'],
        \ 'data': {ctx, data -> s:set_data(data, a:chars)},
        \ })
endfunction

function! wilder#pipe#result#escape_output(ctx, x, data) abort
  return escape(a:x, get(a:data, 'escape_chars', ''))
endfunction

function! s:set_data(data, chars) abort
  let l:data = a:data is v:null ? {} : a:data

  return extend(l:data, {'escape_chars': a:chars})
endfunction
