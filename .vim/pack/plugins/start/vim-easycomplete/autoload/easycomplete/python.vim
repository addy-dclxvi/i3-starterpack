" 兼容非 python3 场景，确保不报错
function! s:PreparePythonEnvironment()
  if get(g:, 'easycomplete_python3_ready') == 2
    return v:true
  endif

  if get(g:, 'easycomplete_python3_ready') == 1
    return v:false
  endif

  if !has("python3")
    let g:easycomplete_python3_ready = 1
    return v:false
  else
    py3 import vim
    py3 import EasyCompleteUtil.util as EasyCompleteUtil
    let g:easycomplete_python3_ready = 2
    return v:true
  endif
endfunction

function! easycomplete#python#GetArch()
  if !s:PreparePythonEnvironment() | return "" | endif
  py3 vim.command("let ret = '%s'"% EasyCompleteUtil.get_arch())
  return ret
endfunction

function! easycomplete#python#IsMacOS()
  if !s:PreparePythonEnvironment() | return "" | endif
  py3 vim.command("let ret = %s"% EasyCompleteUtil.is_macos())
  return ret
endfunction

function! easycomplete#python#NormalizeSortPY(items)
  if !s:PreparePythonEnvironment() | return a:items | endif
  try
    py3 vim.command("let ret = %s"% EasyCompleteUtil.normalize_sort(vim.eval("a:items")))
  catch
    echom "python -> vim data format parsing error"
    echom v:exception
  endtry
  return ret
endfunction

" 实测性能不如 VIM 的实现，一般不用
function! easycomplete#python#FuzzySearchPy(needle, haystack)
  if !s:PreparePythonEnvironment() | return 0 | endif
  let needle = tolower(a:needle)
  let haystack = tolower(a:haystack)
  py3 needle = vim.eval("needle")
  py3 haystack = vim.eval("haystack")
  py3 vim.command("let ret = %s"% EasyCompleteUtil.fuzzy_search(needle, haystack))
  return ret
endfunction

" TODO
function! easycomplete#python#CompleteMenuFilterPy(all_menu, word, maxlength)
  if !s:PreparePythonEnvironment() | return a:all_menu | endif
  py3 all_menu = vim.eval("a:all_menu")
  py3 word = vim.eval("a:word")
  py3 maxlength = int(vim.eval("a:maxlength"))
  py3 vim.command('let ret = %s'% EasyCompleteUtil.complete_menu_filter(all_menu, word, maxlength))
  echom ret
  return ret
endfunction

function! easycomplete#python#GetSnippetsCodeInfo(snip_object)
  if !s:PreparePythonEnvironment() | return "" | endif
  py3 filepath = vim.eval("a:snip_object.filepath")
  py3 line_number = int(vim.eval("a:snip_object.line_number"))
  py3 vim.command('let ret = %s'% EasyCompleteUtil.snippets_code_info(filepath, line_number))
  return ret
endfunction

function! easycomplete#python#Sha256(str)
  if !s:PreparePythonEnvironment() | return a:str | endif
  py3 str = vim.eval("a:str")
  py3 vim.command('let ret = "%s"'% EasyCompleteUtil.get_sha256(str))
  return ret
endfunction

function! easycomplete#python#ListDir(path)
  if !s:PreparePythonEnvironment() | return [] | endif
  py3 path_str = vim.eval("a:path")
  py3 vim.command('let ret = %s'% EasyCompleteUtil.listdir(path_str))
  return ret
endfunction
