if has('win32')
  set shellslash
endif
execute 'set runtimepath+=' . expand('<sfile>:p:h:h')
runtime! plugin/*.vim
scriptencoding utf-8
let s:is_win = has('win32') || system('uname') =~# '\%(MSYS\|MINGW\)'

" test utility  "{{{
function! s:assert(a1, a2, kind) abort  "{{{
  if type(a:a1) == type(a:a2) && string(a:a1) ==# string(a:a2)
    return
  endif

  %delete
  call append(0, ['Got:', string(a:a1)])
  call append(0, [a:kind, '', 'Expect:', string(a:a2)])
  $delete
  1,$print
  cquit
endfunction
"}}}
function! s:quit_by_error() abort "{{{
  %delete
  call append(0, [printf('Catched the following error at %s.', v:throwpoint), v:exception])
  $delete
  1,$print
  cquit
endfunction
"}}}
"}}}
" testset "{{{
" NOTE: %s in keyseq is replaced to register assignment.
let s:testset = [
      \   {
      \     'keyseq': '%syiw',
      \     'yanked': "foo",
      \     'foo': 1,
      \     'bar': 0,
      \     'baz': 0,
      \   },
      \   {
      \     'keyseq': '%sy3e',
      \     'yanked': "foo\nbar\nbaz",
      \     'foo': 1,
      \     'bar': 1,
      \     'baz': 1,
      \   },
      \   {
      \     'keyseq': '%syy',
      \     'yanked': "foo\n",
      \     'foo': 1,
      \     'bar': 0,
      \     'baz': 0,
      \   },
      \   {
      \     'keyseq': '%syj',
      \     'yanked': "foo\nbar\n",
      \     'foo': 1,
      \     'bar': 1,
      \     'baz': 0,
      \   },
      \   {
      \     'keyseq': "%sy\<C-v>iw",
      \     'yanked': "foo",
      \     'foo': 1,
      \     'bar': 0,
      \     'baz': 0,
      \   },
      \   {
      \     'keyseq': "%sy\<C-v>3e",
      \     'yanked': "foo\nbar\nbaz",
      \     'foo': 1,
      \     'bar': 1,
      \     'baz': 1,
      \   },
      \
      \   {
      \     'keyseq': 'viw%sy',
      \     'yanked': "foo",
      \     'foo': 1,
      \     'bar': 0,
      \     'baz': 0,
      \   },
      \   {
      \     'keyseq': 'v3e%sy',
      \     'yanked': "foo\nbar\nbaz",
      \     'foo': 1,
      \     'bar': 1,
      \     'baz': 1,
      \   },
      \   {
      \     'keyseq': 'V%sy',
      \     'yanked': "foo\n",
      \     'foo': 1,
      \     'bar': 0,
      \     'baz': 0,
      \   },
      \   {
      \     'keyseq': 'Vj%sy',
      \     'yanked': "foo\nbar\n",
      \     'foo': 1,
      \     'bar': 1,
      \     'baz': 0,
      \   },
      \   {
      \     'keyseq': "\<C-v>iw%sy",
      \     'yanked': "foo",
      \     'foo': 1,
      \     'bar': 0,
      \     'baz': 0,
      \   },
      \   {
      \     'keyseq': "\<C-v>3e%sy",
      \     'yanked': "foo\nbar\nbaz",
      \     'foo': 1,
      \     'bar': 1,
      \     'baz': 1,
      \   },
      \ ]
let s:register_table = [
      \   {
      \     'clipboard': '',
      \     'keyseq': '',
      \     '@0': 1,
      \     '@"': 1,
      \     '@*': 0,
      \     '@+': 0,
      \     '@a': 0,
      \   },
      \   {
      \     'clipboard': 'unnamed',
      \     'keyseq': '',
      \     '@0': 1,
      \     '@"': 1,
      \     '@*': 1,
      \     '@+': s:is_win ? 1 : 0,
      \     '@a': 0,
      \   },
      \   {
      \     'clipboard': 'unnamedplus',
      \     'keyseq': '',
      \     '@0': 1,
      \     '@"': 1,
      \     '@*': 0,
      \     '@+': s:is_win ? 0 : 1,
      \     '@a': 0,
      \   },
      \   {
      \     'clipboard': 'unnamedplus,unnamed',
      \     'keyseq': '',
      \     '@0': 1,
      \     '@"': 1,
      \     '@*': 1,
      \     '@+': 1,
      \     '@a': 0,
      \   },
      \
      \   {
      \     'clipboard': '',
      \     'keyseq': '""',
      \     '@0': 1,
      \     '@"': 1,
      \     '@*': 0,
      \     '@+': 0,
      \     '@a': 0,
      \   },
      \   {
      \     'clipboard': 'unnamed',
      \     'keyseq': '""',
      \     '@0': 1,
      \     '@"': 1,
      \     '@*': 0,
      \     '@+': 0,
      \     '@a': 0,
      \   },
      \   {
      \     'clipboard': 'unnamedplus',
      \     'keyseq': '""',
      \     '@0': 1,
      \     '@"': 1,
      \     '@*': 0,
      \     '@+': 0,
      \     '@a': 0,
      \   },
      \   {
      \     'clipboard': 'unnamedplus,unnamed',
      \     'keyseq': '""',
      \     '@0': 1,
      \     '@"': 1,
      \     '@*': 0,
      \     '@+': 0,
      \     '@a': 0,
      \   },
      \
      \   {
      \     'clipboard': '',
      \     'keyseq': '"*',
      \     '@0': 0,
      \     '@"': 1,
      \     '@*': 1,
      \     '@+': s:is_win ? 1 : 0,
      \     '@a': 0,
      \   },
      \   {
      \     'clipboard': 'unnamed',
      \     'keyseq': '"*',
      \     '@0': 1,
      \     '@"': 1,
      \     '@*': 1,
      \     '@+': s:is_win ? 1 : 0,
      \     '@a': 0,
      \   },
      \   {
      \     'clipboard': 'unnamedplus',
      \     'keyseq': '"*',
      \     '@0': 0,
      \     '@"': 1,
      \     '@*': 1,
      \     '@+': s:is_win ? 1 : 0,
      \     '@a': 0,
      \   },
      \   {
      \     'clipboard': 'unnamedplus,unnamed',
      \     'keyseq': '"*',
      \     '@0': 0,
      \     '@"': 1,
      \     '@*': 1,
      \     '@+': s:is_win ? 1 : 0,
      \     '@a': 0,
      \   },
      \
      \   {
      \     'clipboard': '',
      \     'keyseq': '"+',
      \     '@0': 0,
      \     '@"': 1,
      \     '@*': 1,
      \     '@+': 1,
      \     '@a': 0,
      \   },
      \   {
      \     'clipboard': 'unnamed',
      \     'keyseq': '"+',
      \     '@0': 0,
      \     '@"': 1,
      \     '@*': 1,
      \     '@+': 1,
      \     '@a': 0,
      \   },
      \   {
      \     'clipboard': 'unnamedplus',
      \     'keyseq': '"+',
      \     '@0': 1,
      \     '@"': 1,
      \     '@*': 0,
      \     '@+': s:is_win ? 0 : 1,
      \     '@a': 0,
      \   },
      \   {
      \     'clipboard': 'unnamedplus,unnamed',
      \     'keyseq': '"+',
      \     '@0': 1,
      \     '@"': 1,
      \     '@*': 1,
      \     '@+': 1,
      \     '@a': 0,
      \   },
      \
      \   {
      \     'clipboard': '',
      \     'keyseq': '"a',
      \     '@0': 0,
      \     '@"': 1,
      \     '@*': 0,
      \     '@+': 0,
      \     '@a': 1,
      \   },
      \   {
      \     'clipboard': 'unnamed',
      \     'keyseq': '"a',
      \     '@0': 0,
      \     '@"': 1,
      \     '@*': 0,
      \     '@+': 0,
      \     '@a': 1,
      \   },
      \   {
      \     'clipboard': 'unnamedplus',
      \     'keyseq': '"a',
      \     '@0': 0,
      \     '@"': 1,
      \     '@*': 0,
      \     '@+': 0,
      \     '@a': 1,
      \   },
      \   {
      \     'clipboard': 'unnamedplus,unnamed',
      \     'keyseq': '"a',
      \     '@0': 0,
      \     '@"': 1,
      \     '@*': 0,
      \     '@+': 0,
      \     '@a': 1,
      \   },
      \ ]
function! s:is_highlighted(lnum) abort
  let matchlist = filter(getmatches(), 'v:val.group ==# "HighlightedyankRegion"')
  let lnumlist = []
  for hi in matchlist
    let lnumlist += [get(hi, 'pos1', [0])[0]]
    let lnumlist += [get(hi, 'pos2', [0])[0]]
    let lnumlist += [get(hi, 'pos3', [0])[0]]
    let lnumlist += [get(hi, 'pos4', [0])[0]]
    let lnumlist += [get(hi, 'pos5', [0])[0]]
    let lnumlist += [get(hi, 'pos6', [0])[0]]
    let lnumlist += [get(hi, 'pos7', [0])[0]]
    let lnumlist += [get(hi, 'pos8', [0])[0]]
  endfor
  call filter(lnumlist, 'v:val != 0')
  return match(lnumlist, a:lnum) > -1
endfunction
"}}}

try

map y <Plug>(highlightedyank)
call append(0, ['foo', 'bar', 'baz'])

for s:register in s:register_table
  for s:test in s:testset
    let &clipboard = s:register.clipboard
    let [@0, @", @*, @+, @a] = ['', '', '', '', '']

    let s:keyseq = printf(s:test.keyseq, s:register.keyseq)
    call feedkeys('gg' . s:keyseq, 'tx')
    call s:assert(@0, s:register['@0'] ? s:test.yanked : '', printf('keyseq: %s (clipboard: "%s") %s', s:keyseq, s:register.clipboard, printf('-> @0: "%s"', @0)))
    call s:assert(@", s:register['@"'] ? s:test.yanked : '', printf('keyseq: %s (clipboard: "%s") %s', s:keyseq, s:register.clipboard, printf('-> @": "%s"', @")))
    call s:assert(@*, s:register['@*'] ? s:test.yanked : '', printf('keyseq: %s (clipboard: "%s") %s', s:keyseq, s:register.clipboard, printf('-> @*: "%s"', @*)))
    call s:assert(@+, s:register['@+'] ? s:test.yanked : '', printf('keyseq: %s (clipboard: "%s") %s', s:keyseq, s:register.clipboard, printf('-> @+: "%s"', @+)))
    call s:assert(@a, s:register['@a'] ? s:test.yanked : '', printf('keyseq: %s (clipboard: "%s") %s', s:keyseq, s:register.clipboard, printf('-> @+: "%s"', @a)))
    call s:assert(s:is_highlighted(1), s:test.foo, printf('keyseq: %s -> foo is %shighlighted.', s:keyseq, s:test.foo ? 'not ' : ''))
    call s:assert(s:is_highlighted(2), s:test.bar, printf('keyseq: %s -> bar is %shighlighted.', s:keyseq, s:test.bar ? 'not ' : ''))
    call s:assert(s:is_highlighted(3), s:test.baz, printf('keyseq: %s -> baz is %shighlighted.', s:keyseq, s:test.baz ? 'not ' : ''))

    call highlightedyank#highlight#cancel()
  endfor
endfor

catch
  call s:quit_by_error()
endtry
qall!

" vim:set foldmethod=marker:
" vim:set commentstring="%s:
