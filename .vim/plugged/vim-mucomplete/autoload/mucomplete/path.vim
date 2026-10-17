" Chained completion that works as I want!
" Maintainer: Lifepillar <lifepillar@lifepillar.me>
" License: MIT

let s:save_cpo = &cpo
set cpo&vim

if has('patch-7.4.654') || (v:version == 704 && has("patch654"))

  fun! s:glob(expr, nosuf, list, alllinks)
    return glob(a:expr, a:nosuf, a:list, a:alllinks)
  endf

elseif v:version > 703 || (v:version == 703 && has("patch465"))

  fun! s:glob(expr, nosuf, list, alllinks)
    return glob(a:expr, a:nosuf, a:list)
  endf

else

  fun! s:glob(expr, nosuf, list, alllinks)
    return split(glob(a:expr, a:nosuf), "\n")
  endf

endif

let s:pathstart = exists('+shellslash') && !&shellslash
      \ ? (get(g:, 'mucomplete#use_only_windows_paths', 0) ? '[\\~]' : '[/\\~]')
      \ : '[/~]'

if exists('&fileignorecase')

  fun! s:case_insensitive()
    return &fileignorecase || &wildignorecase
  endf

elseif exists('&wildignorecase')

  fun! s:case_insensitive()
    return &wildignorecase
  endf

else

  fun! s:case_insensitive()
    return 1
  endf

endif

if has('win32')

  " In Windows, fnamescape() escapes { only if { is not in isfname, but glob()
  " won't like even an escaped { as long as { is in isfname. Using
  " fnameescape() may not be a good idea anyway, but for now we keep it (see
  " https://github.com/vim/vim/issues/541). The best we can do for now is
  " replacing { and } with [\{] and [\}] respectively. They won't match (!) if
  " braces are in isfname, but at least won't give errors either.
  fun! s:fnameescape(p)
    return substitute(
          \ (stridx(&isfname, '{') == -1
          \ ? fnameescape(a:p)
          \ : substitute(fnameescape(a:p), '{', '[\\{]', 'g')),
          \ '}', '[\\}]', 'g')
  endf

else

  " fnamescape() always escapes { (tried macOS and Linux).
  " fnamescape() does not escape }, but glob() needs it to be escaped.
  fun! s:fnameescape(p)
    return escape(fnameescape(a:p), '}')
  endf

endif

fun! mucomplete#path#complete() abort
  let l:prefix = matchstr(getline('.'), '\f\%(\f\|\s\)*\%'.col('.').'c')
  let l:case_insensitive = s:case_insensitive()
  while strlen(l:prefix) > 0 " Try to find an existing path (consider paths with spaces, too)
    if l:prefix ==# '~'
      let l:files = s:glob('~', 0, 1, 1)
      if !empty(l:files)
        call complete(col('.') - 1, map(l:files, '{ "word": v:val, "menu": "[dir]", "icase": l:case_insensitive }'))
      endif
      return ''
    else
      let l:files = s:glob(
            \ (get(g:, 'mucomplete#buffer_relative_paths', 0) && l:prefix !~# '^'.s:pathstart
            \   ? s:fnameescape(expand('%:p:h')) . '/'
            \   : '')
            \ . s:fnameescape(l:prefix) . '*', 0, 1, 1)
      if !empty(l:files)
        call complete(col('.') - len(fnamemodify(l:prefix, ":t")), map(l:files,
              \  '{
              \      "word": fnamemodify(v:val, ":t"),
              \      "menu": (isdirectory(v:val) ? "[dir]" : "[file]"),
              \      "icase": l:case_insensitive
              \   }'
              \ ))
        return ''
      endif
    endif
    let l:prefix = matchstr(l:prefix, '\%(\s\|=\)\zs.*'.s:pathstart.'.*$', 1) " Next potential path
  endwhile
  return ''
endf

let &cpo = s:save_cpo
unlet s:save_cpo

