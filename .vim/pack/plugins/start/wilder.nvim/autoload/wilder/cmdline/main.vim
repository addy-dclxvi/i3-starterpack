let s:command_modifiers = {
      \ 'aboveleft': 1,
      \ 'argdo': 1,
      \ 'belowright': 1,
      \ 'botright': 1,
      \ 'browse': 1,
      \ 'bufdo': 1,
      \ 'cdo': 1,
      \ 'cfdo': 1,
      \ 'confirm': 1,
      \ 'debug': 1,
      \ 'folddoclosed': 1,
      \ 'folddoopen': 1,
      \ 'hide': 1,
      \ 'keepalt': 1,
      \ 'keepjumps': 1,
      \ 'keepmarks': 1,
      \ 'keeppatterns': 1,
      \ 'ldo': 1,
      \ 'leftabove': 1,
      \ 'lfdo': 1,
      \ 'lockmarks': 1,
      \ 'noautocmd': 1,
      \ 'noswapfile': 1,
      \ 'rightbelow': 1,
      \ 'sandbox': 1,
      \ 'silent': 1,
      \ 'tab': 1,
      \ 'tabdo': 1,
      \ 'topleft': 1,
      \ 'verbose': 1,
      \ 'vertical': 1,
      \ 'windo': 1,
      \ }

