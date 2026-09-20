let s:cmdline_cache = wilder#cache#mru_cache(30)

function! wilder#cmdline#parse(cmdline) abort
  if !s:cmdline_cache.has_key(a:cmdline)
    let l:ctx = {'cmdline': a:cmdline, 'pos': 0, 'cmd': '', 'expand': ''}
    call wilder#cmdline#main#do(l:ctx)

    let l:ctx['arg'] = l:ctx['cmdline'][l:ctx.pos :]
    let l:ctx['pos'] = l:ctx.pos
    call s:cmdline_cache.set(a:cmdline, l:ctx)
  endif

  return copy(s:cmdline_cache.get(a:cmdline))
endfunction

" match_arg  : the argument for the fuzzy filter to match against
" expand_arg : the argument passed to getcompletion()
" expand     : the type passed to getcompletion()
" fuzzy_char : the character used to get fuzzy completion if fuzzy mode is 1
function! wilder#cmdline#prepare_getcompletion(ctx, res, fuzzy, use_python) abort
  let a:res.match_arg = a:res.arg
  let a:res.expand_arg = has_key(a:res, 'subcommand_start')
        \ ? a:res.cmdline[a:res.subcommand_start :]
        \ : a:res.arg

  if !a:fuzzy
    if a:res.expand ==# 'tags' &&
          \ !empty(a:res.expand_arg) &&
          \ a:res.expand_arg[0] !=# '/'
      " Search taglist for tags starting with expand_arg
      let a:res.expand_arg = '/^' . a:res.expand_arg
    endif

    return a:res
  endif

  return s:prepare_fuzzy_completion(a:ctx, a:res, a:use_python)
endfunction

