function! wilder#yarp#init()
  if has('nvim') || exists('s:wilder')
    return
  endif

  let s:wilder = yarp#py3('wilder_wrap')

  function! _wilder_init(...)
    return s:wilder.call('_init', a:000)
  endfunction

  function! _wilder_python_file_finder(...)
    return s:wilder.call('_file_finder', a:000)
  endfunction

  function! _wilder_python_sleep(...)
    return s:wilder.call('_sleep', a:000)
  endfunction

  function! _wilder_python_search(...)
    return s:wilder.call('_search', a:000)
  endfunction

  function! _wilder_python_uniq_filt(...)
    return s:wilder.call('_uniq_filt', a:000)
  endfunction

  function! _wilder_python_lexical_sort(...)
    return s:wilder.call('_lexical_sort', a:000)
  endfunction

  function! _wilder_python_get_file_completion(...)
    return s:wilder.call('_get_file_completion', a:000)
  endfunction

  function! _wilder_python_get_help_tags(...)
    return s:wilder.call('_get_help_tags', a:000)
  endfunction

  function! _wilder_python_get_users(...)
    return s:wilder.call('_get_users', a:000)
  endfunction

  function! _wilder_python_fuzzy_filt(...)
    return s:wilder.call('_fuzzy_filt', a:000)
  endfunction

  function! _wilder_python_fruzzy_filt(...)
    return s:wilder.call('_fruzzy_filt', a:000)
  endfunction

  function! _wilder_python_cpsm_filt(...)
    return s:wilder.call('_cpsm_filt', a:000)
  endfunction

  function! _wilder_python_difflib_sort(...)
    return s:wilder.call('_difflib_sort', a:000)
  endfunction

  function! _wilder_python_fuzzywuzzy_sort(...)
    return s:wilder.call('_fuzzywuzzy_sort', a:000)
  endfunction

  function! _wilder_python_basic_highlight(...)
    return s:wilder.call('_basic_highlight', a:000)
  endfunction

  function! _wilder_python_pcre2_highlight(...)
    return s:wilder.call('_pcre2_highlight', a:000)
  endfunction

  function! _wilder_python_cpsm_highlight(...)
    return s:wilder.call('_cpsm_highlight', a:000)
  endfunction
endfunction