function! wilder#cmdline#main#do(ctx) abort
  " default
  let a:ctx.expand = 'command'
  let a:ctx.force = 0

  if empty(a:ctx.cmdline[a:ctx.pos :])
    return
  endif

  if !wilder#cmdline#main#skip_whitespace(a:ctx)
    return
  endif

  " check if comment
  if a:ctx.cmdline[a:ctx.pos] ==# '"'
    let a:ctx.pos = len(a:ctx.cmdline)
    let a:ctx.expand = 'nothing'
    return
  endif

  " skip range
  call wilder#cmdline#skip_range#do(a:ctx)

  if !wilder#cmdline#main#skip_whitespace(a:ctx)
    return
  endif

  if a:ctx.cmdline[a:ctx.pos] ==# '"'
    let a:ctx.pos = len(a:ctx.cmdline)
    let a:ctx.expand = 'nothing'
    return
  endif

  " check if starts with | or :
  " treat as a new command
  if a:ctx.cmdline[a:ctx.pos] ==# '|' || a:ctx.cmdline[a:ctx.pos] ==# ':'
    let a:ctx.pos += 1
    let a:ctx.cmd = ''

    call wilder#cmdline#main#do(a:ctx)

    return
  endif

  let l:is_user_cmd = 0

  if a:ctx.cmdline[a:ctx.pos] ==# 'k' && a:ctx.cmdline[a:ctx.pos + 1] !=# 'e'
    let a:ctx.cmd = 'k'
    let a:ctx.pos += 1

    return
  else
    let l:cmd_start = a:ctx.pos

    let l:char = a:ctx.cmdline[a:ctx.pos]

    if l:char >=# 'A' && l:char <=# 'Z'
      " user-defined command can contain digits
      while l:char >=# 'a' && l:char <=# 'z' ||
            \ l:char >=# 'A' && l:char <=# 'Z' ||
            \ l:char >=# '0' && l:char <=# '9'
        let a:ctx.pos += 1
        let l:char = a:ctx.cmdline[a:ctx.pos]
      endwhile

      let a:ctx.cmd = a:ctx.cmdline[l:cmd_start : a:ctx.pos - 1]
      let l:is_user_cmd = 1
    else
      " non-alphabet command
      if stridx('@*!=><&~#', l:char) != -1
        let a:ctx.pos += 1
        let l:char = a:ctx.cmdline[a:ctx.pos]
      else
        " py3, python3, py3file and py3do are the only commands with numbers
        " all other commands are alphabet only
        if a:ctx.cmdline[a:ctx.pos] ==# 'p' &&
              \ a:ctx.cmdline[a:ctx.pos + 1] ==# 'y' &&
              \ a:ctx.cmdline[a:ctx.pos + 2] ==# '3'
          let a:ctx.pos += 3
          let l:char = a:ctx.cmdline[a:ctx.pos]
        endif

        " this should check for [a-zA-Z] only, but the Vim implementation
        " skips over wildcards. This matters for commands which accept
        " non-alphanumeric arugments e.g. 'e*' would be parsed as an 'edit'
        " command with a '*' argument otherwise. These commands typically
        " don't need a space between the command and argument e.g. 'e++opt'
        " is a valid command.
        while l:char >=# 'a' && l:char <=# 'z' ||
              \ l:char >=# 'A' && l:char <=# 'Z' ||
              \ l:char ==# '*'
          let a:ctx.pos += 1
          let l:char = a:ctx.cmdline[a:ctx.pos]
        endwhile
      endif

      if a:ctx.pos == l:cmd_start
        let a:ctx.expand = 'unsuccessful'
        return
      endif

      " find the command
      if a:ctx.pos > l:cmd_start
        let l:cmd = a:ctx.cmdline[l:cmd_start : a:ctx.pos - 1]
        let l:len = a:ctx.pos - l:cmd_start

        let l:char = l:cmd[0]
        if l:char < 'a' || l:char > 'z'
          let l:char = 'z'
        endif

        let l:next_char = nr2char(char2nr(l:char) + 1)

        let l:i = s:command_char_pos[l:char]
        let l:end = get(s:command_char_pos, 'l:next_char', len(s:commands))

        while l:i < l:end
          let l:command = s:commands[l:i]
          if l:cmd ==# l:command[: l:len - 1]
            let a:ctx.cmd = l:command
            break
          endif

          let l:i += 1
        endwhile
      endif
    endif
  endif

  " cursor is touching command and ends in alpha-numeric character
  " complete the command name
  if a:ctx.pos == len(a:ctx.cmdline)
    let l:char = a:ctx.cmdline[a:ctx.pos - 1]

    if l:char >=# 'a' && l:char <=# 'z' ||
          \ l:char >=# 'A' && l:char <=# 'Z' ||
          \ l:char >=# '0' && l:char <=# '9'
      let a:ctx.pos = l:cmd_start
      let a:ctx.cmd = ''
      " expand commands
      return
    endif
  endif

  " no matching command found, treat as no arguments
  if empty(a:ctx.cmd)
    " 2 or 3-letter substitute command, takes no arguments
    if a:ctx.cmdline[l:cmd_start] ==# 's' &&
          \ stridx('cgriI', a:ctx.cmdline[l:cmd_start + 1]) != -1
      let a:ctx.cmd = 's'
    endif

    let a:ctx.pos = len(a:ctx.cmdline)
    let a:ctx.expand = 'nothing'
    return
  endif

  let a:ctx.expand = 'nothing'

  " handle !
  if a:ctx.cmdline[a:ctx.pos] ==# '!'
    let a:ctx.pos += 1
    let a:ctx.force = 1
  endif

  if has_key(s:command_modifiers, a:ctx.cmd)
    let a:ctx.cmd = ''
    let a:ctx.expand = ''

    call wilder#cmdline#main#do(a:ctx)

    return
  endif

  call wilder#cmdline#main#skip_whitespace(a:ctx)

  let l:flags = get(s:command_flags, a:ctx.cmd, 0)

  let l:use_filter = 0

  if a:ctx.cmd ==# 'write' || a:ctx.cmd ==# 'update'
    if a:ctx.cmdline[a:ctx.pos] ==# '>'
      if a:ctx.cmdline[a:ctx.pos + 1] ==# '>'
        let a:ctx.pos += 2
      endif

      call wilder#cmdline#main#skip_whitespace(a:ctx)
    endif

    if a:ctx.cmd ==# 'write' && a:ctx.cmdline[a:ctx.pos] ==# '!'
      let a:ctx.pos += 1
      let l:use_filter = 1
    endif
  elseif a:ctx.cmd ==# 'read'
    if a:ctx.cmdline[a:ctx.pos] ==# '!'
      let a:ctx.pos += 1
      let l:use_filter = 1
    else
      let l:use_filter = a:ctx.force
    endif
  elseif a:ctx.cmd ==# '<' || a:ctx.cmd ==# '>'
    while a:ctx.cmdline[a:ctx.pos] ==# a:ctx.cmd
      let a:ctx.pos += 1
    endwhile

    call wilder#cmdline#main#skip_whitespace(a:ctx)
  endif

  " Handle +cmd or ++opt
  if a:ctx.cmdline[a:ctx.pos] ==# '+' &&
        \ ((and(l:flags, s:EDITCMD) && !l:use_filter) ||
        \ and(l:flags, s:ARGOPT))
    let l:allow_opt = 1
    let l:allow_cmd = and(l:flags, s:EDITCMD) && !l:use_filter

    while a:ctx.cmdline[a:ctx.pos] ==# '+' &&
          \ a:ctx.pos < len(a:ctx.cmdline)
      let a:ctx.pos += 1

      if a:ctx.cmdline[a:ctx.pos] ==# '+'
        if l:allow_opt
          let a:ctx.pos += 1
          let l:expand = 'file_opt'
        else
          let l:expand = 'nothing'
        endif
      elseif l:allow_cmd
        let l:expand = 'command'
        " ++opt must be before +cmd
        let l:allow_opt = 0
        " only 1 +cmd allowed
        let l:allow_cmd = 0
      else
        let l:expand = 'nothing'
      endif

      let l:arg_start = a:ctx.pos

      " skip to next arg
      while a:ctx.pos < len(a:ctx.cmdline)
            \ && !wilder#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
        if a:ctx.cmdline[a:ctx.pos] ==# '\' &&
              \ a:ctx.pos + 1 < len(a:ctx.cmdline)
          let a:ctx.pos += 1
        endif

        " TODO: multibyte
        let a:ctx.pos += 1
      endwhile

      " still in command or option
      if empty(a:ctx.cmdline[a:ctx.pos])
        let a:ctx.pos = l:arg_start
        let a:ctx.expand = l:expand
        return
      endif

      call wilder#cmdline#main#skip_whitespace(a:ctx)
    endwhile

    if a:ctx.cmd ==# 'write' && a:ctx.cmdline[a:ctx.pos] ==# '!'
      let a:ctx.pos += 1
      let l:use_filter = 1
    elseif a:ctx.cmd ==# 'read'
      if a:ctx.cmdline[a:ctx.pos] ==# '!'
        let a:ctx.pos += 1
        let l:use_filter = 1
      else
        let l:use_filter = a:ctx.force
      endif
    endif
  endif

  " look for | for new command and " for comment
  if and(l:flags, s:TRLBAR) && !l:use_filter
    if a:ctx.cmd ==# 'redir' &&
          \ a:ctx.cmdline[a:ctx.pos] ==# '@' &&
          \ a:ctx.cmdline[a:ctx.pos + 1] ==# '"'
      let a:ctx.pos += 2
    endif

    let l:lookahead = a:ctx.pos
    while l:lookahead < len(a:ctx.cmdline)
      if a:ctx.cmdline[l:lookahead] ==# "\<C-V>" || a:ctx.cmdline[l:lookahead] ==# '\'
        let l:lookahead += 1

        if l:lookahead + 1 < len(a:ctx.cmdline)
          let l:lookahead += 1
        else
          break
        endif
      endif

      " Check if " indicates a comment or start of string
      if a:ctx.cmdline[l:lookahead] ==# '"'
        let l:lookahead += 1

        let l:end_quote_reached = 0
        " Consume until next char is " or end of cmdline is reached
        while l:lookahead < len(a:ctx.cmdline)
          if a:ctx.cmdline[l:lookahead] ==# '\'
            let l:lookahead += 1
          elseif a:ctx.cmdline[l:lookahead] ==# '"'
            let l:end_quote_reached = 1
            let l:lookahead += 1
            break
          endif

          let l:lookahead += 1
        endwhile

        " remaining part of cmdline is comment, treat as no arguments
        if !l:end_quote_reached
          let a:ctx.pos = len(a:ctx.cmdline)
          return
        endif

      " start of new command
      elseif a:ctx.cmdline[l:lookahead] ==# '|'
        let a:ctx.pos = l:lookahead + 1
        let a:ctx.cmd = ''
        let a:ctx.expand = ''

        call wilder#cmdline#main#do(a:ctx)

        return
      endif

      " TODO: multibyte
      let l:lookahead += 1
    endwhile
  endif

  " command does not take extra arguments
  if !and(l:flags, s:EXTRA) && !l:is_user_cmd
    " consume whitespace
    call wilder#cmdline#main#skip_whitespace(a:ctx)

    " and check for | or "
    if a:ctx.cmdline[a:ctx.pos] ==# '|'
      let a:ctx.pos += 1
      let a:ctx.cmd = ''
      let a:ctx.expand = ''

      call wilder#cmdline#main#do(a:ctx)
      return
    else
      " remaining part is either comment or invalid arguments
      " either way, treat as no arguments
      let a:ctx.pos = len(a:ctx.cmdline)
      let a:ctx.expand = 'nothing'
      return
    endif
  endif


  if l:use_filter || a:ctx.cmd ==# '!' || a:ctx.cmd ==# 'terminal'
    let l:before_args = a:ctx.pos

    if !wilder#cmdline#main#skip_nonwhitespace(a:ctx)
      let a:ctx.pos = l:before_args
      let a:ctx.expand = 'shellcmd'
      return
    endif

    " Reset pos back to before_args
    let a:ctx.pos = l:before_args
  endif

  if and(l:flags, s:XFILE)
    " TODO: handle backticks :h backtick-expansion

    let l:arg_start = a:ctx.pos

    " Check if completing $ENV
    if a:ctx.cmdline[a:ctx.pos] ==# '$'
      let l:arg_start = a:ctx.pos
      let a:ctx.pos += 1

      while a:ctx.pos < len(a:ctx.cmdline)
        let l:char = a:ctx.cmdline[a:ctx.pos]
        if !s:is_idc(l:char)
          break
        endif

        let a:ctx.pos += 1
      endwhile

      if a:ctx.pos == len(a:ctx.cmdline)
        let a:ctx.expand = 'environment'
        let a:ctx.pos = l:arg_start + 1
        return
      endif
    endif

    " Check if completing ~user
    if a:ctx.cmdline[a:ctx.pos] ==# '~'
      let l:allow_backslash = has('win32') || has('win64')

      while a:ctx.pos < len(a:ctx.cmdline)
        let l:char = a:ctx.cmdline[a:ctx.pos]
        if l:char ==# '/' ||
              \ l:allow_backslash && l:char ==# '\' ||
              \ !s:is_filec(l:char)
          break
        endif

        let a:ctx.pos += 1
      endwhile

      " + 1 since we want to expand ~ to $HOME
      if a:ctx.pos == len(a:ctx.cmdline) &&
            \ a:ctx.pos > l:arg_start + 1
        let a:ctx.expand = 'user'
        let a:ctx.pos = l:arg_start + 1
        return
      endif
    endif

    let a:ctx.pos = l:arg_start
    let a:ctx.expand = 'file'

    " vim assumes for XFILE, we can ignore arguments other than the last one but
    " this is not necessarily true, we should not do this for NOSPC
    if !and(l:flags, s:NOSPC)
      call s:move_pos_to_last_arg(a:ctx)
    endif
  endif

  if a:ctx.cmd ==# 'find' ||
        \ a:ctx.cmd ==# 'sfind' ||
        \ a:ctx.cmd ==# 'tabfind'
    if a:ctx.expand ==# 'file'
      let a:ctx.expand = 'file_in_path'
    endif
    return
  elseif a:ctx.cmd ==# 'cd' ||
        \ a:ctx.cmd ==# 'chdir' ||
        \ a:ctx.cmd ==# 'lcd' ||
        \ a:ctx.cmd ==# 'lchdir' ||
        \ a:ctx.cmd ==# 'tcd' ||
        \ a:ctx.cmd ==# 'tchdir'
    if a:ctx.expand ==# 'file'
      let a:ctx.expand = 'dir'
    endif
    return
  elseif a:ctx.cmd ==# 'help'
    let a:ctx.expand = 'help'
    return
  " command modifiers
  elseif has_key(s:command_modifiers, a:ctx.cmd)
    let a:ctx.cmd = ''
    let a:ctx.expand = ''

    call wilder#cmdline#main#do(a:ctx)

    return
  elseif a:ctx.cmd ==# 'filter'
    call wilder#cmdline#filter#do(a:ctx)
    return
  elseif a:ctx.cmd ==# 'match'
    call wilder#cmdline#match#do(a:ctx)
    return
  elseif a:ctx.cmd ==# 'command'
    call wilder#cmdline#command#do(a:ctx)
    return
  elseif a:ctx.cmd ==# 'delcommand'
    let a:ctx.expand = 'user_commands'
    return
  elseif a:ctx.cmd ==# 'global' || a:ctx.cmd ==# 'vglobal'
    call wilder#cmdline#global#do(a:ctx)
    return
  elseif a:ctx.cmd ==# '&' || a:ctx.cmd ==# 'substitute'
    call wilder#cmdline#substitute#do(a:ctx)
    return
  elseif a:ctx.cmd ==# 'isearch' ||
        \ a:ctx.cmd ==# 'dsearch' ||
        \ a:ctx.cmd ==# 'ilist' ||
        \ a:ctx.cmd ==# 'dlist' ||
        \ a:ctx.cmd ==# 'ijump' ||
        \ a:ctx.cmd ==# 'psearch' ||
        \ a:ctx.cmd ==# 'djump' ||
        \ a:ctx.cmd ==# 'isplit' ||
        \ a:ctx.cmd ==# 'dsplit'
    call wilder#cmdline#isearch#do(a:ctx)
    return
  elseif a:ctx.cmd ==# 'autocmd'
    call wilder#cmdline#autocmd#do(a:ctx, 0)
    return
  elseif a:ctx.cmd ==# 'doautocmd' ||
        \ a:ctx.cmd ==# 'doautoall'
    call wilder#cmdline#autocmd#do(a:ctx, 1)
  elseif a:ctx.cmd ==# 'set' ||
        \ a:ctx.cmd ==# 'setglobal' ||
        \ a:ctx.cmd ==# 'setlocal'
    call wilder#cmdline#set#do(a:ctx)
    return
  elseif a:ctx.cmd ==# 'tag' ||
        \ a:ctx.cmd ==# 'stag' ||
        \ a:ctx.cmd ==# 'ptag' ||
        \ a:ctx.cmd ==# 'ltag' ||
        \ a:ctx.cmd ==# 'tselect' ||
        \ a:ctx.cmd ==# 'stselect' ||
        \ a:ctx.cmd ==# 'tjump' ||
        \ a:ctx.cmd ==# 'stjump' ||
        \ a:ctx.cmd ==# 'ptselect' ||
        \ a:ctx.cmd ==# 'ptjump'
    let a:ctx.expand = 'tags'
    return
  elseif a:ctx.cmd ==# 'augroup'
    let a:ctx.expand = 'augroup'
  elseif a:ctx.cmd ==# 'syntax'
    call wilder#cmdline#syntax#do(a:ctx)
    return
  elseif a:ctx.cmd ==# 'let' ||
        \ a:ctx.cmd ==# 'if' ||
        \ a:ctx.cmd ==# 'elseif' ||
        \ a:ctx.cmd ==# 'while' ||
        \ a:ctx.cmd ==# 'for' ||
        \ a:ctx.cmd ==# 'echo' ||
        \ a:ctx.cmd ==# 'echon' ||
        \ a:ctx.cmd ==# 'execute' ||
        \ a:ctx.cmd ==# 'echomsg' ||
        \ a:ctx.cmd ==# 'echoerr' ||
        \ a:ctx.cmd ==# 'call' ||
        \ a:ctx.cmd ==# 'return' ||
        \ a:ctx.cmd ==# 'cexpr' ||
        \ a:ctx.cmd ==# 'caddexpr' ||
        \ a:ctx.cmd ==# 'cgetexpr' ||
        \ a:ctx.cmd ==# 'lexpr' ||
        \ a:ctx.cmd ==# 'laddexpr' ||
        \ a:ctx.cmd ==# 'lgetexpr'
    "TODO call has extra arugments
    call wilder#cmdline#let#do(a:ctx)
    return
  elseif a:ctx.cmd ==# 'unlet'
    call wilder#cmdline#unlet#do(a:ctx)
    return
  elseif a:ctx.cmd ==# 'function'
    let a:ctx.expand = 'function'
    return
  elseif a:ctx.cmd ==# 'delfunction'
    let a:ctx.expand = 'user_func'
    return
  elseif a:ctx.cmd ==# 'echohl'
    let a:ctx.expand = 'highlight'
    " TODO: include None
    return
  elseif a:ctx.cmd ==# 'highlight'
    call wilder#cmdline#highlight#do(a:ctx)
    return
  elseif a:ctx.cmd ==# 'cscope' ||
        \ a:ctx.cmd ==# 'lcscope' ||
        \ a:ctx.cmd ==# 'scscope'
    call wilder#cmdline#cscope#do(a:ctx)
    return
  elseif a:ctx.cmd ==# 'sign'
    call wilder#cmdline#sign#do(a:ctx)
    return
  elseif a:ctx.cmd ==# 'bdelete' ||
        \ a:ctx.cmd ==# 'bwipeout' ||
        \ a:ctx.cmd ==# 'bunload'
    let a:ctx.expand = 'buffer'
    return
  elseif a:ctx.cmd ==# 'buffer' ||
        \ a:ctx.cmd ==# 'sbuffer' ||
        \ a:ctx.cmd ==# 'checktime'
    let a:ctx.expand = 'buffer'
    return
  elseif a:ctx.cmd ==# 'abbreviate' ||
        \ a:ctx.cmd ==# 'unabbreviate' ||
        \ a:ctx.cmd[-3 :] ==# 'map' ||
        \ a:ctx.cmd[-6 :] ==# 'abbrev'
    call wilder#cmdline#map#do(a:ctx)
    return
  elseif a:ctx.cmd[-8 :] ==# 'mapclear'
    let a:ctx.expand = 'mapclear'
    return
  elseif a:ctx.cmd[-4 :] ==# 'menu'
    call wilder#cmdline#menu#do(a:ctx)
    return
  elseif a:ctx.cmd ==# 'colorscheme'
    let a:ctx.expand = 'color'
    return
  elseif a:ctx.cmd ==# 'compiler'
    let a:ctx.expand = 'compiler'
    return
  elseif a:ctx.cmd ==# 'ownsyntax'
    let a:ctx.expand = 'ownsyntax'
    return
  elseif a:ctx.cmd ==# 'packadd'
    let a:ctx.expand = 'packadd'
    return
  elseif a:ctx.cmd ==# 'language'
    let l:arg_start = a:ctx.pos
    call wilder#cmdline#main#skip_nonwhitespace(a:ctx)

    if a:ctx.pos == len(a:ctx.cmdline)
      let a:ctx.expand = 'language'
      let a:ctx.pos = l:arg_start
    else
      let l:subcommand = a:ctx.cmdline[l:arg_start : a:ctx.pos - 1]
      if l:subcommand ==# 'messages' ||
            \ l:subcommand ==# 'ctype' ||
            \ l:subcommand ==# 'time'
        let a:ctx.expand = 'locales'
        call wilder#cmdline#main#skip_whitespace(a:ctx)
      endif
    endif
  elseif a:ctx.cmd ==# 'profile'
    call wilder#cmdline#profile#do(a:ctx)
    return
  elseif a:ctx.cmd ==# 'checkhealth'
    let a:ctx.expand = 'checkhealth'
    call s:move_pos_to_last_arg(a:ctx)
    return
  elseif a:ctx.cmd ==# 'behave'
    let a:ctx.expand = 'behave'
    return
  elseif a:ctx.cmd ==# 'messages'
    let a:ctx.expand = 'messages'
    return
  elseif a:ctx.cmd ==# 'history'
    let a:ctx.expand = 'history'
    return
  elseif a:ctx.cmd ==# 'syntime'
    let a:ctx.expand = 'syntime'
    return
  elseif a:ctx.cmd ==# 'argdelete'
    let a:ctx.expand = 'arglist'
    return
  elseif a:ctx.cmd ==# 'lua'
    let a:ctx.expand = 'lua'
    return
  endif
