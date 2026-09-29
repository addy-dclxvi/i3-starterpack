let s:character_classes = {
      \ 'alnum:]': 0,
      \ 'alpha:]': 0,
      \ 'blank:]': 0,
      \ 'cntrl:]': 0,
      \ 'digit:]': 0,
      \ 'graph:]': 0,
      \ 'lower:]': 0,
      \ 'print:]': 0,
      \ 'punct:]': 0,
      \ 'space:]': 0,
      \ 'upper:]': 0,
      \ 'xdigit:]': 0,
      \ 'tab:]': 0,
      \ 'return:]': 0,
      \ 'backspace:]': 0,
      \ 'escape:]': 0,
      \ }

" TODO: multibyte
function! wilder#cmdline#skip_regex#do(ctx, delimiter) abort
  let l:magic = &magic

  while a:ctx.pos < len(a:ctx.cmdline)
    let l:char = a:ctx.cmdline[a:ctx.pos]
    if l:char ==# a:delimiter
      return 1
    endif

    if l:magic && l:char ==# '['
      let a:ctx.pos += 1
      call s:skip_regex_range(a:ctx)

      if a:ctx.pos >= len(a:ctx.cmdline)
        return 0
      endif
    elseif !l:magic && l:char ==# '\\' && a:ctx.cmdline[a:ctx.pos + 1] ==# '['
      let a:ctx.pos += 2
      call s:skip_regex_range(a:ctx)

      if a:ctx.pos == len(a:ctx.cmdline)
        return 0
      endif
    elseif l:char ==# '\' && a:ctx.pos + 1 < len(a:ctx.cmdline)
      let a:ctx.pos += 1

      let l:char = a:ctx.cmdline[a:ctx.pos]
      if l:char ==# 'v'
        let l:magic = 1
      elseif l:char ==# 'V'
        let l:magic = 0
      endif
    endif

    let a:ctx.pos += 1
  endwhile

  return 0
endfunction

function! s:skip_regex_range(ctx) abort
  let l:char = a:ctx.cmdline[a:ctx.pos]

  if a:ctx.cmdline[a:ctx.pos] ==# '^'
    let a:ctx.pos += 1
  endif

  if a:ctx.cmdline[a:ctx.pos] ==# ']' ||
        \ a:ctx.cmdline[a:ctx.pos] ==# '-'
    let a:ctx.pos += 1
  endif

  while a:ctx.pos < len(a:ctx.cmdline) &&
        \ a:ctx.cmdline[a:ctx.pos] !=# ']'
    let l:char = a:ctx.cmdline[a:ctx.pos]

    if l:char ==# '-'
      let a:ctx.pos += 1

      if a:ctx.cmdline[a:ctx.pos] !=# ']' &&
          \ a:ctx.pos + 1 < len(a:ctx.cmdline)

        let a:ctx.pos += 1
      endif
    elseif l:char ==# '\' &&
          \ a:ctx.pos + 1 < len(a:ctx.cmdline) &&
          \ (stridx(']^-n\', a:ctx.cmdline[a:ctx.pos + 1]) != -1 ||
          \ stridx(&cpoptions, 'l') == -1 && stridx(']^-n\', a:ctx.cmdline[a:ctx.pos + 1]) != -1)
      let a:ctx.pos += 2
    elseif l:char ==# '['
      if !s:is_character_class(a:ctx) &&
            \ !s:is_equivalence_class(a:ctx) &&
            \ !s:is_collating_element(a:ctx)
        let a:ctx.pos += 1
      endif
    else
      let a:ctx.pos += 1
    endif
  endwhile
endfunction

function s:is_character_class(ctx) abort
  if a:ctx.cmdline[a:ctx.pos + 1] ==# ':'
    for l:class in keys(s:character_classes)
      if a:ctx.cmdline[a:ctx.pos : a:ctx.pos + len(l:class) - 1] ==# l:class
        let a:ctx.pos += len(l:class)

        return 1
      endif
    endfor
  endif

  return 0
endfunction

function! s:is_equivalence_class(ctx) abort
  if a:ctx.cmdline[a:ctx.pos + 1] ==# '=' &&
        \ a:ctx.cmdline[a:ctx.pos + 3] ==# '=' &&
        \ a:ctx.cmdline[a:ctx.pos + 4] ==# ']'
    " pos + 2 is the character representing the class

    let a:ctx.pos += 4
    return 1
  endif

  return 0
endfunction

function! s:is_collating_element(ctx) abort
  if a:ctx.cmdline[a:ctx.pos + 1] ==# '.' &&
        \ a:ctx.cmdline[a:ctx.pos + 3] ==# '.' &&
        \ a:ctx.cmdline[a:ctx.pos + 4] ==# ']'
    " pos + 2 is the character representing the elememnt

    let a:ctx.pos += 4
    return 1
  endif

  return 0
endfunction
