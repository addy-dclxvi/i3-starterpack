" Plugin:       Highlight Colornames and Values
" Maintainer:   Christian Brabandt <cb@256bit.org>
" URL:          http://www.github.com/chrisbra/color_highlight
" Last Change: Thu, 15 Jan 2015 21:49:17 +0100
" Licence:      Vim License (see :h License)
" Version:      0.11
" GetLatestVimScripts: 3963 11 :AutoInstall: Colorizer.vim
"
" This plugin was inspired by the css_color.vim plugin from Nikolaus Hofer.
" Changes made: - make terminal colors work more reliably and with all
"                 color terminals
"               - performance improvements, coloring is almost instantenously
"               - detect rgb colors like this: rgb(R,G,B)
"               - detect hsl coloring: hsl(H,V,L)
"               - fix small bugs

" Init some variables "{{{1
" Plugin folklore "{{{2
if v:version < 700 || exists("g:loaded_colorizer") || &cp
  finish
endif
let g:loaded_colorizer = 1

let s:cpo_save = &cpo
set cpo&vim

" helper functions "{{{1
fu! ColorHiArgs(A,L,P)
    return "syntax\nmatch\nnosyntax\nnomatch"
endfu

" define commands "{{{1
command! -bang -range=%  -nargs=? -complete=custom,ColorHiArgs ColorHighlight
        \ :call Colorizer#DoColor(<q-bang>, <q-line1>, <q-line2>, <q-args>)
command! -bang -nargs=1  RGB2Term  
        \ :call Colorizer#RGB2Term(<q-args>, <q-bang>)
command! -nargs=1  Term2RGB     :call Colorizer#Term2RGB(<q-args>)

command! -bang    ColorClear    :call Colorizer#ColorOff()
command! -bang    ColorToggle   :call Colorizer#ColorToggle()
command! -nargs=1 HSL2RGB       :call Colorizer#HSL2Term(<q-args>)
command!          ColorContrast :call Colorizer#SwitchContrast()
command!          ColorSwapFgBg :call Colorizer#SwitchFGBG()

" define mappings "{{{1
nnoremap <Plug>Colorizer        :<C-U>ColorToggle<CR>
xnoremap <Plug>Colorizer        :ColorHighlight<CR>
nnoremap <Plug>ColorContrast    :<C-U>ColorContrast<CR>
xnoremap <Plug>ColorContrast    :<C-U>ColorContrast<CR>
nnoremap <Plug>ColorFgBg        :<C-U>ColorSwapFgBg<CR>
xnoremap <Plug>ColorFgBg        :<C-U>ColorSwapFgBg<CR>

if get(g:, 'colorizer_auto_map', 0)
    " only map, if the mapped keys are not yet taken by a different plugin
    " and the user hasn't mapped the function to different keys
    if empty(maparg('<Leader>cC', 'n')) && empty(hasmapto('<Plug>Colorizer', 'n'))
        nmap <silent> <Leader>cC <Plug>Colorizer
    endif
    if empty(maparg('<Leader>cC', 'x')) && empty(hasmapto('<Plug>Colorizer', 'x'))
        xmap <silent> <Leader>cC <Plug>Colorizer
    endif
    if empty(maparg('<Leader>cT', 'n')) && empty(hasmapto('<Plug>ColorContrast', 'n'))
        nmap <silent> <Leader>cT <Plug>ColorContrast
    endif
    if empty(maparg('<Leader>cT', 'x')) && empty(hasmapto('<Plug>ColorContrast', 'n'))
        xmap <silent> <Leader>cT <Plug>ColorContrast
    endif
    if empty(maparg('<Leader>cF', 'n')) && empty(hasmapto('<Plug>ColorFgBg', 'n'))
        nmap <silent> <Leader>cF <Plug>ColorFgBg
    endif
    if empty(maparg('<Leader>cF', 'x')) && empty(hasmapto('<Plug>ColorFgBg', 'x'))
        xmap <silent> <Leader>cF <Plug>ColorFgBg
    endif
endif

" Enable Autocommands "{{{1
if exists("g:colorizer_auto_color")
    " Prevent autoloading
    exe "call Colorizer#AutoCmds(g:colorizer_auto_color)"
endif

if exists("g:colorizer_auto_filetype")
    " Setup some autocommands for specific filetypes.
    aug FT_ColorizerPlugin
        au!
        exe "au Filetype" g:colorizer_auto_filetype 
                    \ "call Colorizer#LocalFTAutoCmds(1)\|
                    \ :ColorHighlight"
    aug END
endif

" Plugin folklore and Vim Modeline " {{{1
let &cpo = s:cpo_save
unlet s:cpo_save
" vim: set foldmethod=marker et fdl=0:
