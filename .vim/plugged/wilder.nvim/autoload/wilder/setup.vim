function! wilder#setup#(...)
  let l:config = get(a:, 1, {})

  " Duplicate wilder#main#enable_cmdline_enter() and
  " wilder#main#disable_cmdline_enter() here so we don't have to autoload
  " autoload/wilder/main.vim.
  if get(l:config, 'enable_cmdline_enter', 1)
    if !exists('#WilderCmdlineEnter')
      augroup WilderCmdlineEnter
        autocmd!
        autocmd CmdlineEnter * call wilder#main#start()
      augroup END
    endif
  else
    if exists('#WilderCmdlineEnter')
      augroup WilderCmdlineEnter
        autocmd!
      augroup END
      augroup! WilderCmdlineEnter
    endif
  endif

  let l:wildcharm = get(l:config, 'wildcharm', &wildchar)
  if l:wildcharm isnot v:false
    execute 'set wildcharm='. &wildchar
  endif

  let l:modes = get(l:config, 'modes', ['/', '?'])
  call wilder#options#set('modes', l:modes)

  for [l:key, l:default_mapping, l:function, l:condition] in [
        \ ['next_key', '<Tab>', 'wilder#next()', 'wilder#in_context()'],
        \ ['previous_key', '<S-Tab>', 'wilder#previous()', 'wilder#in_context()'],
        \ ['reject_key', '<Up>', 'wilder#reject_completion()', 'wilder#can_reject_completion()'],
        \ ['accept_key', '<Down>', 'wilder#accept_completion()', 'wilder#can_accept_completion()'],
        \ ]
    let l:mapping = get(l:config, l:key, l:default_mapping)
    if l:mapping is v:false
      continue
    endif

    if type(l:mapping) is v:t_list
      let l:fallback_mapping = l:mapping[1]
      let l:mapping = l:mapping[0]
    else
      let l:fallback_mapping = l:mapping
    endif

    if l:key ==# 'accept_key' &&
          \ !get(l:config, 'accept_completion_auto_select', 1)
      let l:function = 'wilder#accept_completion(0)'
    endif

    if l:fallback_mapping isnot 0
      execute 'cnoremap <expr>' l:mapping l:condition ' ? ' l:function ' : ' string(l:fallback_mapping)
    else
      execute 'cmap ' l:mapping '<Cmd>call' l:function '<CR>'
    endif
  endfor

endfunction
