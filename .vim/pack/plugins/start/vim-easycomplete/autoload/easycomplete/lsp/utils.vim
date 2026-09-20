let s:has_lua = has('nvim-0.4.0') || (has('lua') && has('patch-8.2.0775'))
function! easycomplete#lsp#utils#has_lua() abort
  return s:has_lua
endfunction

let s:has_virtual_text = exists('*nvim_buf_set_virtual_text') && exists('*nvim_create_namespace')
function! easycomplete#lsp#utils#_has_virtual_text() abort
  return s:has_virtual_text
endfunction

let s:has_signs = exists('*sign_define') && (has('nvim') || has('patch-8.1.0772'))
function! easycomplete#lsp#utils#_has_signs() abort
  return s:has_signs
endfunction

let s:has_nvim_buf_highlight = exists('*nvim_buf_add_highlight')
function! easycomplete#lsp#utils#_has_nvim_buf_highlight() abort
  return s:has_nvim_buf_highlight
endfunction

" https://github.com/prabirshrestha/vim-lsp/issues/399#issuecomment-500585549
let s:has_textprops = exists('*prop_add') && has('patch-8.1.1035')
function! easycomplete#lsp#utils#_has_textprops() abort
  return s:has_textprops
endfunction

let s:has_higlights = has('nvim') ? easycomplete#lsp#utils#_has_nvim_buf_highlight() : easycomplete#lsp#utils#_has_textprops()
function! easycomplete#lsp#utils#_has_highlights() abort
  return s:has_higlights
endfunction

function! easycomplete#lsp#utils#is_file_uri(uri) abort
  return stridx(a:uri, 'file:///') == 0
endfunction

function! easycomplete#lsp#utils#is_remote_uri(uri) abort
  return a:uri =~# '^\w\+::' || a:uri =~# '^[a-z][a-z0-9+.-]*://'
endfunction

function! s:decode_uri(uri) abort
  let l:ret = substitute(a:uri, '[?#].*', '', '')
  return substitute(l:ret, '%\(\x\x\)', '\=printf("%c", str2nr(submatch(1), 16))', 'g')
endfunction

function! s:urlencode_char(c) abort
  return printf('%%%02X', char2nr(a:c))
endfunction

function! s:get_prefix(path) abort
  return matchstr(a:path, '\(^\w\+::\|^\w\+://\)')
endfunction

function! s:encode_uri(path, start_pos_encode, default_prefix) abort
  let l:prefix = s:get_prefix(a:path)
  let l:path = a:path[len(l:prefix):]
  if len(l:prefix) == 0
    let l:prefix = a:default_prefix
  endif

  let l:result = strpart(a:path, 0, a:start_pos_encode)

  for l:i in range(a:start_pos_encode, len(l:path) - 1)
    " Don't encode '/' here, `path` is expected to be a valid path.
    if l:path[l:i] =~# '^[a-zA-Z0-9_.~/-]$'
      let l:result .= l:path[l:i]
    else
      let l:result .= s:urlencode_char(l:path[l:i])
    endif
  endfor

  return l:prefix . l:result
endfunction

let s:path_to_uri_cache = {}
if has('win32') || has('win64')
  function! easycomplete#lsp#utils#path_to_uri(path) abort
    if has_key(s:path_to_uri_cache, a:path)
      return s:path_to_uri_cache[a:path]
    endif

    if empty(a:path) || easycomplete#lsp#utils#is_remote_uri(a:path)
      let s:path_to_uri_cache[a:path] = a:path
      return s:path_to_uri_cache[a:path]
    else
      " You must not encode the volume information on the path if
      " present
      let l:end_pos_volume = matchstrpos(a:path, '\c[A-Z]:')[2]

      if l:end_pos_volume == -1
        let l:end_pos_volume = 0
      endif

      let s:path_to_uri_cache[a:path] = s:encode_uri(substitute(a:path, '\', '/', 'g'), l:end_pos_volume, 'file:///')
      return s:path_to_uri_cache[a:path]
    endif
  endfunction
else
  function! easycomplete#lsp#utils#path_to_uri(path) abort
    if has_key(s:path_to_uri_cache, a:path)
      return s:path_to_uri_cache[a:path]
    endif

    if empty(a:path) || easycomplete#lsp#utils#is_remote_uri(a:path)
      let s:path_to_uri_cache[a:path] = a:path
      return s:path_to_uri_cache[a:path]
    else
      let s:path_to_uri_cache[a:path] = s:encode_uri(a:path, 0, 'file://')
      return s:path_to_uri_cache[a:path]
    endif
  endfunction
endif

let s:uri_to_path_cache = {}
if has('win32') || has('win64')
  function! easycomplete#lsp#utils#uri_to_path(uri) abort
    if has_key(s:uri_to_path_cache, a:uri)
      return s:uri_to_path_cache[a:uri]
    endif

    let s:uri_to_path_cache[a:uri] = substitute(s:decode_uri(a:uri[len('file:///'):]), '/', '\\', 'g')
    return s:uri_to_path_cache[a:uri]
  endfunction
else
  function! easycomplete#lsp#utils#uri_to_path(uri) abort
    if has_key(s:uri_to_path_cache, a:uri)
      return s:uri_to_path_cache[a:uri]
    endif

    let s:uri_to_path_cache[a:uri] = s:decode_uri(a:uri[len('file://'):])
    return s:uri_to_path_cache[a:uri]
  endfunction
endif

function! easycomplete#lsp#utils#get_default_root_uri() abort
  return easycomplete#lsp#utils#path_to_uri(getcwd())
endfunction

function! easycomplete#lsp#utils#get_buffer_path(...) abort
  return expand((a:0 > 0 ? '#' . a:1 : '%') . ':p')
endfunction

function! easycomplete#lsp#utils#get_buffer_uri(...) abort
  return easycomplete#lsp#utils#path_to_uri(expand((a:0 > 0 ? '#' . a:1 : '%') . ':p'))
endfunction

" Find a nearest to a `path` parent directory `directoryname` by traversing the filesystem upwards
function! easycomplete#lsp#utils#find_nearest_parent_directory(path, directoryname) abort
  let l:relative_path = finddir(a:directoryname, a:path . ';')

  if !empty(l:relative_path)
    return fnamemodify(l:relative_path, ':p')
  else
    return ''
  endif
endfunction

" Find a nearest to a `path` parent filename `filename` by traversing the filesystem upwards
function! easycomplete#lsp#utils#find_nearest_parent_file(path, filename) abort
  let l:relative_path = findfile(a:filename, a:path . ';')

  if !empty(l:relative_path)
    return fnamemodify(l:relative_path, ':p')
  else
    return ''
  endif
endfunction

function! easycomplete#lsp#utils#_compare_nearest_path(matches, lhs, rhs) abort
  let l:llhs = len(a:lhs)
  let l:lrhs = len(a:rhs)
  if l:llhs ># l:lrhs
    return -1
  elseif l:llhs <# l:lrhs
    return 1
  endif
  if a:matches[a:lhs] ># a:matches[a:rhs]
    return -1
  elseif a:matches[a:lhs] <# a:matches[a:rhs]
    return 1
  endif
  return 0
endfunction

function! easycomplete#lsp#utils#_nearest_path(matches) abort
  return empty(a:matches) ?
        \ '' :
        \ sort(keys(a:matches), function('easycomplete#lsp#utils#_compare_nearest_path', [a:matches]))[0]
endfunction

function! easycomplete#lsp#utils#error(msg) abort
  echohl ErrorMsg
  echom a:msg
  echohl NONE
endfunction

" Convert a byte-index (1-based) to a character-index (0-based)
" This function requires a buffer specifier (expr, see :help bufname()),
" a line number (lnum, 1-based), and a byte-index (char, 1-based).
function! easycomplete#lsp#utils#to_char(expr, lnum, col) abort
  let l:lines = getbufline(a:expr, a:lnum)
  if l:lines == []
    if type(a:expr) != v:t_string || !filereadable(a:expr)
      " invalid a:expr
      return a:col - 1
    endif
    " a:expr is a file that is not yet loaded as a buffer
    let l:lines = readfile(a:expr, '', a:lnum)
  endif
  let l:linestr = l:lines[-1]
  return strchars(strpart(l:linestr, 0, a:col - 1))
endfunction

function! easycomplete#lsp#utils#make_valid_word(str) abort
  let l:str = substitute(a:str, '\$[0-9]\+\|\${\%(\\.\|[^}]\)\+}', '', 'g')
  let l:str = substitute(l:str, '\\\(.\)', '\1', 'g')
  let l:valid = matchstr(l:str, '^[^"'' (<{\[\t\r\n]\+')
  if empty(l:valid)
    return l:str
  endif
  if l:valid =~# ':$'
    return l:valid[:-2]
  endif
  return l:valid
endfunction

" polyfill for the neovim wait function
if exists('*wait')
  function! easycomplete#lsp#utils#_wait(timeout, condition, ...) abort
    if type(a:timeout) != type(0)
      return -3
    endif
    if type(get(a:000, 0, 0)) != type(0)
      return -3
    endif
    while 1
      let l:result=call('wait', extend([a:timeout, a:condition], a:000))
      if l:result != -3 " ignore spurious errors
        return l:result
      endif
    endwhile
  endfunction
else
  function! easycomplete#lsp#utils#_wait(timeout, condition, ...) abort
    try
      let l:timeout = a:timeout / 1000.0
      let l:interval = get(a:000, 0, 200)
      let l:Condition = a:condition
      if type(l:Condition) != type(function('eval'))
        let l:Condition = function('eval', l:Condition)
      endif
      let l:start = reltime()
      while l:timeout < 0 || reltimefloat(reltime(l:start)) < l:timeout
        if l:Condition()
          return 0
        endif

        execute 'sleep ' . l:interval . 'm'
      endwhile
      return -1
    catch /^Vim:Interrupt$/
      return -2
    endtry
  endfunction
endif

function! s:errlog(...)
  return call('easycomplete#util#errlog', a:000)
endfunction
