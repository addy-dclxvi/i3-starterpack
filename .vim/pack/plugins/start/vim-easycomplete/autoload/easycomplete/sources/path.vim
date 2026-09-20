let s:util_toolkit = has('nvim') ? v:lua.require("easycomplete.util") : v:null

function! easycomplete#sources#path#completor(opt, ctx)
  let l:typing_path = s:TypingAPath(a:ctx)
  if !l:typing_path.is_path
    call easycomplete#complete(a:opt['name'], a:ctx, a:ctx['startcol'], [])
    return v:true
  endif
  call easycomplete#util#timer_start(
        \ "easycomplete#sources#path#CompleteHandler",
        \ [a:ctx['typing'], a:opt['name'], a:ctx, a:ctx['startcol'], l:typing_path],
        \ 10 )
  " 展开目录时，中断其他complete逻辑
  " 中断其他 complete 逻辑，设计上的问题，这里要用异步调
  " easycomplete#complete()
  return v:false
endfunction

function! easycomplete#sources#path#CompleteHandler(...)
  return call(function("s:CompleteHandler"), a:000)
endfunction

function! s:CompleteHandler(typing, name, ctx, startcol, typing_path)
  if g:easycomplete_path_enable == 0
    call easycomplete#complete(a:name, a:ctx, a:startcol, [])
    return
  endif
  let spath_start = a:typing_path.short_path_start
  try
    let result = s:GetDirAndFiles(a:typing_path, a:typing_path.fname)
  catch
    call s:errlog('[Path]', v:exception)
    return
  endtry
  if len(result) == 0
    if strwidth(a:ctx['char']) != 1
      call feedkeys("\<Tab>", "in")
    endif
  endif
  call easycomplete#complete(a:name, a:ctx, a:startcol, result)
endfunction

function! easycomplete#sources#path#pum()
  if g:env_is_vim && (!pumvisible() || !exists('g:easycomplete_stunt_menuitems'))
    return v:valse
  endif
  if g:env_is_nvim && (!easycomplete#pum#visible() || !exists('g:easycomplete_stunt_menuitems'))
    return v:valse
  endif
  if empty(g:easycomplete_stunt_menuitems)
    return v:false
  endif
  if get(g:easycomplete_stunt_menuitems[-1], 'plugin_name', "") == "path"
    return v:true
  endif
  return v:false
endfunction

" 根据输入的 path 匹配出结果，返回的是一个List ['f1','f2','d1','d2']
" 查询条件实际上是用 base 来做的，typing_path 里无法包含当前敲入的filename
" ./ => 基于当前 bufpath 查询
" ../../ => 当前buf文件所在的目录向上追溯2次查询
" /a/b/c => 直接从根查询
" TODO ~/ 的支持
function! s:GetDirAndFiles(typing_path, base)
  let fpath   = easycomplete#util#GetFullName(a:typing_path.fpath)
  let fname   = bufname('%')
  let bufpath = s:GetPathName(fname)

  if len(fpath) > 0 && fpath[0] == "."
    let path = simplify(bufpath . fpath)
  else
    let path = simplify(fpath)
  endif
  let l:base = a:base
  if l:base == ""
    " 查找目录下的文件和目录
    let result_list = easycomplete#util#ls(path)
  else
    " TODO 这里没考虑Cygwin的情况
    let result_list = easycomplete#util#ls(s:GetPathName(path))
    " 使用filter过滤，没有使用grep过滤，以便后续性能调优
    " TODO：当按<Del>键时，自动补全窗会跟随匹配，但无法做到忽略大小写
    " 只有首次点击<Tab>时能忽略大小写，
    " 应该在del跟随和tab时都忽略大小写才对
    if exists('*matchfuzzy')
      let result_list = result_list->matchfuzzy(l:base)
    else
      let result_list = filter(result_list,
            \ 'tolower(v:val) =~ "^'. tolower(substitute(l:base, "\\.", "\\\\\\\\.", "g")) . '"')
    endif
  endif
  return s:GetWrappedFileAndDirsList(result_list, s:GetPathName(path), l:base)
endfunction

function! easycomplete#sources#path#GetDirAndFiles(typing_path, base)
  return s:GetDirAndFiles(a:typing_path, a:base)
endfunction

" 将某个目录下查找出的列表 List 的每项识别出目录和文件
" 并转换成补全浮窗所需的展示格式
function! s:GetWrappedFileAndDirsList(rlist, fpath, base)
  if len(a:rlist) == 0
    return []
  endif

  let dir_menu = g:easycomplete_menu_abbr ? '[Dir]' : 'folder'
  let file_menu = g:easycomplete_menu_abbr ? '[File]' : 'file'

  if a:base[-1:] == "."
    let l:pfx = a:base
  else
    let l:pfx = ""
  endif

  let result_with_kind = []
  for item in a:rlist
    let localfile = simplify(a:fpath . '/' . item)
    if isdirectory(localfile)
      if g:easycomplete_nerd_font == 0
        call add(result_with_kind, {"word": item[strwidth(l:pfx):] . "/", "abbr":item, "menu" : dir_menu, "kind": ""})
      else
        call add(result_with_kind, {"word": item[strwidth(l:pfx):] . "/", "abbr":item,
              \ "menu" : dir_menu, "kind": g:easycomplete_lsp_type_font["folder"] })
      endif
    else
      if g:easycomplete_nerd_font == 0
        call add(result_with_kind, {"word": item[strwidth(l:pfx):], "abbr":item,"menu" : file_menu, "kind":""})
      else
        call add(result_with_kind, {"word": item[strwidth(l:pfx):], "abbr": item,
              \ "menu" : file_menu,
              \ "kind": g:easycomplete_lsp_type_font["file"]
              \ })
      endif
    endif
  endfor

  return result_with_kind
endfunction

function! easycomplete#sources#path#TypingAPath(...)
  return call(function('s:TypingAPath'), a:000)
endfunction

function! s:GetFullPath(prefx)
  if g:env_is_nvim
    let fpath = s:util_toolkit.get_fullpath(a:prefx)
  else
    try
      let fpath = matchstr(a:prefx,"\\([\\(\\) \"'\\t\\[\\]\\{\\}]\\)\\@<=" .
            \   "\\([\\/\\.\\~]\\+[\\.\\/a-zA-Z0-9\u2e80-\uef4f\\_\\- ]\\+\\|[\\.\\/]\\)")
    catch /^Vim\%((\a\+)\)\=:E945/
      let fpath = matchstr(a:prefx,"\\([\\(\\) \"'\\t\\[\\]\\{\\}]\\)\\@<=" .
            \   "\\([\\/\\.\\~]\\+[\\.\\/a-zA-Z0-9\\_\\- ]\\+\\|[\\.\\/]\\)")
    endtry
  endif
  return fpath
endfunction

" 判断当前是否正在输入一个地址path
" base 原本想传入当前文件名字，实际上传不进来，这里也没用到
" s:TypingAPath(ctx) 参数是ctx时，在当前脚本中调用
" s:TypingAPath()    参数留空时，只在cmdline里调用
function! s:TypingAPath(...)
  " TODO 这里不清楚为什么
  " 输入 ./a/b/c ，./a/b/  两者得到的prefx都为空
  " 前者应该得到 c, 这里只能临时将base透传进来表示文件名
  if exists("g:easycomplete_cmdline_typing") && g:easycomplete_cmdline_typing == 1
    let line = getcmdline()
    let coln = getcmdpos() - 1
  else
    let l:ctx = a:1
    let line  = getline('.')
    let coln  = l:ctx['col'] - 1
  endif
  let prefx = ' ' . line[0:coln - 1]

  " 需要注意，参照上一个注释，fpath和spath只是path，没有filename
  " 从正在输入的一整行字符(行首到光标)中匹配出一个path出来
  " TODO 正则不严格，需要优化，下面这几个情况匹配要正确
  "   \ a <Tab>  => done
  "   \<Tab> => done
  "   xxxss \ xxxss<Tab> => done
  " MoreInfo: #140
  let fpath = s:GetFullPath(prefx)
  " 兼容单个 '/' 匹配的情况
  let spath = s:GetPathName(substitute(fpath,"^[\\.\\/].*\\/","./","g"))
  " 清除对 '\' 的路径识别
  let fpath = s:GetPathName(fpath)

  let pathDict                 = {}
  let pathDict.line            = line
  let pathDict.prefx           = prefx
  let pathDict.fname           = s:GetFileName(prefx)
  let pathDict.fpath           = fpath " fullpath
  let pathDict.spath           = spath " shortpath
  let pathDict.full_path_start = coln - len(fpath) + 2
  if trim(pathDict.fname) == ''
    let pathDict.short_path_start = coln - len(spath) + 2
  else
    let pathDict.short_path_start = coln - len(pathDict.fname)
  endif

  " 排除掉输入注释的情况
  " 因为如果输入'//'紧跟<Tab>不应该出<C-X><C-U><C-N>出补全菜单
  if len(fpath) == 0 || match(prefx,"\\(\\/\\/\\|\\/\\*\\)") >= 0
    let pathDict.is_path = 0
  elseif fpath == "/"
    let pathDict.is_path = 0
  else
    let pathDict.is_path = 1
  endif

  return pathDict
endfunction

" 从一个完整的 path 串中得到 FileName
" 输入的 Path 串可以带有文件名
function! s:GetFileName(path)
  return easycomplete#util#GetFileName(a:path)
endfunction

function! s:GetPathName(path)
  let path =  simplify(a:path)
  let pathname = matchstr(path,"^.*\\/")
  return pathname
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! s:errlog(...)
  return call('easycomplete#util#errlog', a:000)
endfunction
