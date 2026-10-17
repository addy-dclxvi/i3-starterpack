" Chained completion that works as I want!
" Maintainer: Lifepillar <lifepillar@lifepillar.me>
" License: MIT

let s:messages = []
let s:errors = []
let s:done = 0
let s:fail = 0
let s:time_passed = 0.0

fun! RunTheTest(test)
  let s:done += 1

  let l:message = a:test
  let l:start_time = reltime()

  try
    exe 'call ' . a:test
  catch
    call add(v:errors, 'Caught exception in ' . a:test . ': ' . v:exception . ' @ ' . v:throwpoint)
  endtry

  let l:message .= ' (' . printf('%.01f', 1000.0 * reltimefloat(reltime(l:start_time))) . 'ms) '

  if len(v:errors) > 0
    let s:fail += 1
    let l:message .= 'FAILED'
    call add(s:errors, '')
    call add(s:errors, a:test)
    for l:err in v:errors
      if l:err =~# '^Caught exception'
        call add(s:errors, substitute(l:err, '^Caught exception\zs.*: Vim[^:]*\ze:', '', ''))
      else
        call add(s:errors, substitute(l:err, '^.*\zeline \d\+', '', ''))
      endif
    endfor
    let v:errors = []
  else
    let l:message .= '✔︎'
  endif
  call add(s:messages,  l:message)
endfunc

fun! FinishTesting()
  call add(s:messages, '')
  call add(s:messages, 'Run ' . s:done . (s:done > 1 ? ' tests' : ' test') . ' in ' . printf('%.03f', s:time_passed) . 's')
  if s:fail == 0
    call add(s:messages, 'ALL TESTS PASSED! ✔︎')
  else
    call add(s:messages, s:fail . (s:fail > 1 ? ' tests' : ' test') . ' failed')
  endif

  botright new +setlocal\ buftype=nofile\ bufhidden=wipe\ nobuflisted\ noswapfile\ wrap
  call append(line('$'), s:messages)
  call append(line('$'), '')
  call append(line('$'), s:errors)
  call matchadd('Identifier', '✔︎')
  call matchadd('WarningMsg', '\<FAILED\>')
  call matchadd('WarningMsg', '^\d\+ tests\? failed')
  call matchadd('Keyword', '^\<line \d\+')
  call matchadd('Constant', '\<Expected\>')
  call matchadd('Constant', '\<but got\>')
  call matchadd('ErrorMsg', 'Caught exception')
endf

fun! RunBabyRun(...)
  " Locate Test_ functions and execute them.
  redir @t
  execute 'silent function /^Test_'.(a:0 > 0 ? a:1 : '')
  redir END
  let s:tests = split(substitute(@t, 'function \(\k*()\)', '\1', 'g'))

  let l:start_time = reltime()

  for s:test in sort(s:tests)
    call RunTheTest(s:test)
  endfor

  let s:time_passed = reltimefloat(reltime(l:start_time))

  call FinishTesting()
endf