" Sets match_arg, expand_arg fuzzy_char based on expand and expand_arg. These
" will be used by wilder#cmdline#get_fuzzy_completion() to decide how to get
" the completions.
" Generally we want to use the first char in expand_arg as fuzzy_char,
" set match_arg to expand_arg, and adjust expand_arg to '' since we are only
" expanding the fuzzy char.
function! s:prepare_fuzzy_completion(ctx, res, use_python) abort
  " For non-python completion, a maximum of 300 help tags are returned, so
  " getting all the candidates and filtering will miss out on a lot of matches
  " If argument is empty, don't fuzzy match except for expanding 'help', where
  " the default argument is 'help'
  if (a:res.expand ==# 'help' && !a:use_python) ||
        \ a:res.pos == len(a:res.cmdline)
    return a:res
  endif

  " Remove the starting s: and g: so the fuzzy filter does not match against
  " that them.
  if (a:res.expand ==# 'expression' || a:res.expand ==# 'var') &&
        \ a:res.expand_arg[1] ==# ':' &&
        \ (a:res.expand_arg[0] ==# 'g' || a:res.expand_arg[0] ==# 's')
    let a:res.fuzzy_char = a:res.expand_arg[2]
    let a:res.match_arg = a:res.expand_arg[2 :]
    let a:res.expand_arg = a:res.expand_arg[0: 1]

  " For tag-regexp, keep the argument and don't do fuzzy matching
  elseif a:res.expand ==# 'tags' && a:res.expand_arg[0] ==# '/'
    let a:res.fuzzy_char = ''
    let a:res.match_arg = ''

  " Return all candidates and let the fuzzy filter remove the non-matching
  " candidates for the following cases:
  "
  " mapping: special keys such as <Space> cannot be fuzzy completed since
  " < will not get completions for <Space>.
  "
  " buffer: getcompletion() for buffers checks against the file name, but
  " we want to check against the full path.
  "
  " help: help tag matching does not have to start from beginning of word.
  elseif a:res.expand ==# 'mapping' ||
        \ a:res.expand ==# 'buffer' ||
        \ a:res.expand ==# 'help'
    " Default argument for help completion is 'help'
    if a:res.expand ==# 'help' && empty(a:res.expand_arg)
      let a:res.match_arg = 'help'
    else
      let a:res.match_arg = a:res.expand_arg
    endif

    let a:res.expand_arg = ''
    let a:res.fuzzy_char = ''
  else
    " Default case, expand with the fuzzy_char
    let a:res.fuzzy_char = strcharpart(a:res.expand_arg, 0, 1)
    let a:res.expand_arg = ''
  endif

  return a:res
endfunction

function! wilder#cmdline#prepare_file_completion(ctx, res, fuzzy)
  let l:res = copy(a:res)
  let l:arg = l:res.arg

  if l:res.expand ==# 'file_in_path'
    let l:res.fuzzy_char = ''
    let l:res.expand_arg = l:arg
    let l:res.match_arg = l:arg

    return l:res
  endif

  " Remove backslash preceding spaces.
  let l:arg = substitute(l:arg, '\\ ', ' ', 'g')

  let l:slash = !has('win32') && !has('win64')
        \ ? '/'
        \ : &shellslash
        \ ? '/'
        \ : '\'

  " Special handling for ~. Return the home directory.
  if l:arg ==# '~'
    let l:res.fuzzy_char = ''
    let l:res.expand_arg = ''
    let l:res.completions = [expand('~') . l:slash]

    return l:res
  endif

  let l:original_len = len(l:arg)

  " Expand the fnamemodify()-able part, if any.
  " ^(%|#|<cword>|<cWORD>|<client>)(:[phtre])*
  let l:matches = matchlist(l:arg,
        \ '^\(%\|#\|<cword>|<cWORD>|<client>\)' .
        \ '\(\%(:[phtre]\)*\)')
  if len(l:matches) > 0
    let l:part_to_fnamemodify = l:matches[0]
    let l:rest = l:arg[len(l:part_to_fnamemodify) :]
    let l:arg = expand(l:part_to_fnamemodify) . l:rest

    " Adjust current directory to empty string.
    if l:arg ==# '.'
      let l:arg = ''
    endif
  endif

  let l:allow_backslash = has('win32') || has('win64')

  " Pattern for matching directory separator.
  if !l:allow_backslash
    let l:dir_sep = l:slash
  else
    if l:slash ==# '\'
      let l:dir_sep = '\\'
    else
      let l:dir_sep = '/\|\\'
    endif
  endif

  " Handle wildcards.
  let l:first_wildcard = match(l:arg, '\*')
  if l:first_wildcard >= 0
    if l:first_wildcard > 0
      " Expand the portion before the wildcard since expand('foo/*') will glob
      " for matches.
      let l:before_wildcard = l:arg[: l:first_wildcard - 1]
      let l:after_wildcard = l:arg[l:first_wildcard :]

      let l:expand_arg = expand(l:before_wildcard) . l:after_wildcard
    else
      let l:expand_arg = l:arg
    endif

    " Don't use fuzzy matching for wildcards.
    let l:res.has_wildcard = 1
    let l:res.match_arg = ''
    let l:res.expand_arg = l:expand_arg

    return l:res
  endif

  " Split path into head and tail
  if match(l:arg, l:dir_sep) >= 0
    let l:head = fnamemodify(l:arg, ':h')
    let l:tail = fnamemodify(l:arg, ':t')
  else
    let l:head = ''
    let l:tail = l:arg
  endif

  " Check if tail is trying to complete an env var.
  let l:matches = matchlist(l:tail, '\$\(\f*\)$')
  if len(l:matches)
    let l:env_var = l:matches[1]
    let l:path_prefix = l:arg[:-len(l:env_var)-1]

    let l:res.path_prefix = l:path_prefix
    let l:res.expand = 'environment'
    let l:res.expand_arg = ''
    let l:res.fuzzy_char = ''
    let l:res.completions = map(getcompletion(l:env_var, 'environment'),
          \ {_, x -> l:path_prefix . x})

    " Get position of the $ in tail.
    let l:dollar_pos = len(l:tail) - len(l:env_var)

    " Show cursor after the $.
    let l:res.pos += l:original_len - len(l:tail) + l:dollar_pos

    return l:res
  endif

  " Append / back to l:head.
  if !empty(l:head)
    " Expand env vars.
    let l:head = s:expand_user_and_env_vars(l:head)

    " Don't add / if there is already an existing / since // is not
    " simplified - see :h simplify()).
    if l:head[-1:] !=# l:slash
      let l:head .= l:slash
    endif

    let l:head = simplify(l:head)
  endif

  let l:res.match_arg = l:tail

  " Don't trim leading / for absolute paths when drawing.
  let l:path_prefix = l:head ==# l:slash ? '' : l:head

  " If arg starts with ~/, show paths relative to ~.
  " head might no longer be under ~ e.g. simplify('~/../..')
  if l:arg[0] ==# '~' &&
        \ fnamemodify(l:head, ':~')[0] ==# '~' &&
        \ match(l:arg[1], l:dir_sep) == 0
    let l:res.relative_to_home_dir = 1
    let l:res.path_prefix = fnamemodify(l:path_prefix, ':~')
  else
    let l:res.path_prefix = l:path_prefix
  endif

  if a:fuzzy
    let l:res.expand_arg = l:head
    let l:res.fuzzy_char = strcharpart(l:tail, 0, 1)
  else
    let l:res.expand_arg = l:head . l:tail
    let l:res.fuzzy_char = ''
  endif

  if !empty(l:head)
    " Show cursor at the start of tail.
    let l:res.pos += l:original_len - len(l:tail)
  endif

  return l:res
endfunction

function! wilder#cmdline#get_fuzzy_completion(ctx, res, getcompletion, fuzzy_mode, use_python) abort
  " Use tag-regexp to get fuzzy completions from taglist()
  if a:res.expand ==# 'tags'
    let l:fuzzy_char = get(a:res, 'fuzzy_char', '')

    if empty(l:fuzzy_char)
      let a:res.expand_arg = '.'
    else
      let a:res.expand_arg = '/'
      if toupper(l:fuzzy_char) !=# l:fuzzy_char
        let a:res.expand_arg .= '\c'
      endif

      if a:fuzzy_mode == 1
        let a:res.expand_arg .= '^'
      endif

      let a:res.expand_arg .= l:fuzzy_char
    endif

    return a:getcompletion(a:ctx, a:res)
  endif

  " If argument is empty, use normal completions
  " Don't fuzzy complete for vim help since a maximum of 300 help tags are returned
  if a:res.pos == len(a:res.cmdline) ||
        \ (a:res.expand ==# 'help' && !a:use_python)
    return a:getcompletion(a:ctx, a:res)
  endif

  let l:fuzzy_char = get(a:res, 'fuzzy_char', '')

  " Keep leading . in file expansion to search hidden directories
  if a:fuzzy_mode == 2 &&
        \ !(wilder#cmdline#is_file_expansion(a:res.expand) && l:fuzzy_char ==# '.')
    let l:fuzzy_char = ''
  endif

  if toupper(l:fuzzy_char) ==# l:fuzzy_char
    let a:res.expand_arg = a:res.expand_arg . l:fuzzy_char
    return a:getcompletion(a:ctx, a:res)
  endif

  let l:lower_res = copy(a:res)
  let l:lower_res.expand_arg = a:res.expand_arg . l:fuzzy_char

  let l:upper_res = copy(a:res)
  let l:upper_res.expand_arg = a:res.expand_arg . toupper(l:fuzzy_char)

  return wilder#wait(a:getcompletion(a:ctx, l:upper_res),
        \ {ctx, upper_xs -> wilder#resolve(ctx, wilder#wait(a:getcompletion(ctx, l:lower_res),
        \ {ctx, lower_xs -> wilder#resolve(ctx, wilder#uniq_filt(0, 0, lower_xs + upper_xs))}))})
endfunction

let s:cached_tags = {}
let s:cached_tags_session_id = -1

function! wilder#cmdline#python_get_file_completion(ctx, res) abort
  if has_key(a:res, 'completions')
    return a:res['completions']
  endif

  let l:expand_arg = a:res.expand_arg

  if a:res.expand ==# 'dir' ||
        \ a:res.expand ==# 'file' ||
        \ a:res.expand ==# 'file_in_path' ||
        \ a:res.expand ==# 'shellcmd'
    return {ctx -> _wilder_python_get_file_completion(
          \ ctx,
          \ l:expand_arg,
          \ a:res.expand,
          \ get(a:res, 'has_wildcard', 0),
          \ get(a:res, 'path_prefix', ''),
          \ )}
  endif

  if a:res.expand ==# 'user'
    return {ctx -> _wilder_python_get_users(ctx, l:expand_arg, a:res.expand)}
  endif

  return []
endfunction

function! wilder#cmdline#getcompletion(ctx, res) abort
  if has_key(a:res, 'completions')
    return a:res['completions']
  endif

  let l:expand_arg = a:res.expand_arg

  " getting all shellcmds takes a significant amount of time
  if a:res.expand ==# 'shellcmd' && empty(l:expand_arg)
    return []
  endif

  if a:res.expand ==# 'dir' ||
        \ a:res.expand ==# 'file' ||
        \ a:res.expand ==# 'file_in_path' ||
        \ a:res.expand ==# 'shellcmd'

    if get(a:res, 'has_wildcard', 0)
      let l:xs = expand(l:expand_arg, 0, 1)

      if len(l:xs) == 1 && l:xs[0] ==# l:expand_arg
        return []
      endif

      return l:xs
    endif

    return getcompletion(l:expand_arg, a:res.expand, 1)
  endif

  if a:res.expand ==# 'nothing' || a:res.expand ==# 'unsuccessful'
    return []
  elseif a:res.expand ==# 'augroup'
    return getcompletion(l:expand_arg, 'augroup')
  elseif a:res.expand ==# 'arglist'
    return getcompletion(l:expand_arg, 'arglist')
  elseif a:res.expand ==# 'behave'
    return getcompletion(l:expand_arg, 'behave')
  elseif a:res.expand ==# 'buffer'
    let l:buffers = getcompletion(l:expand_arg, 'buffer')
    return map(l:buffers, {_, x -> fnamemodify(x, ':~:.')})
  elseif a:res.expand ==# 'checkhealth'
    return has('nvim') ? getcompletion(l:expand_arg, 'checkhealth') : []
  elseif a:res.expand ==# 'color'
    return getcompletion(l:expand_arg, 'color')
  elseif a:res.expand ==# 'command'
    return getcompletion(l:expand_arg, 'command')
  elseif a:res.expand ==# 'compiler'
    return getcompletion(l:expand_arg, 'compiler')
  elseif a:res.expand ==# 'cscope'
    return getcompletion(a:res.cmdline[a:res.subcommand_start :], 'cscope')
  elseif a:res.expand ==# 'event'
    return getcompletion(l:expand_arg, 'event')
  elseif a:res.expand ==# 'event_and_augroup'
    return getcompletion(l:expand_arg, 'event') + getcompletion(l:expand_arg, 'augroup')
  elseif a:res.expand ==# 'expression'
    return getcompletion(l:expand_arg, 'expression')
  elseif a:res.expand ==# 'environment'
    return getcompletion(l:expand_arg, 'environment')
  elseif a:res.expand ==# 'file_opt'
    let l:opts = ['bad', 'bin', 'enc', 'ff', 'nobin']
    if a:res.cmd ==# 'read'
      call insert(l:opts, 'edit', 2)
    endif

    return filter(l:opts, {_, x -> s:is_prefix(x, l:expand_arg)})
  elseif a:res.expand ==# 'function'
    return getcompletion(l:expand_arg, 'function')
  elseif a:res.expand ==# 'help'
    return getcompletion(l:expand_arg, 'help')
  elseif a:res.expand ==# 'highlight'
    return getcompletion(l:expand_arg, 'highlight')
  elseif a:res.expand ==# 'history'
    return getcompletion(l:expand_arg, 'history')
  elseif a:res.expand ==# 'language'
    return getcompletion(l:expand_arg, 'locale') +
          \ filter(['ctype', 'messages', 'time'], {_, x -> s:is_prefix(x, l:expand_arg)})
  elseif a:res.expand ==# 'locale'
    return getcompletion(l:expand_arg, 'locale')
  elseif a:res.expand ==# 'lua'
    " Lua completion handled by s:get_lua_completion()
    return []
  elseif a:res.expand ==# 'mapping'
    let l:map_args = get(a:res, 'map_args', {})

    let l:result = []

    if l:expand_arg ==# '' || l:expand_arg[0] ==# '<'
      for l:map_arg in ['<buffer>', '<unique>', '<nowait>', '<silent>',
            \ '<special>', '<script>', '<expr>']
        if !has_key(l:map_args, l:map_arg)
          call add(l:result, l:map_arg)
        endif
      endfor

      if l:expand_arg[0] ==# '<'
        call filter(l:result, {_, x -> s:is_prefix(x, l:expand_arg)})
      endif
    endif

    if a:res.cmd[-5 :] ==# 'unmap'
      let l:mode = a:res.cmd ==# 'unmap' ? '' : a:res.cmd[0]
      let l:cmd = 'map'
    elseif a:res.cmd[-3 :] ==# 'map'
      let l:mode = a:res.cmd ==# 'map' || a:res.cmd ==# 'noremap' ? '' : a:res.cmd[0]
      let l:cmd = 'map'
    elseif a:res.cmd[-12 :] ==# 'unabbreviate'
      let l:mode = a:res.cmd ==# 'unabbreviate' ? '' : a:res.cmd[0]
      let l:cmd = 'abbrev'
    elseif a:res.cmd ==# 'abbreviate'
      let l:mode = ''
      let l:cmd = 'abbrev'
    elseif a:res.cmd[-6 :] ==# 'abbrev'
      let l:mode = a:res.cmd ==# 'noreabbrev' ? '' : a:res.cmd[0]
      let l:cmd = 'abbrev'
    else
      let l:mode = ''
      let l:cmd = 'map'
    endif

    let l:lines = split(execute(l:mode . l:cmd . ' ' . join(keys(l:map_args), ' ') .
          \ ' ' . l:expand_arg), "\n")

    if len(l:lines) != 1 ||
          \ (l:lines[0] !=# 'No mapping found' &&
          \ l:lines[0] !=# 'No abbreviation found')
      for l:line in l:lines
        let l:words = split(l:line,'\s\+')
        if l:line[0] ==# ' '
          let l:map_lhs = l:words[0]
        else
          let l:map_lhs = l:words[1]
        endif

        call add(l:result, l:map_lhs)
      endfor
    endif

    return wilder#uniq_filt(0, 0, l:result)
  elseif a:res.expand ==# 'mapclear'
    return s:is_prefix('<buffer>', l:expand_arg) ? ['<buffer>'] : []
  elseif a:res.expand ==# 'menu'
    if !has_key(a:res, 'menu_arg')
      return []
    endif
    return getcompletion(a:res.menu_arg, 'menu')
  elseif a:res.expand ==# 'messages'
    return getcompletion(l:expand_arg, 'messages')
  elseif a:res.expand ==# 'option'
    return getcompletion(l:expand_arg, 'option')
  elseif a:res.expand ==# 'option_bool'
    return filter(wilder#cmdline#set#get_bool_options(),
          \ {_, x -> s:is_prefix(x, l:expand_arg)})
  elseif a:res.expand ==# 'option_old'
    let l:old_option = eval('&' . a:res.option)
    return [type(l:old_option) is v:t_string ? l:old_option : string(l:old_option)]
  elseif a:res.expand ==# 'packadd'
    return getcompletion(l:expand_arg, 'packadd')
  elseif a:res.expand ==# 'profile'
    return filter(['continue', 'dump', 'file', 'func', 'pause', 'start'],
          \ {_, x -> s:is_prefix(x, l:expand_arg)})
  elseif a:res.expand ==# 'ownsyntax'
    return getcompletion(l:expand_arg, 'syntax')
  elseif a:res.expand ==# 'shellcmd'
    return getcompletion(l:expand_arg, 'shellcmd')
  elseif a:res.expand ==# 'sign'
    return getcompletion(a:res.cmdline[a:res.subcommand_start :], 'sign')
  elseif a:res.expand ==# 'syntax'
    return getcompletion(l:expand_arg, 'syntax')
  elseif a:res.expand ==# 'syntax_subcommand'
    return filter(['case', 'clear', 'cluster', 'conceal',
          \ 'enable', 'foldlevel', 'include', 'iskeyword',
          \ 'keyword', 'list', 'manual', 'match', 'off',
          \ 'on', 'region', 'reset', 'spell', 'sync'], {_, x -> s:is_prefix(x, l:expand_arg)})
    return getcompletion(l:expand_arg, 'syntax')
  elseif a:res.expand ==# 'syntime'
    return getcompletion(l:expand_arg, 'syntime')
  elseif a:res.expand ==# 'user'
    return getcompletion(l:expand_arg, 'user')
  elseif a:res.expand ==# 'user_func'
    let l:functions = getcompletion(l:expand_arg, 'function')
    let l:functions = filter(l:functions, {_, x -> !(x[0] >= 'a' && x[0] <= 'z')})
    return map(l:functions, {_, x -> x[-1 :] ==# ')' ? x[: -3] : x[: -2]})
  elseif a:res.expand ==# 'user_addr_type'
    return filter(['arguments', 'buffers', 'lines', 'loaded_buffers',
          \ 'quickfix', 'tabs', 'windows'], {_, x -> s:is_prefix(x, l:expand_arg)})
  elseif a:res.expand ==# 'user_cmd_flags'
    return filter(['addr', 'bar', 'buffer', 'complete', 'count',
          \ 'nargs', 'range', 'register'], {_, x -> s:is_prefix(x, l:expand_arg)})
  elseif a:res.expand ==# 'user_complete'
    return filter(['arglist', 'augroup', 'behave', 'buffer', 'checkhealth',
          \ 'color', 'command', 'compiler', 'cscope', 'custom',
          \ 'customlist', 'dir', 'environment', 'event', 'expression',
          \ 'file', 'file_in_path', 'filetype', 'function', 'help',
          \ 'highlight', 'history', 'locale', 'mapclear', 'mapping',
          \ 'menu', 'messages', 'option', 'packadd', 'shellcmd',
          \ 'sign', 'syntax', 'syntime', 'tag', 'tag_listfiles',
          \ 'user', 'var'], {_, x -> s:is_prefix(x, l:expand_arg)})
  elseif a:res.expand ==# 'user_nargs'
    if empty(l:expand_arg)
      return ['*', '+', '0', '1', '?']
    endif

    if l:expand_arg ==# '*' || l:expand_arg ==# '+' || l:expand_arg ==# '0' ||
          \ l:expand_arg ==# '1' || l:expand_arg ==# '?'
      return [l:expand_arg]
    endif

    return []
  elseif a:res.expand ==# 'user_commands'
    return filter(getcompletion(l:expand_arg, 'command'), {_, x -> x[0] >=# 'A' && x[0] <=# 'Z'})
  elseif a:res.expand ==# 'tags'
    if a:ctx.session_id > s:cached_tags_session_id
      let s:cached_tags_session_id = a:ctx.session_id
      let s:cached_tags = {}
    endif

    let l:arg = a:res.expand_arg
    if l:arg[0] ==# '/'
      let l:taglist_arg = l:arg[1:]
    else
      let l:taglist_arg = l:arg
    endif

    if empty(l:taglist_arg)
      let l:taglist_arg = '.'
    endif

    if !has_key(s:cached_tags, l:taglist_arg)
      let s:cached_tags[l:taglist_arg] = map(taglist(l:taglist_arg), {_, x -> x.name})
    endif

    return copy(s:cached_tags[l:taglist_arg])
  elseif a:res.expand ==# 'var'
    return getcompletion(l:expand_arg, 'var')
  endif

  if !exists('s:has_get_completion_cmdline')
    try
      " cmdline completion only available in Vim 8.2+
      call getcompletion('foo', 'cmdline')
      let s:has_getcompletion_cmdline = 1
    catch
      let s:has_getcompletion_cmdline = 0
    endtry
  endif

  " fallback to cmdline getcompletion
  if s:has_getcompletion_cmdline
    return getcompletion(a:res.cmdline, 'cmdline')
  endif

  return []
endfunction

function! wilder#cmdline#is_file_expansion(expand) abort
  return a:expand ==# 'file' ||
        \ a:expand ==# 'file_in_path' ||
        \ a:expand ==# 'dir' ||
        \ a:expand ==# 'shellcmd' ||
        \ a:expand ==# 'user'
endfunction

function! wilder#cmdline#is_user_command(cmd) abort
  return !empty(a:cmd) && a:cmd[0] >=# 'A' && a:cmd[0] <=# 'Z'
endfunction

let s:cached_commands_session_id = -1
let s:has_completion_error = {}
let s:cached_user_commands = {}

" returns [{handled}, {result}, {res}[, {need_filter}]]
function! wilder#cmdline#prepare_user_completion(ctx, res) abort
  if !wilder#cmdline#is_user_command(a:res.cmd)
    return [0, 0, a:res]
  endif

  if !has('nvim')
    return [1, v:true, a:res]
  endif

  if a:ctx.session_id > s:cached_commands_session_id
    let s:cached_commands_session_id = a:ctx.session_id
    let s:cached_user_commands = extend(nvim_get_commands({}), nvim_buf_get_commands(0, {}))
    let s:has_completion_error = {}
  endif

  " Calling getcompletion() interferes with wildmenu command completion so
  " we return v:true early
  if has_key(s:has_completion_error, a:res.cmd)
    let l:res = copy(a:res)
    let l:res.pos = 0
    return [1, v:true, l:res]
  endif

  if has_key(s:cached_user_commands, a:res.cmd)
    let l:command = a:res.cmd
  else
    " Command might be a partial name
    let l:matches = getcompletion(a:res.cmd, 'command')

    " 2 or more matches indicates command is ambiguous
    if len(l:matches) >= 2
      throw "Ambiguous use of user-defined command, possible matches: " . string(l:matches)
    elseif len(l:matches) == 0
      return [1, [], a:res, 0]
    endif

    let l:command = l:matches[0]
  endif

  let l:user_command = s:cached_user_commands[l:command]

  if has_key(l:user_command, 'complete_arg') &&
        \ l:user_command.complete_arg isnot v:null

    " Find last argument by looking for the last whitespace character
    let l:pos = len(a:res.cmdline)
    while l:pos >= a:res.pos
      if a:res.cmdline[l:pos] ==# ' ' || a:res.cmdline[l:pos] ==# "\t"
        break
      endif

      let l:pos -= 1
    endwhile

    let l:arg = a:res.cmdline[l:pos+1 :]

    try
      let l:function_name = l:user_command.complete_arg
      if l:function_name[:1] ==# 's:'
        let l:function_name = '<SNR>' . l:user_command.script_id . '_' . l:function_name[2:]
      elseif l:function_name[:4] ==? '<SID>'
        let l:function_name = '<SNR>' . l:user_command.script_id . '_' . l:function_name[5:]
      endif

      let l:Completion_func = function(l:function_name)
      let l:result = l:Completion_func(l:arg, a:res.cmdline, len(a:res.cmdline))
    catch
      " Add both the full command and partial command
      let s:has_completion_error[l:command] = 1
      let s:has_completion_error[a:res.cmd] = 1

      let l:res = copy(a:res)
      let l:res.pos = 0
      return [1, v:true, l:res]
    endtry

    let l:is_custom_list = get(l:user_command, 'complete', '') ==# 'customlist'
    if !l:is_custom_list
      let l:result = split(l:result, '\n')
    endif

    let l:res = copy(a:res)
    let l:res.pos = l:pos
    let l:res.match_arg = l:arg
    if !l:is_custom_list
      let l:res.arg = l:arg
    endif

    return [1, l:result, l:res, !l:is_custom_list]
  endif

  if has_key(l:user_command, 'complete') &&
        \ l:user_command['complete'] isnot v:null &&
        \ l:user_command['complete'] !=# 'custom' &&
        \ l:user_command['complete'] !=# 'customlist'
    let l:res = copy(a:res)
    let l:res['expand'] = l:user_command['complete']

    return [0, 0, l:res]
  endif

  return [1, v:false, a:res]
endfunction

function! wilder#cmdline#replace(ctx, x, data) abort
  let l:result = wilder#cmdline#parse(a:ctx.cmdline)

  if l:result.pos == 0
    return a:x
  endif

  if wilder#cmdline#is_user_command(l:result.cmd)
    let l:pos = len(l:result.cmdline)
    while l:pos >= l:result.pos
      if l:result.cmdline[l:pos] ==# ' ' || l:result.cmdline[l:pos] ==# "\t"
        break
      endif

      let l:pos -= 1
    endwhile
  else
    let l:pos = l:result.pos - 1
  endif

  return l:result.cmdline[: l:pos] . a:x
endfunction

function! wilder#cmdline#draw_path(ctx, x, data) abort
  if get(a:data, 'cmdline.expand', '') ==# 'file_in_path'
    return a:x
  endif

  let l:path_prefix = get(a:data, 'cmdline.path_prefix', '')
  return a:x[len(l:path_prefix) :]
endfunction

function! s:convert_result_to_data(res)
  let l:data = {
        \ 'pos': a:res.pos,
        \ 'cmdline.command': a:res.cmd,
        \ 'cmdline.expand': a:res.expand,
        \ 'cmdline.arg': a:res.arg,
        \ }

  if has_key(a:res, 'path_prefix')
    let l:data['cmdline.path_prefix'] = a:res.path_prefix
  endif

  if has_key(a:res, 'match_arg')
    let l:data['cmdline.match_arg'] = a:res.match_arg
  endif

  if has_key(a:res, 'has_wildcard')
    let l:data['cmdline.has_wildcard'] = a:res.has_wildcard
  endif

  return l:data
endfunction

" Gets completions based on whether res, fuzzy and use_python
function! s:getcompletion(ctx, res, fuzzy, use_python) abort
  " For python file completions, use wilder#cmdline#python_get_file_completion()
  " For help tags, use _wilder_python_get_help_tags()
  " Else use wilder#cmdline#getcompletion()
  if a:use_python && wilder#cmdline#is_file_expansion(a:res.expand)
    let l:Completion_func = funcref('wilder#cmdline#python_get_file_completion')
  elseif a:use_python && a:res.expand ==# 'help' && a:fuzzy
    let l:Completion_func = {-> {ctx -> _wilder_python_get_help_tags(ctx, &rtp, &helplang)}}
  else
    let l:Completion_func = funcref('wilder#cmdline#getcompletion')
  endif

  " For tag-regexp, don't do fuzzy completion
  " If fuzzy, wrap the completion func in wilder#cmdline#get_fuzzy_completion()
  if a:res.expand ==# 'tags' && a:res.expand_arg[0] ==# '/'
    let l:Getcompletion = l:Completion_func
  elseif a:fuzzy
    let l:Getcompletion = {ctx, x -> wilder#cmdline#get_fuzzy_completion(
          \ ctx, x, l:Completion_func, a:fuzzy, a:use_python)}
  else
    let l:Getcompletion = l:Completion_func
  endif

  return wilder#wait(l:Getcompletion(a:ctx, a:res),
        \ {ctx, xs -> wilder#resolve(ctx, {
        \ 'value': xs,
        \ 'pos': a:res.pos,
        \ 'data': s:convert_result_to_data(a:res),
        \ })})
endfunction

function wilder#cmdline#should_use_file_finder(res) abort
  if has_key(a:res, 'completions')
    return v:false
  endif

  let l:arg = a:res.arg

  if match(l:arg, '\*') != -1
    return 0
  endif

  if l:arg[0] ==# '%' ||
        \ l:arg[0] ==# '#' ||
        \ l:arg[0] ==# '<'
    return 0
  endif

  let l:path = a:res.expand_arg

  " Prevent scanning of filesystem accidentally.
  if l:path ==# '~' ||
        \ l:path[0] ==# '/' ||
        \ l:path[0] ==# '\' ||
        \ l:path[0:1] ==# '..'
    return 0
  endif

  if has('win32') || has('win64')
    return l:path[1] !=# ':'
  endif

  return 1
endfunction

let s:substitute_commands = {
      \ 'substitute': v:true,
      \ 'smagic': v:true,
      \ 'snomagic': v:true,
      \ 'global': v:true,
      \ 'vglobal': v:true,
      \ }

function! wilder#cmdline#is_substitute_command(cmd) abort
  return has_key(s:substitute_commands, a:cmd)
endfunction

function! wilder#cmdline#substitute_pipeline(opts) abort
  if has_key(a:opts, 'hide_in_replace')
    let l:hide_in_replace = a:opts.hide_in_replace
  elseif has_key(a:opts, 'hide')
    " DEPRECATED: use hide_in_replace
    let l:hide_in_replace = a:opts.hide
  else
    let l:hide_in_replace = has('nvim') && !has('nvim-0.3.7')
  endif

  if has_key(a:opts, 'pipeline')
    let l:search_pipeline = a:opts['pipeline']
  elseif wilder#options#get('use_python_remote_plugin')
    let l:search_pipeline = wilder#python_search_pipeline({'skip_cmdtype_check': 1})
  else
    let l:search_pipeline = wilder#vim_search_pipeline({'skip_cmdtype_check': 1})
  endif

  " cmdline
  " : check getcmdtype()?
  " |--> return v:false
  " : parse_cmdline
  " : check is substitute command
  " |--> return v:false
  " : check len(substitute_args) s[/][pattern][/][replace][/][flags]
  " |--> return v:false or v:true
  " : extract substitute [pattern]
  " : search_pipeline
  " : add command, pos and replace
  " └--> result
  return [
        \ wilder#check({-> getcmdtype() ==# ':'}),
        \ {_, x -> wilder#cmdline#parse(x)},
        \ wilder#check({_, res -> wilder#cmdline#is_substitute_command(res.cmd)}),
        \ {_, res -> res.cmd ==# 'global' || res.cmd ==# 'vglobal' ||
        \   len(res.substitute_args) == 1 || len(res.substitute_args) == 2 ?
        \   res :
        \   l:hide_in_replace ? v:true : v:false},
        \ wilder#subpipeline({ctx, res -> [
        \   {_, res -> res.cmd ==# 'global' || res.cmd ==# 'vglobal' ?
        \     res.arg :
        \     res.substitute_args[1]},
        \ ] + l:search_pipeline + [
        \   wilder#result({
        \     'data': {
        \       'cmdline.command': res.cmd,
        \     },
        \     'pos': res.pos + 1,
        \     'replace': ['wilder#cmdline#replace'],
        \   }),
        \ ]}),
        \ ]
endfunction

function! wilder#cmdline#python_file_finder_pipeline(opts) abort
  let l:opts = copy(a:opts)

  let l:should_debounce = get(l:opts, 'debounce', 0) > 0
  if l:should_debounce
    let l:debounce_interval = l:opts['debounce']
    let l:Debounce = wilder#debounce(l:debounce_interval)
  else
    let l:Debounce = 0
  endif

  if has_key(l:opts, 'filters')
    let l:checked_filters = []

    for l:filter in l:opts['filters']
      if type(l:filter) isnot v:t_dict
        let l:filter = {'name': l:filter}
      endif

      let l:filter_opts = get(l:filter, 'opts', {})
      let l:filter['opts'] = l:filter_opts

      if l:filter['name'] ==# 'fruzzy_filter' &&
            \ !has_key(l:filter_opts, 'fruzzy_path')
        let l:filter_opts['fruzzy_path'] = wilder#fruzzy_path()
      endif

      if l:filter['name'] ==# 'cpsm_filter' &&
            \ !has_key(l:filter_opts, 'cpsm_path')
        let l:filter_opts['cpsm_path'] = wilder#cpsm_path()
      endif

      if l:filter['name'] ==# 'clap_filter'
        if !has_key(l:filter_opts, 'clap_path')
          let l:filter_opts['clap_path'] = wilder#clap_path()
        endif

        if !has_key(l:filter_opts, 'use_rust')
          let l:use_rust = !empty(wilder#findfile('pythonx/clap/fuzzymatch_rs.so')) ||
                \ !empty(wilder#findfile('pythonx/clap/fuzzymatch_rs.dyn'))
          let l:filter_opts['use_rust'] = l:use_rust
        endif
      endif

      call add(l:checked_filters, l:filter)
    endfor

    let l:opts['filters'] = l:checked_filters
  else
    let l:opts['filters'] = [{'name': 'fuzzy_filter', 'opts': {}}, {'name': 'difflib_sorter', 'opts': {}}]
  endif

  if !has_key(l:opts, 'path')
    let l:opts['path'] = wilder#project_root()
  endif

  let l:Path = l:opts['path']
  if type(l:Path) isnot v:t_func
    let l:opts['path'] = {-> l:Path}
  endif

  " cmdline
  " : check getcmdtype()?
  " |--> return v:false
  " : parse_cmdline
  " : prepare user completion to update res.expand
  " : if handled
  " |--> return v:false
  " : check is file or dir
  " |--> return v:false
  " : prepare_file_completion
  " | reset parsed.pos to original
  " : should use file finder?
  " |--> return v:false
  " : debounce if needed
  " : _wilder_python_file_finder
  " : add pos, replace and data
  " └--> result
  return [
        \ wilder#check({-> getcmdtype() ==# ':'}),
        \ {_, x -> wilder#cmdline#parse(x)},
        \ {ctx, res -> wilder#cmdline#prepare_user_completion(ctx, res)},
        \ {ctx, res -> res[0] ? v:false : res[2]},
        \ wilder#check({_, res -> res.expand ==# 'file' || res.expand ==# 'dir'}),
        \ wilder#subpipeline({ctx, res1 -> [
        \   {ctx, res1 -> wilder#cmdline#prepare_file_completion(ctx, copy(res1), 0)},
        \   {ctx, res2 -> extend(res2, {'pos': res1.pos})},
        \ ]}),
        \ wilder#check({ctx, res -> wilder#cmdline#should_use_file_finder(res)}),
        \ wilder#if(l:should_debounce, l:Debounce),
        \ wilder#subpipeline({ctx, res -> [
        \   {-> s:file_finder(ctx, l:opts, res)},
        \   wilder#result({
        \     'pos': res.pos,
        \     'replace': ['wilder#cmdline#replace'],
        \     'data': extend(s:convert_result_to_data(res), {'query': s:expand_user_and_env_vars(res.arg)}),
        \   }),
        \ ]}),
        \ ]
endfunction

function! s:expand_user_and_env_vars(arg)
  let l:slash = !has('win32') && !has('win64')
        \ ? '/'
        \ : &shellslash
        \ ? '/'
        \ : '\'

  let l:path_segments = split(a:arg, l:slash, 1)

  if empty(l:path_segments)
    return a:arg
  endif

  call map(l:path_segments, {_, p -> p[0] ==# '$' ? eval(p) : p})

  if l:path_segments[0][0] ==# '~'
    let l:path_segments[0] = expand(l:path_segments[0])
  endif

  return join(l:path_segments, l:slash)
endfunction

function! s:file_finder(ctx, opts, res) abort
  let l:cwd = getcwd()
  let l:match_arg = s:expand_user_and_env_vars(a:res.arg)
  let l:is_dir = a:res.expand ==# 'dir'

  if !l:is_dir
    if has_key(a:opts, 'file_command')
      let l:Command = a:opts['file_command']
    else
      let l:Command = ['find', '.', '-type', 'f', '-printf', '%P\n']
    endif
  else
    if has_key(a:opts, 'dir_command')
      let l:Command = a:opts['dir_command']
    else
      let l:Command = ['find', '.', '-type', 'd', '-printf', '%P\n']
    endif
  endif

  if type(l:Command) is v:t_func
    let l:Command = l:Command(a:ctx, l:match_arg)

    if l:Command is v:false
      return v:false
    endif
  endif

  if has_key(a:opts, 'cache_timestamp')
    let l:timestamp = a:opts['cache_timestamp'](a:ctx)
  else
    let l:timestamp = a:ctx.session_id
  endif

  let l:path = a:opts['path'](a:ctx, l:match_arg)

  let l:opts = {
        \ 'timeout': get(a:opts, 'timeout', 5000),
        \ }

  return {ctx -> _wilder_python_file_finder(ctx, l:opts, l:Command, a:opts['filters'],
        \ l:cwd, l:path, l:match_arg, l:is_dir, l:timestamp)}
endfunction

function! s:simplify(path)
  let l:path = simplify(a:path)

  let l:slash = !has('win32') && !has('win64')
        \ ? '/'
        \ : &shellslash
        \ ? '/'
        \ : '\'

  if a:path[-2:-1] ==# '/.' || a:path[-2:-1] ==# l:slash . '.'
    let l:path .= a:path[-2:-1]
  endif

  return l:path
endfunction

function! s:get_opts(opts) abort
  if has_key(a:opts, 'language')
    let l:use_python = a:opts['language'] ==# 'python'
  elseif has_key(a:opts, 'use_python')
    let l:use_python = a:opts['use_python']
  else
    let l:use_python = wilder#options#get('use_python_remote_plugin')
  endif

  let l:fuzzy = get(a:opts, 'fuzzy', 0)
  let l:with_data = 0
  if l:fuzzy
    if has_key(a:opts, 'fuzzy_filter_with_data')
      let l:with_data = 1
      let l:Filter = a:opts['fuzzy_filter_with_data']
    elseif has_key(a:opts, 'fuzzy_filter')
      let l:Filter = a:opts['fuzzy_filter']
    elseif l:use_python
      let l:Filter = wilder#python_fuzzy_filter()
    else
      let l:Filter = wilder#vim_fuzzy_filter()
    endif
  else
    let l:Filter = 0
  endif

  return [l:Filter, l:with_data, l:use_python, l:fuzzy]
endfunction

function! wilder#cmdline#getcompletion_pipeline(opts) abort
  let [l:Filter, l:with_data, l:use_python, l:fuzzy] = s:get_opts(a:opts)

  " parsed cmdline
  " : prepare_file_completion
  " : s:getcompletion
  " : map if relative_to_home_dir
  " : fuzzy_filter if needed
  " └--> result
  let l:file_completion_subpipeline = [
        \ wilder#check({_, res -> wilder#cmdline#is_file_expansion(res.expand)}),
        \ {ctx, res -> wilder#cmdline#prepare_file_completion(ctx, res, l:fuzzy)},
        \ wilder#subpipeline({ctx, res -> [
        \   {ctx, res -> s:getcompletion(ctx, res, l:fuzzy, l:use_python)},
        \   wilder#result({
        \     'value': {ctx, xs, data -> l:fuzzy == 0 ?
        \       s:filter_file_in_path(ctx, xs, data) : xs},
        \   }),
        \   wilder#result({
        \     'value': {ctx, xs -> get(res, 'relative_to_home_dir', 0) ?
        \       map(xs, {i, x -> fnamemodify(x, ':~')}) : xs},
        \   }),
        \ ]}),
        \ wilder#if(l:fuzzy && !l:with_data, wilder#result({
        \   'value': {ctx, xs, data -> l:Filter(
        \     ctx, xs, get(data, 'cmdline.path_prefix', '') . get(data, 'cmdline.match_arg', ''))},
        \ })),
        \ wilder#if(l:fuzzy && l:with_data, wilder#result({
        \   'value': {ctx, xs, data -> l:Filter(
        \     ctx, data, xs, get(data, 'cmdline.path_prefix', '') . get(data, 'cmdline.match_arg', ''))},
        \ })),
        \ wilder#result({
        \   'draw': ['wilder#cmdline#draw_path'],
        \   'replace': ['wilder#cmdline#replace'],
        \ }),
        \ wilder#result_output_escape(' '),
        \ ]

  " parsed cmdline
  " : prepare_completion
  " : s:getcompletion
  " : fuzzy_filter if needed
  " └--> result
  let l:completion_subpipeline = [
        \ {ctx, res -> wilder#cmdline#prepare_getcompletion(ctx, res, l:fuzzy, l:use_python)},
        \ {ctx, res -> s:getcompletion(ctx, res, l:fuzzy, l:use_python)},
        \ wilder#if(l:fuzzy && !l:with_data, wilder#result({
        \   'value': {ctx, xs, data -> l:Filter(
        \     ctx, xs, get(data, 'cmdline.match_arg', ''))},
        \ })),
        \ wilder#if(l:fuzzy && l:with_data, wilder#result({
        \   'value': {ctx, xs, data -> l:Filter(
        \     ctx, data, xs, get(data, 'cmdline.match_arg', ''))},
        \ })),
        \ wilder#result({
        \   'replace': ['wilder#cmdline#replace'],
        \ }),
        \ ]

  let l:lua_completion_subpipeline = [
        \ wilder#check({_, res -> res.expand ==# 'lua'}),
        \ {ctx, res -> has('nvim-0.5') ? res : v:false},
        \ {ctx, res -> s:get_lua_completion(ctx, res, l:fuzzy)},
        \ wilder#if(l:fuzzy && !l:with_data, wilder#result({
        \   'value': {ctx, xs, data -> l:Filter(
        \     ctx, xs, get(data, 'cmdline.match_arg', ''))},
        \ })),
        \ wilder#if(l:fuzzy && l:with_data, wilder#result({
        \   'value': {ctx, xs, data -> l:Filter(
        \     ctx, data, xs, get(data, 'cmdline.match_arg', ''))},
        \ })),
        \ ]

  " parsed cmdline
  " : is file expansion?
  " |--> file_completion_pipeline
  " └--> completion_pipeline
  return [
        \ wilder#branch(
        \   l:lua_completion_subpipeline,
        \   l:file_completion_subpipeline,
        \   l:completion_subpipeline,
        \ ),
        \ ]
