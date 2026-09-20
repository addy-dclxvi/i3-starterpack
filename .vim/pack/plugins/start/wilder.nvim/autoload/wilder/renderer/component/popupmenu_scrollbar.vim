function! wilder#renderer#component#popupmenu_scrollbar#(opts) abort
  let l:state = {}

  let l:thumb_char = get(a:opts, 'thumb_char', '█')
  let l:thumb_hl = get(a:opts, 'thumb_hl', 'PmenuThumb')
  let l:scrollbar_char = get(a:opts, 'scrollbar_char', ' ')
  let l:scrollbar_hl = get(a:opts, 'scrollbar_hl', 'PmenuSbar')

  let l:state.thumb_chunk = [l:thumb_char, l:thumb_hl]
  let l:state.scrollbar_chunk = [l:scrollbar_char, l:scrollbar_hl]

  let l:state.collapse = get(a:opts, 'collapse', 1)

  return {ctx, result -> s:scrollbar(l:state, ctx, result)}
endfunction

function! s:scrollbar(state, ctx, result) abort
  let [l:start, l:end] = a:ctx.page
  let l:num_candidates = len(a:result.value)
  let l:height = a:ctx.height

  if l:num_candidates <= l:height
    if a:state.collapse
      return []
    else
      return repeat([[a:state.scrollbar_chunk]], l:height)
    endif
  endif

  let l:thumb_start = float2nr(1.0 * l:start * l:height / l:num_candidates)
  let l:thumb_size = float2nr(1.0 * l:height * l:height / l:num_candidates) + 1
  let l:thumb_end = l:thumb_start + l:thumb_size

  " Due to floating point rounding, thumb can exceed height.
  " Adjust the thumb back 1 row so that visually the thumb size remains fixed.
  " The position of the thumb will be wrong but the fixed thumb size is more
  " important.
  if l:thumb_end > l:height
    let l:thumb_start -= 1
    let l:thumb_end -= 1
  endif

  " Adjust case where rounding causes l:thumb_size to equal l:height.
  if l:thumb_size == l:height
    let l:thumb_size -= 1

    if l:end < l:num_candidates - 1
      let l:thumb_end -= 1
    else
      let l:thumb_start += 1
    endif
  endif

  let l:thumb_chunk = a:state.thumb_chunk
  let l:scrollbar_chunk = a:state.scrollbar_chunk

  let l:before_thumb_chunks = repeat([[l:scrollbar_chunk]], l:thumb_start)
  let l:thumb_chunks = repeat([[l:thumb_chunk]], l:thumb_size)
  let l:after_thumb_chunks = repeat([[l:scrollbar_chunk]], l:height - l:thumb_end)

  return l:before_thumb_chunks + l:thumb_chunks + l:after_thumb_chunks
endfunction
