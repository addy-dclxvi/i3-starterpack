" highlighted-yank: Make the yanked region apparent!
" Last Change: 15-Mar-2018.
" Maintainer : Masaaki Nakamura <mckn@outlook.com>

" License    : NYSL
"              Japanese <http://www.kmonos.net/nysl/>
"              English (Unofficial) <http://www.kmonos.net/nysl/index.en.html>
if exists("g:loaded_highlightedyank")
  finish
endif
let g:loaded_highlightedyank = 1

" highlight group
function! s:default_highlight() abort
  highlight default link HighlightedyankRegion IncSearch
endfunction
call s:default_highlight()
augroup highlightedyank-event-ColorScheme
  autocmd!
  autocmd ColorScheme * call s:default_highlight()
augroup END

if exists('##TextYankPost') && !hasmapto('<Plug>(highlightedyank)') && !exists('g:highlightedyank_disable_autocmd')
  augroup highlightedyank
    autocmd!
    autocmd TextYankPost * call highlightedyank#debounce()
  augroup END

  " commands
  command! -nargs=0 -bar HighlightedyankOn     call highlightedyank#on()
  command! -nargs=0 -bar HighlightedyankOff    call highlightedyank#off()
  command! -nargs=0 -bar HighlightedyankToggle call highlightedyank#toggle()
else
  function! s:keymap() abort
    if stridx(&cpoptions, 'y') < 0
      nnoremap <silent> <Plug>(highlightedyank) :<C-u>call highlightedyank#obsolete#highlightedyank#yank('n')<CR>
      xnoremap <silent> <Plug>(highlightedyank) :<C-u>call highlightedyank#obsolete#highlightedyank#yank('x')<CR>
      onoremap          <Plug>(highlightedyank) y
    else
      noremap  <silent> <Plug>(highlightedyank-g@) g@
      noremap  <expr>   <Plug>(highlightedyank-setoperatorfunc) highlightedyank#obsolete#highlightedyank#setoperatorfunc()
      nmap     <silent> <Plug>(highlightedyank) <Plug>(highlightedyank-setoperatorfunc)<Plug>(highlightedyank-g@)
      xmap     <silent> <Plug>(highlightedyank) <Plug>(highlightedyank-setoperatorfunc)<Plug>(highlightedyank-g@)
      onoremap          <Plug>(highlightedyank) g@
    endif
  endfunction
  call s:keymap()

  if exists('##OptionSet')
    augroup highlightedyank-event-OptionSet
      autocmd!
      autocmd OptionSet cpoptions call s:keymap()
    augroup END
  endif

  " commands
  command! -nargs=0 -bar HighlightedyankOn     call highlightedyank#obsolete#highlightedyank#on()
  command! -nargs=0 -bar HighlightedyankOff    call highlightedyank#obsolete#highlightedyank#off()
  command! -nargs=0 -bar HighlightedyankToggle call highlightedyank#obsolete#highlightedyank#toggle()
endif