endfunction

function! s:filter_file_in_path(ctx, xs, data) abort
  if get(a:data, 'cmdline.expand', '') !=# 'file_in_path'
    return a:xs
  endif

  let l:arg = get(a:data, 'cmdline.arg', '')
  return filter(a:xs, {_, x -> stridx(x, l:arg) != -1})
endfunction

function! s:get_lua_completion(ctx, res, fuzzy) abort
  let l:last_char = a:res.arg[-1 :]
  if !empty(l:last_char) &&
        \ l:last_char !~# '\w' &&
        \ l:last_char !=# '_' &&
        \ l:last_char !=# '.'
    " _expand_arg fails when arg ends with non-identifier
    let l:candidates = luaeval('{vim._expand_pat("")}')[0]
    let l:arg_pos = len(a:res.arg)
  else
    let [l:candidates, l:arg_pos] = luaeval('{vim._expand_pat("^" .. _A[1])}', [a:res.arg])

    if a:fuzzy
      let l:last_char = a:res.arg[-1 :]

      " use arg_pos to calculate where arg starts
      let l:arg = l:arg_pos > 0 ?
            \ a:res.arg[: l:arg_pos - 1] :
            \ ''

      let l:last_char = l:arg[-1 :]
      if !empty(l:last_char) &&
            \ l:last_char !~# '\w' &&
            \ l:last_char !=# '_' &&
            \ l:last_char !=# '.'
        let l:candidates = luaeval('{vim._expand_pat("")}')[0]
      else
        let l:candidates = luaeval('{vim._expand_pat("^" .. _A[1])}', [l:arg])[0]
      endif
    endif
  endif

  if l:arg_pos > 0
    let l:prefix = a:res.arg[: l:arg_pos - 1]
    let l:match_arg = a:res.arg[l:arg_pos :]
    let l:pos = a:res.pos + l:arg_pos - 1
  else
    let l:prefix = ''
    let l:match_arg = a:res.arg
    let l:pos = a:res.pos
  endif

  if a:fuzzy == 1 && !empty(l:match_arg)
    let l:char = l:match_arg[0]
    let l:candidates = filter(l:candidates, {_, x -> x[0] ==# tolower(l:char) || x[0] ==# toupper(l:char)})
  endif

  return {
        \ 'value': l:candidates,
        \ 'pos': l:pos,
        \ 'replace': ['wilder#cmdline#replace_lua'],
        \ 'data': {
        \   'cmdline.match_arg': l:match_arg,
        \   'cmdline.lua_prefix': l:prefix,
        \ },
        \ }
endfunction

function! wilder#cmdline#replace_lua(ctx, x, data)
  let l:result = wilder#cmdline#parse(a:ctx.cmdline)

  if l:result.pos > 0
    let l:cmdline = l:result.cmdline[: l:result.pos - 1]
  else
    let l:cmdline = ''
  endif

  return l:cmdline . get(a:data, 'cmdline.lua_prefix', '') . a:x
endfunction

function! wilder#cmdline#pipeline(opts) abort
  if has_key(a:opts, 'hide_in_substitute')
    let l:hide_in_substitute = a:opts.hide_in_substitute
  elseif has_key(a:opts, 'hide')
    " DEPRECATED: use hide_in_substitute
    let l:hide_in_substitute = a:opts.hide
  else
    let l:hide_in_substitute = has('nvim') && !has('nvim-0.3.7')
  endif

  let l:Sorter = get(a:opts, 'sorter', get(a:opts, 'sort', 0))

  let l:set_pcre2_pattern = get(a:opts, 'set_pcre2_pattern', 0)

  let l:sort_buffers_lastused = get(a:opts, 'sort_buffers_lastused', 1)

  let l:should_debounce = get(a:opts, 'debounce', 0) > 0
  if l:should_debounce
    let l:debounce_interval = a:opts['debounce']
    let l:Debounce = wilder#debounce(l:debounce_interval)
  else
    let l:Debounce = 0
  endif

  let l:opts = s:get_opts(a:opts)
  let l:F = l:opts[0]
  let l:with_data = l:opts[1]
  let l:fuzzy = l:opts[3]

  if l:fuzzy
    if l:with_data
      let l:Filter = {ctx, xs, q -> l:F(ctx, {}, xs, q)}
    else
      let l:Filter = l:F
    endif
  else
    let l:Filter = {ctx, xs, q -> filter(xs, {_, x -> match(x, q) == 0})}
  endif

  " [handled, user_completions, parsed, need_filter]
  " : handled?
  " └--> user_completions
  let l:user_completion_pipeline = [
        \ {ctx, res -> res[0] ? res : v:false},
        \ wilder#subpipeline({ctx, res -> [
        \   {_, res -> res[1]},
        \   wilder#result({
        \     'value': {ctx, xs -> res[3] ? l:Filter(ctx, xs, res[2].arg) : xs},
        \     'pos': res[2].pos,
        \     'replace': ['wilder#cmdline#replace'],
        \     'data': s:convert_result_to_data(res[2]),
        \   }),
        \ ]}),
        \ ]

  " [handled, user_completions, parsed]
  " : not handled, extract parsed
  " : getcompletion_pipeline 
  " : sort if needed
  " : add pcre2 pattern if needed
  " └--> result
  let l:getcompletion_pipeline = [{ctx, res -> res[2]}] +
        \ wilder#cmdline#getcompletion_pipeline(a:opts) + [
        \ wilder#if(l:Sorter isnot 0, wilder#result({
        \   'value': {ctx, xs, data ->
        \     l:Sorter(ctx, xs, get(data, 'cmdline.match_arg', ''))}
        \ })),
        \ wilder#if(l:set_pcre2_pattern, wilder#result({
        \   'data': {ctx, data -> s:set_pcre2_pattern(data, l:fuzzy)},
        \ })),
        \ ]

  " cmdline
  " : check getcmdtype()?
  " |--> return v:false
  " : parse_cmdline
  " : check is substitute command and should hide?
  " |--> return v:true
  " : prepare_user_completion
  " : is user completion?
  " |--> user_completion_pipeline
  " └--> getcompletion_pipeline
  "    : add data.query
  "    └--> result
  return [
        \ wilder#check({-> getcmdtype() ==# ':'}),
        \ {_, x -> wilder#cmdline#parse(x)},
        \ wilder#if(l:hide_in_substitute, {ctx, res -> len(get(res, 'substitute_args', [])) >= 2 ? v:true : res}),
        \ wilder#if(l:should_debounce, l:Debounce),
        \ {ctx, res -> wilder#cmdline#prepare_user_completion(ctx, res)},
        \ wilder#branch(
        \   l:user_completion_pipeline,
        \   l:getcompletion_pipeline,
        \ ),
        \ wilder#result({
        \   'value': {ctx, xs, data -> l:sort_buffers_lastused ? s:sort_buffers_lastused(ctx, xs, data) : xs},
        \   'data': {ctx, data -> s:set_query(data)},
        \ }),
        \ ]
