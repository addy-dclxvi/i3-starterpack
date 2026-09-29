function! wilder#in_context()
  return wilder#main#in_context()
endfunction

function! wilder#enable_cmdline_enter()
  return wilder#main#enable_cmdline_enter()
endfunction

function! wilder#enable()
  return wilder#main#enable()
endfunction

function! wilder#disable()
  return wilder#main#disable()
endfunction

function! wilder#toggle()
  return wilder#main#toggle()
endfunction

function! wilder#set_option(x, ...) abort
  if !a:0
    call wilder#options#set(a:x)
  else
    call wilder#options#set(a:x, a:1)
  endif
endfunction

function! wilder#next()
  return wilder#main#next()
endfunction

function! wilder#previous()
  return wilder#main#previous()
endfunction

function! wilder#resolve(ctx, x)
  call timer_start(0, {-> wilder#pipeline#resolve(a:ctx, a:x)})
endfunction

function! wilder#reject(ctx, x)
  call timer_start(0, {-> wilder#pipeline#reject(a:ctx, a:x)})
endfunction

" DEPRECATED: use wilder#resolve()
function! wilder#on_finish(ctx, x)
  return call('wilder#resolve', [a:ctx, a:x])
endfunction

" DEPRECATED: use wilder#reject()
function! wilder#on_error(ctx, x)
  return call('wilder#reject', [a:ctx, a:x])
endfunction

function! wilder#wait(f, ...)
  if !a:0
    return wilder#pipeline#wait(a:f)
  elseif a:0 == 1
    return wilder#pipeline#wait(a:f, a:1)
  else
    return wilder#pipeline#wait(a:f, a:1, a:2)
  endif
endfunction

function! wilder#can_reject_completion()
  return wilder#main#can_reject_completion()
endfunction

function! wilder#reject_completion()
  return wilder#main#reject_completion()
endfunction

function! wilder#can_accept_completion()
  return wilder#main#can_accept_completion()
endfunction

function! wilder#accept_completion(...)
  let l:auto_select = get(a:, 1, 1)
  return wilder#main#accept_completion(l:auto_select)
endfunction

function! wilder#start_from_normal_mode()
  return wilder#main#start_from_normal_mode()
endfunction

function! wilder#make_hl(name, args, ...) abort
  return wilder#highlight#make_hl(a:name, a:args, a:000)
endfunction

function! wilder#make_temp_hl(name, args, ...) abort
  return wilder#highlight#make_temp_hl(a:name, a:args, a:000)
endfunction

function! wilder#hl_with_attr(name, hl_group, ...) abort
  let l:attrs = {}
  for l:attr in a:000
    if l:attr[:1] ==# 'no'
      let l:attrs[l:attr[2:]] = v:false
    else
      let l:attrs[l:attr] = v:true
    endif
  endfor
  return wilder#make_hl(a:name, a:hl_group, [{}, l:attrs, l:attrs])
endfunction

" DEPRECATED: use wilder#basic_highlighter()
function! wilder#query_highlighter(...)
  return call('wilder#basic_highlighter', a:000)
endfunction

" DEPRECATED: use wilder#basic_highlighter()
function! wilder#query_common_subsequence_spans(...)
  return call('wilder#basic_highlighter', a:000)
endfunction

function! wilder#basic_highlighter(...)
  let l:opts = get(a:, 1, {})
  return wilder#highlighter#basic_highlighter(l:opts)
endfunction

function! wilder#vim_basic_highlighter(...) abort
  let l:opts = get(a:, 1, {})
  let l:opts.language = 'vim'
  return wilder#highlighter#basic_highlighter(l:opts)
endfunction

function! wilder#python_basic_highlighter(...) abort
  let l:opts = get(a:, 1, {})
  let l:opts.language = 'python'
  return wilder#highlighter#basic_highlighter(l:opts)
endfunction

function! wilder#pcre2_highlighter(...) abort
  let l:opts = get(a:, 1, {})
  return wilder#highlighter#pcre2_highlighter(l:opts)
endfunction

function! wilder#python_pcre2_highlighter(...) abort
  let l:opts = get(a:, 1, {})
  let l:opts.language = 'python'
  return wilder#highlighter#pcre2_highlighter(l:opts)
endfunction

function! wilder#lua_pcre2_highlighter(...) abort
  let l:opts = get(a:, 1, {})
  let l:opts.language = 'lua'
  return wilder#highlighter#pcre2_highlighter(l:opts)
endfunction

" DEPRECATED: use wilder#pcre2_highlighter()
function! wilder#pcre2_capture_spans(...) abort
  return call('wilder#pcre2_highlighter', a:000)
endfunction

function! wilder#cpsm_highlighter(...) abort
  return call('wilder#python_cpsm_highlighter', a:000)
endfunction

function! wilder#python_cpsm_highlighter(...) abort
  let l:opts = get(a:, 1, {})
  return wilder#highlighter#python_cpsm_highlighter(l:opts)
endfunction

function! wilder#lua_fzy_highlighter(...) abort
  return wilder#highlighter#lua_fzy_highlighter()
endfunction

function! wilder#highlighter_with_gradient(highlighter) abort
  return wilder#highlighter#highlighter_with_gradient(a:highlighter)
endfunction

" pipes

function! wilder#_sleep(t) abort
  " lambda functions do not have func-abort
  " so it is possible for timer_start to throw an error
  " followed by resolve being called
  return {_, x -> {ctx -> timer_start(a:t, {-> wilder#resolve(ctx, x)})}}
endfunction

function! wilder#branch(...) abort
  return wilder#pipe#branch#(a:000)
endfunction

function! wilder#map(...) abort
  return wilder#pipe#map#(a:000)
endfunction

function! wilder#subpipeline(f) abort
  return wilder#pipe#subpipeline#(a:f)
endfunction

function! wilder#check(...) abort
  return wilder#pipe#check#(a:000)
endfunction

function! wilder#if(condition, p) abort
  if !a:condition
    return {_, x -> x}
  endif

  return {ctx, x -> a:p(ctx, x)}
endfunction

function! wilder#debounce(t) abort
  return wilder#pipe#debounce#(a:t)
endfunction

function! wilder#result(...) abort
  if !a:0
    return wilder#pipe#result#()
  else
    return wilder#pipe#result#(a:1)
  endif
endfunction

function! wilder#result_output_escape(chars) abort
  return wilder#pipe#result#escape_output_result(a:chars)
endfunction

" DEPRECATED: Use wilder#vim_substring_pattern()
function! wilder#vim_substring() abort
  return call('wilder#vim_substring_pattern', [])
endfunction

function! wilder#vim_substring_pattern() abort
  return {_, x -> x . (x[-1:] ==# '\' ? '\' : '') . '\k*'}
endfunction

function! wilder#vim_search(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#pipe#vim_search#(l:args)
endfunction

function! wilder#escape_python(str, ...) abort
  let l:escaped_chars = get(a:, 1, '^$*+?|(){}[]')

  let l:chars = split(a:str, '\zs')
  let l:res = ''

  let l:i = 0
  while l:i < len(l:chars)
    let l:char = l:chars[l:i]
    if l:char ==# '\'
      if l:i+1 < len(l:chars)
        let l:res .= '\' . l:chars[l:i+1]
        let l:i += 2
      else
        let l:res .= '\\'
        let l:i += 1
      endif
    elseif stridx(l:escaped_chars, l:char) != -1
      let l:res .= '\' . l:char
      let l:i += 1
    else
      let l:res .= l:char
      let l:i += 1
    endif
  endwhile

  return l:res
endfunction

" DEPRECATED: Use wilder#python_substring_pattern()
function! wilder#python_substring() abort
  return call('wilder#python_substring_pattern', [])
endfunction

function! wilder#python_substring_pattern() abort
  return {_, x -> '(' . wilder#escape_python(x) . ')\w*'}
endfunction

" DEPRECATED: Use wilder#python_fuzzy_pattern()
function! wilder#python_fuzzy_match(...) abort
  return call('wilder#python_fuzzy_pattern', a:000)
endfunction

function! wilder#python_fuzzy_pattern(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#pipe#python_fuzzy_match#(l:args)
endfunction

" DEPRECATED: Use wilder#python_fuzzy_delimiter_pattern()
function! wilder#python_fuzzy_delimiter(...) abort
  return call('wilder#python_fuzzy_delimiter_pattern', a:000)
endfunction

function! wilder#python_fuzzy_delimiter_pattern(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#pipe#python_fuzzy_delimiter#(l:args)
endfunction

function! wilder#python_search(...) abort
  let l:opts = a:0 > 0 ? a:1 : {}
  return {_, x -> {ctx -> _wilder_python_search(ctx, l:opts, x)}}
endfunction

function! wilder#_python_sleep(t) abort
  return {_, x -> {ctx -> _wilder_python_sleep(ctx, a:t, x)}}
endfunction

function! wilder#history(...) abort
  if !a:0
    return wilder#pipe#history#()
  elseif a:0 == 1
    return wilder#pipe#history#(a:1)
  else
    return wilder#pipe#history#(a:1, a:2)
  endif
endfunction

" sorters

" DEPRECATED: Use wilder#lexical_sorter()
function! wilder#vim_sort() abort
  return call('wilder#lexical_sorter', [])
endfunction

function! wilder#lexical_sorter() abort
  return call('wilder#transform#lexical_sorter', [])
endfunction

function! wilder#lexical_sort(...) abort
  return call('wilder#transform#lexical_sort', a:000)
endfunction

" DEPRECATED: Use wilder#python_lexical_sorter()
function! wilder#python_sort() abort
  return call('wilder#python_lexical_sorter', [])
endfunction

function! wilder#python_lexical_sorter() abort
  return call('wilder#transform#python_lexical_sorter', [])
endfunction

function! wilder#python_lexical_sort(...) abort
  return call('wilder#transform#python_lexical_sort', a:000)
endfunction

" DEPRECATED: Use wilder#python_difflib_sorter()
function! wilder#python_sorter_difflib(...) abort
  return call('wilder#python_difflib_sorter', a:000)
endfunction

function! wilder#python_difflib_sorter(...) abort
  return call('wilder#transform#python_difflib_sorter', a:000)
endfunction

function! wilder#python_difflib_sort(...) abort
  return call('wilder#transform#python_difflib_sort', a:000)
endfunction

" DEPRECATED: Use wilder#python_fuzzywuzzy_sorter()
function! wilder#python_sorter_fuzzywuzzy(...) abort
  return call('wilder#python_fuzzywuzzy_sorter', a:000)
endfunction

function! wilder#python_fuzzywuzzy_sorter(...) abort
  return call('wilder#transform#python_fuzzywuzzy_sorter', a:000)
endfunction

" DEPRECATED: use wilder#python_fuzzywuzzy_sort()
function! wilder#python_fuzzywuzzy(ctx, xs, query) abort
  return call('wilder#python_fuzzywuzzy_sort', [a:ctx, {}, a:xs, a:query])
endfunction

function! wilder#python_fuzzywuzzy_sort(...) abort
  return call('wilder#transform#python_fuzzywuzzy_sort', a:000)
endfunction

" filters

" DEPRECATED: use wilder#uniq_filter()
function! wilder#uniq() abort
  return call('wilder#uniq_filter', [])
endfunction

function! wilder#uniq_filter() abort
  return call('wilder#transform#uniq_filter', [])
endfunction

function! wilder#uniq_filt(...) abort
  return call('wilder#transform#uniq_filt', a:000)
endfunction

" DEPRECATED: use wilder#python_uniq_filter()
function! wilder#python_uniq() abort
  return call('wilder#python_uniq_filter', [])
endfunction

function! wilder#python_uniq_filter() abort
  return call('wilder#transform#python_uniq_filter', [])
endfunction

function! wilder#python_uniq_filt(...) abort
  return call('wilder#transform#python_uniq_filt', a:000)
endfunction

" DEPRECATED: use wilder#fuzzy_filter()
function! wilder#filter_fuzzy() abort
  return call('wilder#fuzzy_filter', [])
endfunction

function! wilder#fuzzy_filter(...) abort
  return call('wilder#transform#fuzzy_filter', a:000)
endfunction

function! wilder#fuzzy_filt(...) abort
  return call('wilder#transform#fuzzy_filt', a:000)
endfunction

function! wilder#vim_fuzzy_filter() abort
  return call('wilder#transform#vim_fuzzy_filter', [])
endfunction

function! wilder#vim_fuzzy_filt(...) abort
  return call('wilder#transform#vim_fuzzy_filt', a:000)
endfunction

" DEPRECATED: use wilder#python_fuzzy_filter()
function! wilder#python_filter_fuzzy(...) abort
  return call('wilder#python_fuzzy_filter', a:000)
endfunction

function! wilder#python_fuzzy_filter(...) abort
  return call('wilder#transform#python_fuzzy_filter', a:000)
endfunction

function! wilder#python_fuzzy_filt(...) abort
  return call('wilder#transform#python_fuzzy_filt', a:000)
endfunction

" DEPRECATED: use wilder#python_fruzzy_filter()
function! wilder#python_filter_fruzzy(...) abort
  return call('wilder#python_fruzzy_filter', a:000)
endfunction

function! wilder#python_fruzzy_filter(...) abort
  return call('wilder#transform#python_fruzzy_filter', a:000)
endfunction

function! wilder#python_fruzzy_filt(...) abort
  return call('wilder#transform#python_fruzzy_filt', a:000)
endfunction

" DEPRECATED: use wilder#python_cpsm_filter()
function! wilder#python_filter_cpsm(...) abort
  return call('wilder#python_cpsm_filter', a:000)
endfunction

function! wilder#python_cpsm_filter(...) abort
  return call('wilder#transform#python_cpsm_filter', a:000)
endfunction

function! wilder#python_cpsm_filt(...) abort
  return call('wilder#transform#python_cpsm_filt', a:000)
endfunction

function! wilder#python_clap_filter(...) abort
  return call('wilder#transform#python_clap_filter', a:000)
endfunction

function! wilder#python_clap_filt(...) abort
  return call('wilder#transform#python_clap_filt', a:000)
endfunction

function! wilder#lua_fzy_filter() abort
  return call('wilder#transform#lua_fzy_filter', [])
endfunction

function! wilder#lua_fzy_filt(...) abort
  return call('wilder#transform#lua_fzy_filt', a:000)
endfunction

" pipelines

function! wilder#search_pipeline(...) abort
  let l:opts = get(a:, 1, {})

  return wilder#options#get('use_python_remote_plugin') ?
        \ wilder#python_search_pipeline(l:opts) :
        \ wilder#vim_search_pipeline(l:opts)
endfunction

function! s:search_pipeline(...) abort
  let l:opts = a:0 > 0 ? a:1 : {}

  let l:search_pipeline = get(l:opts, 'pipeline', [
        \ wilder#vim_substring(),
        \ wilder#vim_search(),
        \ wilder#result_output_escape('^$*~[]/\'),
        \ ])

  let l:skip_cmdtype_check = get(l:opts, 'skip_cmdtype_check', 0)

  let l:should_debounce = get(l:opts, 'debounce', 0) > 0
  let l:Debounce = l:should_debounce ? wilder#debounce(l:opts['debounce']) : 0

  return [
        \ wilder#if(!l:skip_cmdtype_check,
        \   wilder#check({-> getcmdtype() ==# '/' || getcmdtype() ==# '?'})),
        \ wilder#if(l:should_debounce, l:Debounce),
        \ wilder#subpipeline({ctx, x -> l:search_pipeline + [
        \  wilder#result({
        \    'data': {ctx, data -> s:set_query(data, x)},
        \  }),
        \ ]})
        \ ]
endfunction

function! s:set_query(data, x)
  let l:data = a:data is v:null ? {} : a:data
  if has_key(l:data, 'query')
    return a:data
  endif

  return extend(l:data, {'query': a:x})
endfunction

function! wilder#vim_search_pipeline(...) abort
  return s:search_pipeline(get(a:, 1, {}))
endfunction

function! wilder#python_search_pipeline(...) abort
  let l:opts = get(a:, 1, {})

  let l:Pattern = get(l:opts, 'pattern', get(l:opts, 'regex', 'substring'))
  if type(l:Pattern) is v:t_func
    " pass
  elseif l:Pattern ==# 'fuzzy'
    let l:Pattern = wilder#python_fuzzy_pattern()
  elseif l:Pattern ==# 'fuzzy_delimiter'
    let l:Pattern = wilder#python_fuzzy_delimiter_pattern()
  else
    let l:Pattern = wilder#python_substring_pattern()
  endif

  let l:Sorter = get(l:opts, 'sorter', get(l:opts, 'sort', 0))

  let l:pipeline = [
        \ l:Pattern,
        \ wilder#subpipeline({ctx, x -> [
        \   wilder#python_search(s:extract_keys(l:opts, 'max_candidates', 'engine')),
        \   wilder#if(l:Sorter isnot 0, {ctx, xs -> l:Sorter(ctx, xs, ctx.input)}),
        \   wilder#result_output_escape('^$*~[]/\'),
        \   wilder#result({'data': {'pcre2.pattern': x}}),
        \ ]}),
        \ ]

  return s:search_pipeline({
        \ 'debounce': get(l:opts, 'debounce', 0),
        \ 'pipeline': l:pipeline,
        \ 'skip_cmdtype_check': get(l:opts, 'skip_cmdtype_check', 0),
        \ })
endfunction

function! wilder#cmdline_pipeline(...) abort
  return wilder#cmdline#pipeline(get(a:, 1, {}))
endfunction

function! wilder#substitute_pipeline(...) abort
  return wilder#cmdline#substitute_pipeline(get(a:, 1, {}))
endfunction

function! wilder#python_file_finder_pipeline(...) abort
  return wilder#cmdline#python_file_finder_pipeline(get(a:, 1, {}))
endfunction

" renderer items

" DEPRECATED: use wilder#wildmenu_index()
function! wilder#index(...) abort
  return call('wilder#wildmenu_index', a:000)
endfunction

function! wilder#wildmenu_index(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#renderer#component#wildmenu_index#(l:args)
endfunction

" DEPRECATED: use wilder#wildmenu_string()
function! wilder#string(str, ...) abort
  return call('wilder#wildmenu_string', [str] + a:000)
endfunction

function! wilder#wildmenu_string(str, ...) abort
  if a:0
    return [a:str, a:1]
  endif

  return a:str
endfunction

" DEPRECATED: use wilder#wildmenu_previous_arrow()
function! wilder#previous_arrow(...) abort
  return call('wilder#wildmenu_previous_arrow', a:000)
endfunction

function! wilder#wildmenu_previous_arrow(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#renderer#component#wildmenu_arrows#previous(l:args)
endfunction

" DEPRECATED: use wilder#wildmenu_next_arrow()
function! wilder#next_arrow(...) abort
  return call('wilder#wildmenu_next_arrow', a:000)
endfunction

function! wilder#wildmenu_next_arrow(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#renderer#component#wildmenu_arrows#next(l:args)
endfunction

" DEPRECATED: use wilder#wildmenu_powerline_separator()
function! wilder#separator(str, from, to, ...) abort
  return call('wilder#wildmenu_powerline_separator', [a:str, a:from, a:to] + a:000)
endfunction

" DEPRECATED: use wilder#wildmenu_powerline_separator()
function! wilder#powerline_separator(str, from, to, ...) abort
  return call('wilder#wildmenu_powerline_separator', [a:str, a:from, a:to] + a:000)
endfunction

function! wilder#wildmenu_powerline_separator(str, from, to, ...) abort
  if a:0
    return wilder#renderer#component#wildmenu_separator#(a:str, a:from, a:to, a:1)
  else
    return wilder#renderer#component#wildmenu_separator#(a:str, a:from, a:to)
  endif
endfunction

" DEPRECATED: use wilder#wildmenu_spinner()
function! wilder#spinner(...) abort
  return call('wilder#wildmenu_spinner', a:000)
endfunction

function! wilder#wildmenu_spinner(...) abort
  let l:args = a:0 > 0 ? a:1 : {}
  return wilder#renderer#component#wildmenu_spinner#(l:args)
endfunction

" DEPRECATED: use wilder#wildmenu_condition()
function! wilder#condition(predicate, if_true, ...) abort
  return call('wilder#wildmenu_condition', [a:predicate, a:if_true] + a:000)
endfunction

function! wilder#wildmenu_condition(predicate, if_true, ...) abort
  let l:if_false = a:0 > 0 ? a:1 : []
  return wilder#renderer#component#wildmenu_condition#(a:predicate, a:if_true, l:if_false)
endfunction

function! wilder#popupmenu_scrollbar(...) abort
  let l:args = get(a:, 1, {})
  return wilder#renderer#component#popupmenu_scrollbar#(l:args)
endfunction

function! wilder#popupmenu_spinner(...) abort
  let l:args = get(a:, 1, {})
  return wilder#renderer#component#popupmenu_spinner#(l:args)
endfunction

function! wilder#popupmenu_devicons(...) abort
  let l:args = get(a:, 1, {})
  return wilder#renderer#component#popupmenu_devicons#(l:args)
endfunction

function! wilder#popupmenu_buffer_flags(...) abort
  let l:args = get(a:, 1, {})
  return wilder#renderer#component#popupmenu_buffer_flags#(l:args)
endfunction

function! wilder#popupmenu_empty_message(...) abort
  let l:args = get(a:, 1, {})
  return wilder#renderer#component#popupmenu_empty_message#(l:args)
endfunction

function! wilder#popupmenu_empty_message_with_spinner(...) abort
  let l:args = get(a:, 1, {})
  return wilder#renderer#component#popupmenu_empty_message_with_spinner#(l:args)
endfunction

" renderers

function! wilder#renderer_mux(args)
  return wilder#renderer#mux#(a:args)
endfunction

" DEPRECATED: use wilder#wildmenu_renderer()
function! wilder#statusline_renderer(...)
  let l:args = a:0 > 0 ? a:1 : {}
  call extend(l:args, {'mode': 'statusline'})
  return wilder#wildmenu_renderer(l:args)
endfunction

" DEPRECATED: use wilder#wildmenu_renderer()
function! wilder#float_renderer(...)
  let l:args = a:0 > 0 ? a:1 : {}
  call extend(l:args, {'mode': 'float'})
  return wilder#wildmenu_renderer(l:args)
endfunction

function! wilder#wildmenu_renderer(...)
  let l:args = a:0 > 0 ? a:1 : {}

  if !has_key(l:args, 'mode')
    let l:args.mode = has('nvim-0.4') ? 'float' :
          \ exists('*popup_create') ? 'popup' :
          \ 'statusline'
  endif

  if l:args.mode ==# 'float' || l:args.mode ==# 'popup'
    return wilder#renderer#wildmenu_float_or_popup#(l:args)
  endif

  return wilder#renderer#wildmenu_statusline#(l:args)
endfunction

function! wilder#popupmenu_renderer(...)
  let l:args = get(a:, 1, {})

  if !has_key(l:args, 'mode')
    let l:args.mode = has('nvim-0.4') ? 'float' : 'popup'
  endif

  return wilder#renderer#popupmenu#(l:args)
endfunction

" DEPRECATED: use wilder#wildmenu_airline_theme()
function! wilder#airline_theme(...)
  return call('wilder#wildmenu_airline_theme', a:000)
endfunction

function! wilder#wildmenu_airline_theme(...)
  let l:args = get(a:, 1, {})
  return wilder#renderer#wildmenu_theme#airline_theme(l:args)
endfunction

" DEPRECATED: use wilder#wildmenu_lightline_theme()
function! wilder#lightline_theme(...)
  return call('wilder#wildmenu_lightline_theme', a:000)
endfunction

function! wilder#wildmenu_lightline_theme(...)
  let l:args = get(a:, 1, {})
  return wilder#renderer#wildmenu_theme#lightline_theme(l:args)
endfunction

function! wilder#popupmenu_border_theme(...)
  let l:args = get(a:, 1, {})
  return wilder#renderer#popupmenu_border_theme#(l:args)
endfunction

function! wilder#popupmenu_palette_theme(...)
  let l:args = get(a:, 1, {})

  return wilder#renderer#popupmenu_palette_theme#(l:args)
endfunction

function! s:find_function_script_file(f)
  try
    " ensure function is autoloaded
    silent call eval(a:f . '()')
  catch /E119/
    " success
  catch
    return ''
  endtry

  let l:output = execute('verbose function ' . a:f)
  let l:lines = split(l:output, '\n')
  if len(l:lines) < 2
    return ''
  endif

  let l:matches = matchlist(l:lines[1], 'Last set from \(.\+\) line \d\+$')
  if len(l:matches) < 2
    " verbose function output is different for older versions.
    let l:matches = matchlist(l:lines[1], 'Last set from \(.\+\)$')
    if len(l:matches) < 2
      return ''
    endif
  endif

  return l:matches[1]
endfunction

function! wilder#findfile(file) abort
  if exists('*nvim_get_runtime_file')
    let l:runtime_files = nvim_get_runtime_file(a:file, 0)
    return get(l:runtime_files, 0, '')
  endif

  return findfile(a:file, &rtp)
endfunction

function! s:get_module_path(file, use_cached)
  if !exists('s:module_path_cache')
    let s:module_path_cache = wilder#cache#cache()
  endif

  if !a:use_cached || !s:module_path_cache.has_key(a:file)
    let l:file = wilder#findfile(a:file)
    let l:path = fnamemodify(l:file, ':h')

    call s:module_path_cache.set(a:file, l:path)
  endif

  return s:module_path_cache.get(a:file)
endfunction

function! wilder#fruzzy_path(...) abort
  return s:get_module_path('rplugin/python3/fruzzy.py', get(a:, 1, 1))
endfunction

function! wilder#cpsm_path(...) abort
  return s:get_module_path('autoload/cpsm.py', get(a:, 1, 1))
endfunction

function! wilder#clap_path(...) abort
  return s:get_module_path('pythonx/clap/scorer.py', get(a:, 1, 1))
endfunction

function! wilder#clear_module_path_cache()
  if !exists('s:module_path_cache')
    let s:module_path_cache = wilder#cache#cache()
  endif

  call s:module_path_cache.clear()
endfunction

function! wilder#project_root(...) abort
  if !exists('s:project_root_cache')
    let s:project_root_cache = wilder#cache#cache()
  endif

  if a:0
    let l:root_markers = a:1
  else
    let l:root_markers = ['.hg', '.git']
  endif

  return {-> s:project_root(l:root_markers)}
endfunction

function! wilder#clear_project_root_cache() abort
  if !exists('s:project_root_cache')
    let s:project_root_cache = wilder#cache#cache()
  endif

  call s:project_root_cache.clear()
endfunction

function! s:project_root(root_markers, ...) abort
  if a:0
    let l:path = a:1
  else
    let l:path = getcwd()
  endif

  if !s:project_root_cache.has_key(l:path)
    let l:project_root = s:get_project_root(l:path, a:root_markers)
    call s:project_root_cache.set(l:path, l:project_root)
  endif

  return s:project_root_cache.get(l:path)
endfunction

function! s:get_project_root(path, root_markers) abort
  let l:home_directory = expand('~')
  let l:find_path = a:path . ';' . l:home_directory

  for l:root_marker in a:root_markers
    let l:result = findfile(l:root_marker, l:find_path)
    if empty(l:result)
      let l:result = finddir(l:root_marker, l:find_path)
    endif

    if empty(l:result)
      continue
    endif

    return fnamemodify(l:result, ':~:h')
  endfor

  return ''
endfunction

" DEPRECATED: This function is to be removed.
" Use wilder#popupmenu_devicons() instead.
function! wilder#result_draw_devicons()
  return wilder#result({
        \ 'draw': ['wilder#draw_devicons'],
        \ })
endfunction

function! wilder#draw_devicons(ctx, x, data) abort
  let l:expand = get(a:data, 'cmdline.expand', '')

  if l:expand !=# 'file' &&
        \ l:expand !=# 'file_in_path' &&
        \ l:expand !=# 'dir' &&
        \ l:expand !=# 'shellcmd' &&
        \ l:expand !=# 'buffer'
    return a:x
  endif

  let l:slash = !has('win32') && !has('win64')
        \ ? '/'
        \ : &shellslash
        \ ? '/'
        \ : '\'

  let l:is_dir = a:x[-1:] ==# l:slash

  return WebDevIconsGetFileTypeSymbol(a:x, l:is_dir) . ' ' . a:x
endfunction

function! wilder#devicons_get_icon_from_vim_devicons()
  return wilder#renderer#component#popupmenu_devicons#get_icon_from_vim_devicons()
endfunction

function! wilder#devicons_get_icon_from_nerdfont_vim()
  return wilder#renderer#component#popupmenu_devicons#get_icon_from_nerdfont_vim()
endfunction

function! wilder#devicons_get_icon_from_nvim_web_devicons(...)
  let l:opts = a:0 ? a:1 : {}
  return wilder#renderer#component#popupmenu_devicons#get_icon_from_nvim_web_devicons(l:opts)
endfunction

function! wilder#devicons_get_hl_from_glyph_palette_vim(...)
  let l:opts = a:0 ? a:1 : {}
  return wilder#renderer#component#popupmenu_devicons#get_hl_from_glyph_palette_vim(l:opts)
endfunction

function! wilder#devicons_get_hl_from_nvim_web_devicons(...)
  let l:opts = a:0 ? a:1 : {}
  return wilder#renderer#component#popupmenu_devicons#get_hl_from_nvim_web_devicons(l:opts)
endfunction

function! s:extract_keys(obj, ...)
  let l:res = {}

  for l:key in a:000
    if has_key(a:obj, l:key)
      let l:res[l:key] = a:obj[l:key]
    endif
  endfor

  return l:res
endfunction

function! wilder#setup(...)
  return call('wilder#setup#', a:000)
endfunction
