function! wilder#pipe#python_fuzzy_match#(args) abort
  return {ctx, x -> s:fuzzy_match(a:args, ctx, x)}
endfunction

function! s:fuzzy_match(args, ctx, x) abort
  if has_key(a:args, 'word')
    if type(a:args.word) == v:t_func
      let l:word = a:args.word(a:ctx, a:x)
    else
      let l:word = a:args.word
    endif
  else
    let l:word = '\w'
  endif

  if get(a:args, 'start_at_boundary', 1)
    " starts with word boundary or is preceded by a non-word character
    let l:res = '(?:\b|^|(?!' . l:word  . '))'
  else
    let l:res = '(?:' . l:word . ')*'
  endif

  let l:chars = split(a:x, '\zs')
  let l:len = len(l:chars)

  let l:i = 0
  while l:i < l:len
    let l:char = l:chars[l:i]

    if l:char ==# '\'
      if l:i+1 < len(l:chars)
        let l:res .= '(\' . l:chars[l:i+1] . ')'
        let l:i += 2
      else
        let l:res .= '(\\)'
        let l:i += 1
      endif
    elseif l:char ==# '^' ||
          \ l:char ==# '$' ||
          \ l:char ==# '*' ||
          \ l:char ==# '+' ||
          \ l:char ==# '?' ||
          \ l:char ==# '|' ||
          \ l:char ==# '(' ||
          \ l:char ==# ')' ||
          \ l:char ==# '{' ||
          \ l:char ==# '}' ||
          \ l:char ==# '[' ||
          \ l:char ==# ']'
      let l:res .= '(\' . l:char . ')'
      let l:i += 1
    elseif l:char ==# toupper(l:char)
      let l:res .= '(' . l:char . ')'
      let l:i += 1
    else
      let l:res .= '(' . l:char . '|' . toupper(l:char) . ')'
      let l:i += 1
    endif

    let l:res .= l:word . '*'

    if l:i < l:len
      let l:res .= '?'
    endif
  endwhile

  return l:res
endfunction