endfunction

function! wilder#cmdline#main#has_file_args(cmd) abort
  let l:flags = get(s:command_flags, a:cmd, 0)
  return and(l:flags, s:XFILE)
endfunction

function! wilder#cmdline#main#is_whitespace(char) abort
  let l:nr = char2nr(a:char)
  return a:char ==# ' ' || l:nr >= 9 && l:nr <= 13
endfunction

function! wilder#cmdline#main#skip_whitespace(ctx) abort
  if empty(a:ctx.cmdline[a:ctx.pos])
    return 0
  endif

  while wilder#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
    let a:ctx.pos += 1

    if empty(a:ctx.cmdline[a:ctx.pos])
      return 0
    endif
  endwhile

  return 1
endfunction

function! wilder#cmdline#main#skip_nonwhitespace(ctx) abort
  if empty(a:ctx.cmdline[a:ctx.pos])
    return 0
  endif

  while !wilder#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
    let a:ctx.pos += 1

    if empty(a:ctx.cmdline[a:ctx.pos])
      return 0
    endif
  endwhile

  return 1
endfunction

function! wilder#cmdline#main#find_last_whitespace(ctx) abort
  let l:arg_start = a:ctx.pos
  let a:ctx.pos = len(a:ctx.cmdline) - 1
  while a:ctx.pos >= l:arg_start
    if wilder#cmdline#main#is_whitespace(a:ctx.cmdline[a:ctx.pos])
      let l:arg_start = a:ctx.pos + 1

      break
    endif
    let a:ctx.pos -= 1
  endwhile
endfunction

function! s:move_pos_to_last_arg(ctx) abort
  let l:last_arg = a:ctx.pos

  " find start of last argument
  while a:ctx.pos < len(a:ctx.cmdline)
    let l:char = a:ctx.cmdline[a:ctx.pos]

    if l:char ==# ' ' || l:char ==# "\t"
      let a:ctx.pos += 1
      let l:last_arg = a:ctx.pos
    else
      if l:char ==# '\' && a:ctx.pos + 1 < len(a:ctx.cmdline)
        let a:ctx.pos += 1
      endif
      let a:ctx.pos += 1
    endif
  endwhile

  let a:ctx.pos = l:last_arg
endfunction

function! s:is_filec(c) abort
  return match(a:c, '\f') != -1
endfunction

function! s:path_has_wildcard(c) abort
  if has('win32') || has('win64')
    let l:wildcards = '?*$[`'
  else
    let l:wildcards = "*?[{`'$"
  endif

  return stridx(l:wildcards, a:c) != -1
endfunction

function! s:isfilec_or_wc(c) abort
  return s:is_filec(a:c) || a:c ==# ']' || s:path_has_wildcard(a:c)
endfunction

function! s:is_idc(c) abort
  return match(a:c, '\i') != -1
endfunction

function! s:or(...) abort
  let l:result = 0

  for l:arg in a:000
    let l:result = or(l:result, l:arg)
  endfor

  return l:result
endfunc

let s:EXTRA      =    0x004
let s:XFILE      =    0x008
let s:NOSPC      =    0x010
let s:TRLBAR     =    0x100
let s:EDITCMD    =   0x8000
let s:ARGOPT     =  0x40000

let s:command_char_pos = {
      \ 'a': 0,
      \ 'b': 19,
      \ 'c': 42,
      \ 'd': 104,
      \ 'e': 126,
      \ 'f': 146,
      \ 'g': 161,
      \ 'h': 167,
      \ 'i': 175,
      \ 'j': 193,
      \ 'k': 195,
      \ 'l': 200,
      \ 'm': 258,
      \ 'n': 276,
      \ 'o': 296,
      \ 'p': 307,
      \ 'q': 342,
      \ 'r': 345,
      \ 's': 365,
      \ 't': 430,
      \ 'u': 471,
      \ 'v': 482,
      \ 'w': 500,
      \ 'x': 516,
      \ 'y': 525,
      \ 'z': 526,
      \ '{': 527,
      \ }

let s:commands = [
      \ 'append',
      \ 'abbreviate',
      \ 'abclear',
      \ 'aboveleft',
      \ 'all',
      \ 'amenu',
      \ 'anoremenu',
      \ 'args',
      \ 'argadd',
      \ 'argdelete',
      \ 'argdo',
      \ 'argedit',
      \ 'argglobal',
      \ 'arglocal',
      \ 'argument',
      \ 'ascii',
      \ 'autocmd',
      \ 'augroup',
      \ 'aunmenu',
      \ 'buffer',
      \ 'bNext',
      \ 'ball',
      \ 'badd',
      \ 'bdelete',
      \ 'behave',
      \ 'belowright',
      \ 'bfirst',
      \ 'blast',
      \ 'bmodified',
      \ 'bnext',
      \ 'botright',
      \ 'bprevious',
      \ 'brewind',
      \ 'break',
      \ 'breakadd',
      \ 'breakdel',
      \ 'breaklist',
      \ 'browse',
      \ 'buffers',
      \ 'bufdo',
      \ 'bunload',
      \ 'bwipeout',
      \ 'change',
      \ 'cNext',
      \ 'cNfile',
      \ 'cabbrev',
      \ 'cabclear',
      \ 'caddbuffer',
      \ 'caddexpr',
      \ 'caddfile',
      \ 'call',
      \ 'catch',
      \ 'cbuffer',
      \ 'cbottom',
      \ 'cc',
      \ 'cclose',
      \ 'cd',
      \ 'cdo',
      \ 'center',
      \ 'cexpr',
      \ 'cfile',
      \ 'cfdo',
      \ 'cfirst',
      \ 'cgetfile',
      \ 'cgetbuffer',
      \ 'cgetexpr',
      \ 'chdir',
      \ 'changes',
      \ 'checkhealth',
      \ 'checkpath',
      \ 'checktime',
      \ 'chistory',
      \ 'clist',
      \ 'clast',
      \ 'close',
      \ 'clearjumps',
      \ 'cmap',
      \ 'cmapclear',
      \ 'cmenu',
      \ 'cnext',
      \ 'cnewer',
      \ 'cnfile',
      \ 'cnoremap',
      \ 'cnoreabbrev',
      \ 'cnoremenu',
      \ 'copy',
      \ 'colder',
      \ 'colorscheme',
      \ 'command',
      \ 'comclear',
      \ 'compiler',
      \ 'continue',
      \ 'confirm',
      \ 'copen',
      \ 'cprevious',
      \ 'cpfile',
      \ 'cquit',
      \ 'crewind',
      \ 'cscope',
      \ 'cstag',
      \ 'cunmap',
      \ 'cunabbrev',
      \ 'cunmenu',
      \ 'cwindow',
      \ 'delete',
      \ 'delmarks',
      \ 'debug',
      \ 'debuggreedy',
      \ 'delcommand',
      \ 'delfunction',
      \ 'display',
      \ 'diffupdate',
      \ 'diffget',
      \ 'diffoff',
      \ 'diffpatch',
      \ 'diffput',
      \ 'diffsplit',
      \ 'diffthis',
      \ 'digraphs',
      \ 'djump',
      \ 'dlist',
      \ 'doautocmd',
      \ 'doautoall',
      \ 'drop',
      \ 'dsearch',
      \ 'dsplit',
      \ 'edit',
      \ 'earlier',
      \ 'echo',
      \ 'echoerr',
      \ 'echohl',
      \ 'echomsg',
      \ 'echon',
      \ 'else',
      \ 'elseif',
      \ 'emenu',
      \ 'endif',
      \ 'endfunction',
      \ 'endfor',
      \ 'endtry',
      \ 'endwhile',
      \ 'enew',
      \ 'ex',
      \ 'execute',
      \ 'exit',
      \ 'exusage',
      \ 'file',
      \ 'files',
      \ 'filetype',
      \ 'filter',
      \ 'find',
      \ 'finally',
      \ 'finish',
      \ 'first',
      \ 'fold',
      \ 'foldclose',
      \ 'folddoopen',
      \ 'folddoclosed',
      \ 'foldopen',
      \ 'for',
      \ 'function',
      \ 'global',
      \ 'goto',
      \ 'grep',
      \ 'grepadd',
      \ 'gui',
      \ 'gvim',
      \ 'help',
      \ 'helpclose',
      \ 'helpgrep',
      \ 'helptags',
      \ 'hardcopy',
      \ 'highlight',
      \ 'hide',
      \ 'history',
      \ 'insert',
      \ 'iabbrev',
      \ 'iabclear',
      \ 'if',
      \ 'ijump',
      \ 'ilist',
      \ 'imap',
      \ 'imapclear',
      \ 'imenu',
      \ 'inoremap',
      \ 'inoreabbrev',
      \ 'inoremenu',
      \ 'intro',
      \ 'isearch',
      \ 'isplit',
      \ 'iunmap',
      \ 'iunabbrev',
      \ 'iunmenu',
      \ 'join',
      \ 'jumps',
      \ 'k',
      \ 'keepmarks',
      \ 'keepjumps',
      \ 'keeppatterns',
      \ 'keepalt',
      \ 'list',
      \ 'lNext',
      \ 'lNfile',
      \ 'last',
      \ 'language',
      \ 'laddexpr',
      \ 'laddbuffer',
      \ 'laddfile',
      \ 'later',
      \ 'lbuffer',
      \ 'lbottom',
      \ 'lcd',
      \ 'lchdir',
      \ 'lclose',
      \ 'lcscope',
      \ 'ldo',
      \ 'left',
      \ 'leftabove',
      \ 'let',
      \ 'lexpr',
      \ 'lfile',
      \ 'lfdo',
      \ 'lfirst',
      \ 'lgetfile',
      \ 'lgetbuffer',
      \ 'lgetexpr',
      \ 'lgrep',
      \ 'lgrepadd',
      \ 'lhelpgrep',
      \ 'lhistory',
      \ 'll',
      \ 'llast',
      \ 'llist',
      \ 'lmap',
      \ 'lmapclear',
      \ 'lmake',
      \ 'lnoremap',
      \ 'lnext',
      \ 'lnewer',
      \ 'lnfile',
      \ 'loadview',
      \ 'loadkeymap',
      \ 'lockmarks',
      \ 'lockvar',
      \ 'lolder',
      \ 'lopen',
      \ 'lprevious',
      \ 'lpfile',
      \ 'lrewind',
      \ 'ltag',
      \ 'lunmap',
      \ 'lua',
      \ 'luado',
      \ 'luafile',
      \ 'lvimgrep',
      \ 'lvimgrepadd',
      \ 'lwindow',
      \ 'ls',
      \ 'move',
      \ 'mark',
      \ 'make',
      \ 'map',
      \ 'mapclear',
      \ 'marks',
      \ 'match',
      \ 'menu',
      \ 'menutranslate',
      \ 'messages',
      \ 'mkexrc',
      \ 'mksession',
      \ 'mkspell',
      \ 'mkvimrc',
      \ 'mkview',
      \ 'mode',
      \ 'mzscheme',
      \ 'mzfile',
      \ 'next',
      \ 'nbkey',
      \ 'nbclose',
      \ 'nbstart',
      \ 'new',
      \ 'nmap',
      \ 'nmapclear',
      \ 'nmenu',
      \ 'nnoremap',
      \ 'nnoremenu',
      \ 'noremap',
      \ 'noautocmd',
      \ 'nohlsearch',
      \ 'noreabbrev',
      \ 'noremenu',
      \ 'noswapfile',
      \ 'normal',
      \ 'number',
      \ 'nunmap',
      \ 'nunmenu',
      \ 'oldfiles',
      \ 'omap',
      \ 'omapclear',
      \ 'omenu',
      \ 'only',
      \ 'onoremap',
      \ 'onoremenu',
      \ 'options',
      \ 'ounmap',
      \ 'ounmenu',
      \ 'ownsyntax',
      \ 'print',
      \ 'packadd',
      \ 'packloadall',
      \ 'pclose',
      \ 'perl',
      \ 'perldo',
      \ 'pedit',
      \ 'pop',
      \ 'popup',
      \ 'ppop',
      \ 'preserve',
      \ 'previous',
      \ 'promptfind',
      \ 'promptrepl',
      \ 'profile',
      \ 'profdel',
      \ 'psearch',
      \ 'ptag',
      \ 'ptNext',
      \ 'ptfirst',
      \ 'ptjump',
      \ 'ptlast',
      \ 'ptnext',
      \ 'ptprevious',
      \ 'ptrewind',
      \ 'ptselect',
      \ 'put',
      \ 'pwd',
      \ 'python',
      \ 'pydo',
      \ 'pyfile',
      \ 'py3',
      \ 'py3do',
      \ 'python3',
      \ 'py3file',
      \ 'quit',
      \ 'quitall',
      \ 'qall',
      \ 'read',
      \ 'recover',
      \ 'redo',
      \ 'redir',
      \ 'redraw',
      \ 'redrawstatus',
      \ 'registers',
      \ 'resize',
      \ 'retab',
      \ 'return',
      \ 'rewind',
      \ 'right',
      \ 'rightbelow',
      \ 'rshada',
      \ 'runtime',
      \ 'rundo',
      \ 'ruby',
      \ 'rubydo',
      \ 'rubyfile',
      \ 'rviminfo',
      \ 'substitute',
      \ 'sNext',
      \ 'sargument',
      \ 'sall',
      \ 'sandbox',
      \ 'saveas',
      \ 'sbuffer',
      \ 'sbNext',
      \ 'sball',
      \ 'sbfirst',
      \ 'sblast',
      \ 'sbmodified',
      \ 'sbnext',
      \ 'sbprevious',
      \ 'sbrewind',
      \ 'scriptnames',
      \ 'scriptencoding',
      \ 'scscope',
      \ 'set',
      \ 'setfiletype',
      \ 'setglobal',
      \ 'setlocal',
      \ 'sfind',
      \ 'sfirst',
      \ 'simalt',
      \ 'sign',
      \ 'silent',
      \ 'sleep',
      \ 'slast',
      \ 'smagic',
      \ 'smap',
      \ 'smapclear',
      \ 'smenu',
      \ 'snext',
      \ 'snomagic',
      \ 'snoremap',
      \ 'snoremenu',
      \ 'source',
      \ 'sort',
      \ 'split',
      \ 'spellgood',
      \ 'spelldump',
      \ 'spellinfo',
      \ 'spellrepall',
      \ 'spellundo',
      \ 'spellwrong',
      \ 'sprevious',
      \ 'srewind',
      \ 'stop',
      \ 'stag',
      \ 'startinsert',
      \ 'startgreplace',
      \ 'startreplace',
      \ 'stopinsert',
      \ 'stjump',
      \ 'stselect',
      \ 'sunhide',
      \ 'sunmap',
      \ 'sunmenu',
      \ 'suspend',
      \ 'sview',
      \ 'swapname',
      \ 'syntax',
      \ 'syntime',
      \ 'syncbind',
      \ 't',
      \ 'tcd',
      \ 'tchdir',
      \ 'tNext',
      \ 'tag',
      \ 'tags',
      \ 'tab',
      \ 'tabclose',
      \ 'tabdo',
      \ 'tabedit',
      \ 'tabfind',
      \ 'tabfirst',
      \ 'tabmove',
      \ 'tablast',
      \ 'tabnext',
      \ 'tabnew',
      \ 'tabonly',
      \ 'tabprevious',
      \ 'tabNext',
      \ 'tabrewind',
      \ 'tabs',
      \ 'tcl',
      \ 'tcldo',
      \ 'tclfile',
      \ 'terminal',
      \ 'tfirst',
      \ 'throw',
      \ 'tjump',
      \ 'tlast',
      \ 'tmap',
      \ 'tmapclear',
      \ 'tmenu',
      \ 'tnext',
      \ 'tnoremap',
      \ 'topleft',
      \ 'tprevious',
      \ 'trewind',
      \ 'try',
      \ 'tselect',
      \ 'tunmap',
      \ 'tunmenu',
      \ 'undo',
      \ 'undojoin',
      \ 'undolist',
      \ 'unabbreviate',
      \ 'unhide',
      \ 'unlet',
      \ 'unlockvar',
      \ 'unmap',
      \ 'unmenu',
      \ 'unsilent',
      \ 'update',
      \ 'vglobal',
      \ 'version',
      \ 'verbose',
      \ 'vertical',
      \ 'visual',
      \ 'view',
      \ 'vimgrep',
      \ 'vimgrepadd',
      \ 'viusage',
      \ 'vmap',
      \ 'vmapclear',
      \ 'vmenu',
      \ 'vnoremap',
      \ 'vnew',
      \ 'vnoremenu',
      \ 'vsplit',
      \ 'vunmap',
      \ 'vunmenu',
      \ 'write',
      \ 'wNext',
      \ 'wall',
      \ 'while',
      \ 'winsize',
      \ 'wincmd',
      \ 'windo',
      \ 'winpos',
      \ 'wnext',
      \ 'wprevious',
      \ 'wq',
      \ 'wqall',
      \ 'wsverb',
      \ 'wshada',
      \ 'wundo',
      \ 'wviminfo',
      \ 'xit',
      \ 'xall',
      \ 'xmap',
      \ 'xmapclear',
      \ 'xmenu',
      \ 'xnoremap',
      \ 'xnoremenu',
      \ 'xunmap',
      \ 'xunmenu',
      \ 'yank',
      \ 'z',
      \ '!',
      \ '#',
      \ '&',
      \ '<',
      \ ':',
      \ '>',
      \ '@',
      \ 'Next',
      \ '~',
      \ ]

