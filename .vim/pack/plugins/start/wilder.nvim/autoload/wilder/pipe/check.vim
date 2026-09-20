function! wilder#pipe#check#(args) abort
  return {ctx, x -> s:check(a:args, ctx, x)}
endfunction

function! s:check(checks, ctx, x) abort
  let l:i = 0

  for l:Check in a:checks
    if !l:Check(a:ctx, a:x)
      return v:false
    endif
  endfor

  return a:x
endfunction