endfunction

function! s:set_pcre2_pattern(data, fuzzy) abort
  let l:data = a:data is v:null ? {} : a:data
  let l:match_arg = get(l:data, 'cmdline.match_arg', '')

  if a:fuzzy
    let l:pcre2_pattern = wilder#transform#make_python_fuzzy_regex(l:match_arg)
  else
    let l:pcre2_pattern = '('. escape(l:match_arg, '\.^$*+?|(){}[]') . ')'
  endif

  return extend(l:data, {'pcre2.pattern': l:pcre2_pattern})
endfunction

function! s:sort_buffers_lastused(ctx, xs, data) abort
  if get(a:data, 'cmdline.expand', '') !=# 'buffer'
    return a:xs
  endif

  let l:bufinfos = getbufinfo()
  let l:bufnr_to_x = {}

  for l:x in a:xs
    let l:bufname = fnamemodify(l:x, ':~')
    let l:bufnr = bufnr('^' . l:x . '$')

    let l:bufnr_to_x[l:bufnr] = l:x
  endfor

  let l:x_to_info = {}
  let l:seen = {}

  for l:info in l:bufinfos
    let l:bufnr = l:info.bufnr

    if !has_key(l:bufnr_to_x, l:bufnr)
      continue
    endif

    let l:x = l:bufnr_to_x[l:bufnr]
    let l:x_to_info[l:x] = l:info
    let l:seen[l:bufnr] = 1
  endfor

  let l:xs = copy(a:xs)
  let l:match_arg = get(a:data, 'cmdline.match_arg', '')

  " add matching bufnr
  if l:match_arg =~# '\d\+'
    for l:info in l:bufinfos
      let l:bufnr = l:info.bufnr
      let l:bufname = l:info.name

      if !l:info.listed ||
            \ empty(l:bufname) ||
            \ has_key(l:seen, l:bufnr)
        continue
      endif

      if stridx(l:bufnr, l:match_arg) == 0
        let l:bufname = fnamemodify(l:bufname, ':~:.')
        let l:x_to_info[l:bufname] = l:info
        call add(l:xs, l:bufname)
      endif
    endfor
  endif

  let l:current_bufnr = bufnr('%')

  return sort(l:xs, {x1, x2 -> s:sort_buffers_lastused_func(x1, x2, l:x_to_info, l:current_bufnr)})
endfunction

function! s:sort_buffers_lastused_func(x1, x2, x_to_info, current_bufnr) abort
  let l:info1 = get(a:x_to_info, a:x1, {})
  let l:lastused1 = get(l:info1, 'lastused', 1000000000)
  let l:info2 = get(a:x_to_info, a:x2, {})
  let l:lastused2 = get(l:info2, 'lastused', 1000000000)

  if get(l:info1, 'bufnr', -1) == a:current_bufnr
    return 1
  endif

  if get(l:info2, 'bufnr', -1) == a:current_bufnr
    return -1
  endif

  return l:lastused2 - l:lastused1
endfunction

function! s:set_query(data) abort
  let l:data = a:data is v:null ? {} : a:data
  let l:match_arg = get(l:data, 'cmdline.match_arg', '')

  return extend(l:data, {'query': l:match_arg})
endfunction

function! s:is_prefix(str, q) abort
  if empty(a:q)
    return 1
  endif

  if len(a:q) > len(a:str)
    return 0
  endif

  return a:str[0 : len(a:q) - 1] ==# a:q
endfunction