let s:command_flags = {
      \ 'append': 3150083,
      \ 'abbreviate': 1059076,
      \ 'abclear': 1048836,
      \ 'aboveleft': 2180,
      \ 'all': 17667,
      \ 'amenu': 1079557,
      \ 'anoremenu': 1079557,
      \ 'args': 295182,
      \ 'argadd': 20751,
      \ 'argdelete': 16655,
      \ 'argdo': 18599,
      \ 'argedit': 315791,
      \ 'argglobal': 295182,
      \ 'arglocal': 295182,
      \ 'argument': 312583,
      \ 'ascii': 1573120,
      \ 'autocmd': 1058822,
      \ 'augroup': 1048854,
      \ 'aunmenu': 1059076,
      \ 'buffer': 247047,
      \ 'bNext': 50435,
      \ 'ball': 17665,
      \ 'badd': 1081756,
      \ 'bdelete': 83207,
      \ 'behave': 1048980,
      \ 'belowright': 2180,
      \ 'bfirst': 49411,
      \ 'blast': 49411,
      \ 'bmodified': 50435,
      \ 'bnext': 50435,
      \ 'botright': 2180,
      \ 'bprevious': 50435,
      \ 'brewind': 49411,
      \ 'break': 1573120,
      \ 'breakadd': 1048836,
      \ 'breakdel': 1048836,
      \ 'breaklist': 1048836,
      \ 'browse': 1050756,
      \ 'buffers': 1048838,
      \ 'bufdo': 18599,
      \ 'bunload': 83207,
      \ 'bwipeout': 214279,
      \ 'change': 3147075,
      \ 'cNext': 17667,
      \ 'cNfile': 17667,
      \ 'cabbrev': 1059076,
      \ 'cabclear': 1048836,
      \ 'caddbuffer': 16661,
      \ 'caddexpr': 2452,
      \ 'caddfile': 284,
      \ 'call': 1575045,
      \ 'catch': 1572868,
      \ 'cbuffer': 16663,
      \ 'cbottom': 256,
      \ 'cc': 17667,
      \ 'cclose': 17665,
      \ 'cd': 1048862,
      \ 'cdo': 18599,
      \ 'center': 3146053,
      \ 'cexpr': 2454,
      \ 'cfile': 286,
      \ 'cfdo': 18599,
      \ 'cfirst': 17667,
      \ 'cgetfile': 284,
      \ 'cgetbuffer': 16661,
      \ 'cgetexpr': 2452,
      \ 'chdir': 1048862,
      \ 'changes': 1048832,
      \ 'checkhealth': 260,
      \ 'checkpath': 1048834,
      \ 'checktime': 83205,
      \ 'chistory': 256,
      \ 'clist': 1048838,
      \ 'clast': 17667,
      \ 'close': 1066243,
      \ 'clearjumps': 1048832,
      \ 'cmap': 1059076,
      \ 'cmapclear': 1048836,
      \ 'cmenu': 1079557,
      \ 'cnext': 17667,
      \ 'cnewer': 17665,
      \ 'cnfile': 17667,
      \ 'cnoremap': 1059076,
      \ 'cnoreabbrev': 1059076,
      \ 'cnoremenu': 1079557,
      \ 'copy': 3146053,
      \ 'colder': 17665,
      \ 'colorscheme': 1048852,
      \ 'command': 1058822,
      \ 'comclear': 1048832,
      \ 'compiler': 1048854,
      \ 'continue': 1573120,
      \ 'confirm': 1050756,
      \ 'copen': 17665,
      \ 'cprevious': 17667,
      \ 'cpfile': 17667,
      \ 'cquit': 21763,
      \ 'crewind': 17667,
      \ 'cscope': 2060,
      \ 'cstag': 278,
      \ 'cunmap': 1059076,
      \ 'cunabbrev': 1059076,
      \ 'cunmenu': 1059076,
      \ 'cwindow': 17665,
      \ 'delete': 3147585,
      \ 'delmarks': 1048838,
      \ 'debug': 1575044,
      \ 'debuggreedy': 1069313,
      \ 'delcommand': 1048982,
      \ 'delfunction': 1048726,
      \ 'display': 1575172,
      \ 'diffupdate': 258,
      \ 'diffget': 2097413,
      \ 'diffoff': 258,
      \ 'diffpatch': 2097436,
      \ 'diffput': 261,
      \ 'diffsplit': 284,
      \ 'diffthis': 256,
      \ 'digraphs': 1048836,
      \ 'djump': 103,
      \ 'dlist': 1048679,
      \ 'doautocmd': 1048836,
      \ 'doautoall': 1048836,
      \ 'drop': 295308,
      \ 'dsearch': 1048679,
      \ 'dsplit': 103,
      \ 'edit': 295198,
      \ 'earlier': 1048852,
      \ 'echo': 1574916,
      \ 'echoerr': 1574916,
      \ 'echohl': 1573124,
      \ 'echomsg': 1574916,
      \ 'echon': 1574916,
      \ 'else': 1573120,
      \ 'elseif': 1574916,
      \ 'emenu': 1067397,
      \ 'endif': 1573120,
      \ 'endfunction': 1048832,
      \ 'endfor': 1573120,
      \ 'endtry': 1573120,
      \ 'endwhile': 1573120,
      \ 'enew': 258,
      \ 'ex': 295198,
      \ 'execute': 1574916,
      \ 'exit': 1311103,
      \ 'exusage': 256,
      \ 'file': 20767,
      \ 'files': 1048838,
      \ 'filetype': 1048836,
      \ 'filter': 2182,
      \ 'find': 311583,
      \ 'finally': 1573120,
      \ 'finish': 1573120,
      \ 'first': 295174,
      \ 'fold': 1573185,
      \ 'foldclose': 1573187,
      \ 'folddoopen': 2213,
      \ 'folddoclosed': 2213,
      \ 'foldopen': 1573187,
      \ 'for': 1574916,
      \ 'function': 1048582,
      \ 'global': 1572967,
      \ 'goto': 1590529,
      \ 'grep': 18831,
      \ 'grepadd': 18831,
      \ 'gui': 1343758,
      \ 'gvim': 1343758,
      \ 'help': 2054,
      \ 'helpclose': 17665,
      \ 'helpgrep': 2180,
      \ 'helptags': 1048972,
      \ 'hardcopy': 1319,
      \ 'highlight': 1573126,
      \ 'hide': 17671,
      \ 'history': 1048836,
      \ 'insert': 3145987,
      \ 'iabbrev': 1059076,
      \ 'iabclear': 1048836,
      \ 'if': 1574916,
      \ 'ijump': 103,
      \ 'ilist': 1048679,
      \ 'imap': 1059076,
      \ 'imapclear': 1048836,
      \ 'imenu': 1079557,
      \ 'inoremap': 1059076,
      \ 'inoreabbrev': 1059076,
      \ 'inoremenu': 1079557,
      \ 'intro': 1048832,
      \ 'isearch': 1048679,
      \ 'isplit': 103,
      \ 'iunmap': 1059076,
      \ 'iunabbrev': 1059076,
      \ 'iunmenu': 1059076,
      \ 'join': 7341379,
      \ 'jumps': 1048832,
      \ 'k': 1573141,
      \ 'keepmarks': 2180,
      \ 'keepjumps': 2180,
      \ 'keeppatterns': 2180,
      \ 'keepalt': 2180,
      \ 'list': 5244225,
      \ 'lNext': 17667,
      \ 'lNfile': 17667,
      \ 'last': 295174,
      \ 'language': 1048836,
      \ 'laddexpr': 2452,
      \ 'laddbuffer': 16661,
      \ 'laddfile': 284,
      \ 'later': 1048852,
      \ 'lbuffer': 16663,
      \ 'lbottom': 256,
      \ 'lcd': 1048862,
      \ 'lchdir': 1048862,
      \ 'lclose': 17665,
      \ 'lcscope': 2060,
      \ 'ldo': 18599,
      \ 'left': 3146053,
      \ 'leftabove': 2180,
      \ 'let': 1574916,
      \ 'lexpr': 2454,
      \ 'lfile': 286,
      \ 'lfdo': 18599,
      \ 'lfirst': 17667,
      \ 'lgetfile': 284,
      \ 'lgetbuffer': 16661,
      \ 'lgetexpr': 2452,
      \ 'lgrep': 18831,
      \ 'lgrepadd': 18831,
      \ 'lhelpgrep': 2180,
      \ 'lhistory': 256,
      \ 'll': 17667,
      \ 'llast': 17667,
      \ 'llist': 1048838,
      \ 'lmap': 1059076,
      \ 'lmapclear': 1048836,
      \ 'lmake': 2318,
      \ 'lnoremap': 1059076,
      \ 'lnext': 17667,
      \ 'lnewer': 17665,
      \ 'lnfile': 17667,
      \ 'loadview': 284,
      \ 'loadkeymap': 1048576,
      \ 'lockmarks': 2180,
      \ 'lockvar': 1572998,
      \ 'lolder': 17665,
      \ 'lopen': 17665,
      \ 'lprevious': 17667,
      \ 'lpfile': 17667,
      \ 'lrewind': 17667,
      \ 'ltag': 16662,
      \ 'lunmap': 1059076,
      \ 'lua': 1048709,
      \ 'luado': 1048741,
      \ 'luafile': 1048733,
      \ 'lvimgrep': 18831,
      \ 'lvimgrepadd': 18831,
      \ 'lwindow': 17665,
      \ 'ls': 1048838,
      \ 'move': 3146053,
      \ 'mark': 1573141,
      \ 'make': 2318,
      \ 'map': 1059078,
      \ 'mapclear': 1048838,
      \ 'marks': 1048836,
      \ 'match': 1064965,
      \ 'menu': 1079559,
      \ 'menutranslate': 1059076,
      \ 'messages': 1048837,
      \ 'mkexrc': 1048862,
      \ 'mksession': 286,
      \ 'mkspell': 2446,
      \ 'mkvimrc': 1048862,
      \ 'mkview': 286,
      \ 'mode': 1048852,
      \ 'mzscheme': 1573029,
      \ 'mzfile': 1048733,
      \ 'next': 311567,
      \ 'nbkey': 16516,
      \ 'nbclose': 1048832,
      \ 'nbstart': 1048852,
      \ 'new': 311583,
      \ 'nmap': 1059076,
      \ 'nmapclear': 1048836,
      \ 'nmenu': 1079557,
      \ 'nnoremap': 1059076,
      \ 'nnoremenu': 1079557,
      \ 'noremap': 1059078,
      \ 'noautocmd': 2180,
      \ 'nohlsearch': 1573120,
      \ 'noreabbrev': 1059076,
      \ 'noremenu': 1079559,
      \ 'noswapfile': 2180,
      \ 'normal': 1583239,
      \ 'number': 5244225,
      \ 'nunmap': 1059076,
      \ 'nunmenu': 1059076,
      \ 'oldfiles': 1573122,
      \ 'omap': 1059076,
      \ 'omapclear': 1048836,
      \ 'omenu': 1079557,
      \ 'only': 17667,
      \ 'onoremap': 1059076,
      \ 'onoremenu': 1079557,
      \ 'options': 256,
      \ 'ounmap': 1059076,
      \ 'ounmenu': 1059076,
      \ 'ownsyntax': 1574916,
      \ 'print': 5768513,
      \ 'packadd': 1573278,
      \ 'packloadall': 1573122,
      \ 'pclose': 258,
      \ 'perl': 1573029,
      \ 'perldo': 1048741,
      \ 'pedit': 295198,
      \ 'pop': 21763,
      \ 'popup': 1051014,
      \ 'ppop': 21763,
      \ 'preserve': 256,
      \ 'previous': 312583,
      \ 'promptfind': 1050628,
      \ 'promptrepl': 1050628,
      \ 'profile': 1048838,
      \ 'profdel': 1048836,
      \ 'psearch': 103,
      \ 'ptag': 20759,
      \ 'ptNext': 20739,
      \ 'ptfirst': 20739,
      \ 'ptjump': 278,
      \ 'ptlast': 258,
      \ 'ptnext': 20739,
      \ 'ptprevious': 20739,
      \ 'ptrewind': 20739,
      \ 'ptselect': 278,
      \ 'put': 3150659,
      \ 'pwd': 1048832,
      \ 'python': 1048709,
      \ 'pydo': 1048741,
      \ 'pyfile': 1048733,
      \ 'py3': 1048709,
      \ 'py3do': 1048741,
      \ 'python3': 1048709,
      \ 'py3file': 1048733,
      \ 'quit': 1066243,
      \ 'quitall': 258,
      \ 'qall': 1048834,
      \ 'read': 3412319,
      \ 'recover': 286,
      \ 'redo': 1048832,
      \ 'redir': 1048846,
      \ 'redraw': 1048834,
      \ 'redrawstatus': 1048834,
      \ 'registers': 1050884,
      \ 'resize': 1065237,
      \ 'retab': 3146103,
      \ 'return': 1574916,
      \ 'rewind': 295174,
      \ 'right': 3146053,
      \ 'rightbelow': 2180,
      \ 'rshada': 1048862,
      \ 'runtime': 1573262,
      \ 'rundo': 156,
      \ 'ruby': 1048709,
      \ 'rubydo': 1048741,
      \ 'rubyfile': 1048733,
      \ 'rviminfo': 1048862,
      \ 'substitute': 1048645,
      \ 'sNext': 312583,
      \ 'sargument': 312583,
      \ 'sall': 17667,
      \ 'sandbox': 2180,
      \ 'saveas': 1311038,
      \ 'sbuffer': 247047,
      \ 'sbNext': 50433,
      \ 'sball': 50433,
      \ 'sbfirst': 33024,
      \ 'sblast': 33024,
      \ 'sbmodified': 50433,
      \ 'sbnext': 50433,
      \ 'sbprevious': 50433,
      \ 'sbrewind': 33024,
      \ 'scriptnames': 1048832,
      \ 'scriptencoding': 1048852,
      \ 'scscope': 2052,
      \ 'set': 1573124,
      \ 'setfiletype': 1048964,
      \ 'setglobal': 1573124,
      \ 'setlocal': 1573124,
      \ 'sfind': 311583,
      \ 'sfirst': 295174,
      \ 'simalt': 1048980,
      \ 'sign': 1065093,
      \ 'silent': 1575046,
      \ 'sleep': 1066245,
      \ 'slast': 295174,
      \ 'smagic': 1048645,
      \ 'smap': 1059076,
      \ 'smapclear': 1048836,
      \ 'smenu': 1079557,
      \ 'snext': 311567,
      \ 'snomagic': 1048645,
      \ 'snoremap': 1059076,
      \ 'snoremenu': 1079557,
      \ 'source': 1573150,
      \ 'sort': 2099303,
      \ 'split': 311583,
      \ 'spellgood': 16775,
      \ 'spelldump': 258,
      \ 'spellinfo': 256,
      \ 'spellrepall': 256,
      \ 'spellundo': 16775,
      \ 'spellwrong': 16775,
      \ 'sprevious': 312583,
      \ 'srewind': 295174,
      \ 'stop': 1048834,
      \ 'stag': 20759,
      \ 'startinsert': 1048834,
      \ 'startgreplace': 1048834,
      \ 'startreplace': 1048834,
      \ 'stopinsert': 1048834,
      \ 'stjump': 278,
      \ 'stselect': 278,
      \ 'sunhide': 17665,
      \ 'sunmap': 1059076,
      \ 'sunmenu': 1059076,
      \ 'suspend': 1048834,
      \ 'sview': 311583,
      \ 'swapname': 1048832,
      \ 'syntax': 1050628,
      \ 'syntime': 1048980,
      \ 'syncbind': 256,
      \ 't': 3146053,
      \ 'tcd': 1048862,
      \ 'tchdir': 1048862,
      \ 'tNext': 20739,
      \ 'tag': 20759,
      \ 'tags': 1048832,
      \ 'tab': 2180,
      \ 'tabclose': 1069335,
      \ 'tabdo': 18597,
      \ 'tabedit': 315679,
      \ 'tabfind': 315807,
      \ 'tabfirst': 256,
      \ 'tabmove': 20757,
      \ 'tablast': 256,
      \ 'tabnext': 20757,
      \ 'tabnew': 315679,
      \ 'tabonly': 1069335,
      \ 'tabprevious': 20757,
      \ 'tabNext': 20757,
      \ 'tabrewind': 256,
      \ 'tabs': 1048832,
      \ 'tcl': 1048709,
      \ 'tcldo': 1048741,
      \ 'tclfile': 1048733,
      \ 'terminal': 1048590,
      \ 'tfirst': 20739,
      \ 'throw': 1572996,
      \ 'tjump': 278,
      \ 'tlast': 258,
      \ 'tmap': 1059076,
      \ 'tmapclear': 1048836,
      \ 'tmenu': 1079557,
      \ 'tnext': 20739,
      \ 'tnoremap': 1059076,
      \ 'topleft': 2180,
      \ 'tprevious': 20739,
      \ 'trewind': 20739,
      \ 'try': 1573120,
      \ 'tselect': 278,
      \ 'tunmap': 1059076,
      \ 'tunmenu': 1059076,
      \ 'undo': 1070337,
      \ 'undojoin': 1048832,
      \ 'undolist': 1048832,
      \ 'unabbreviate': 1059076,
      \ 'unhide': 17665,
      \ 'unlet': 1572998,
      \ 'unlockvar': 1572998,
      \ 'unmap': 1059078,
      \ 'unmenu': 1059078,
      \ 'unsilent': 1575044,
      \ 'update': 262527,
      \ 'vglobal': 1048677,
      \ 'version': 1048836,
      \ 'verbose': 1591429,
      \ 'vertical': 2180,
      \ 'visual': 295198,
      \ 'view': 295198,
      \ 'vimgrep': 18831,
      \ 'vimgrepadd': 18831,
      \ 'viusage': 256,
      \ 'vmap': 1059076,
      \ 'vmapclear': 1048836,
      \ 'vmenu': 1079557,
      \ 'vnoremap': 1059076,
      \ 'vnew': 311583,
      \ 'vnoremenu': 1079557,
      \ 'vsplit': 311583,
      \ 'vunmap': 1059076,
      \ 'vunmenu': 1059076,
      \ 'write': 1311103,
      \ 'wNext': 278879,
      \ 'wall': 1048834,
      \ 'while': 1574916,
      \ 'winsize': 388,
      \ 'wincmd': 1065109,
      \ 'windo': 18597,
      \ 'winpos': 1048836,
      \ 'wnext': 278815,
      \ 'wprevious': 278815,
      \ 'wq': 262527,
      \ 'wqall': 262462,
      \ 'wsverb': 16516,
      \ 'wshada': 1048862,
      \ 'wundo': 158,
      \ 'wviminfo': 1048862,
      \ 'xit': 1311103,
      \ 'xall': 258,
      \ 'xmap': 1059076,
      \ 'xmapclear': 1048836,
      \ 'xmenu': 1079557,
      \ 'xnoremap': 1059076,
      \ 'xnoremenu': 1079557,
      \ 'xunmap': 1059076,
      \ 'xunmenu': 1059076,
      \ 'yank': 1050433,
      \ 'z': 5243205,
      \ '!': 1048655,
      \ '#': 5244225,
      \ '&': 3145797,
      \ '<': 7341377,
      \ ':': 5243169,
      \ '>': 7341377,
      \ '@': 1048901,
      \ 'Next': 312583,
      \ '~': 3145797,
      \ }
