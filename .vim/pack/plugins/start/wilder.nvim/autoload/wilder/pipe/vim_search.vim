function! wilder#pipe#vim_search#(opts) abort
  return {ctx, x -> s:search(a:opts, ctx, x)}
endfunction

function! s:search(opts, ctx, x) abort
  let l:cursor_pos = getcurpos()
  let l:candidates = []
  let l:candidates_set = {}
  let l:max_candidates = get(a:opts, 'max_candidates', 300)

  let l:current_line = l:cursor_pos[1]
  try
    silent exe 'keeppatterns ' . l:current_line . ',$s/' . a:x . '/\=s:add(submatch(0), l:candidates, l:candidates_set, l:max_candidates)/gne'
    silent exe 'keeppatterns 1,' . l:current_line . 's/' . a:x . '/\=s:add(submatch(0), l:candidates, l:candidates_set, l:max_candidates)/gne'
  catch /^wilder: Max candidates reached/
    return l:candidates
  finally
    call setpos('.', l:cursor_pos)
  endtry

  return l:candidates
endfunction

function! s:add(match, candidates, candidates_set, max_candidates) abort
  if has_key(a:candidates_set, a:match)
    return
  endif

  let a:candidates_set[a:match] = 1
  call add(a:candidates, a:match)

  if a:max_candidates > 0 && len(a:candidates) >= a:max_candidates
    call s:throw()
  endif
endfunction

function! s:throw() abort
  throw 'wilder: Max candidates reached'
endfunction
