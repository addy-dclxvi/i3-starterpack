let s:installer_dir = expand('<sfile>:h:h') . '/easycomplete/installer'
let s:root_dir = expand('<sfile>:h:h')
let s:data_dir = easycomplete#util#ConfigRoot()
" LSP Server 安装目录，目录结构：
" ~/.config/vim-easycomplete/
"     └─ servers/
"         ├─ sh/                           <------  plugin name
"         │   ├─ bash-language-server      <------  command
"         │   ├─ package.json
"         │   └─ node_modules/
"         └─ css/                          <------  plugin name
"             ├─ css-language-server       <------  command
"             ...
let s:lsp_servers_dir = s:data_dir . '/servers'
let s:nvim_lsp_servers_dir = easycomplete#util#NVimLspInstallRoot()

function! easycomplete#installer#InstallerDir() abort
  return s:installer_dir
endfunction

function! easycomplete#installer#LspServerDir() abort
  return s:lsp_servers_dir
endfunction

function! easycomplete#installer#GetCommand(name)
  if !easycomplete#ok('g:easycomplete_enable')
    return ''
  endif
  let opt = easycomplete#GetOptions(a:name)
  if a:name == ""
    return ''
  endif
  if empty(opt)
    call easycomplete#util#info('[error]', 'GetCommand("' . a:name . '"): plugin options is null')
    return ''
  endif
  let cmd = opt['command']
  let local_cmd = easycomplete#installer#LspServerDir() . '/' . a:name . '/' . cmd
  if executable(local_cmd)
    return local_cmd
  endif
  if executable(cmd)
    return cmd
  endif
  return ''
endfunction

function! s:LspCmdInstalled(name)
  let opt = easycomplete#GetOptions(a:name)
  if empty(opt)
    call easycomplete#util#info('[error]', 'LspCmdInstalled(): plugin options is null')
    return v:false
  endif
  let cmd = get(opt, 'command', '')
  return s:executable(cmd)
endfunction

function! easycomplete#installer#install(...) abort
  let lsp_plugin = easycomplete#util#GetLspPlugin()
  if (!exists('a:1') || empty('a:1')) && !has_key(lsp_plugin, 'name')
    call easycomplete#util#info('Error,', 'Unknown filetype.')
    return
  endif
  try
    let l:name = exists('a:1') ?
              \ ( a:1 == "" ? easycomplete#util#GetLspPlugin()['name'] : a:1)
              \ : easycomplete#util#GetLspPlugin()['name']
  catch
    call s:log("Please install LSP Server with correct command or under supported filetype.")
    return
  endtry
  if l:name == "tabnine"
    let l:name = "tn"
  endif
  let s:name = l:name
  if s:LspCmdInstalled(l:name)
    call easycomplete#confirm#pop(l:name . " lsp server is already installed. reinstall it again?",
          \ function("s:ConfirmCallback"))
  else
    call s:ConfirmCallback(v:null, 1)
  endif
endfunction

function! s:ConfirmCallback(error, res)
  if !empty(a:error)
    call s:log(a:error)
    return
  endif

  if a:res == 1
    call s:DoInstall(s:name)
  else
    call easycomplete#util#info("Stop reinstall.")
  endif
endfunction

function! s:DoInstall(name)
  let l:name = a:name
  let l:install_script = easycomplete#installer#InstallerDir() . '/' . l:name . '.sh'
  let l:lsp_server_dir = easycomplete#installer#LspServerDir() . '/' . l:name

  " prepare auth of exec script
  call setfperm(l:install_script, 'rwxr-xr-x')
  for script_name in ['/npm_install.sh', '/pip_install.sh', '/go_install.sh']
    call setfperm(easycomplete#installer#InstallerDir() . script_name, 'rwxr-xr-x')
  endfor

  if !filereadable(l:install_script)
    call easycomplete#util#info('Error,', 'Install script is not found.')
    return
  endif

  if isdirectory(l:lsp_server_dir)
    call easycomplete#util#info('Uninstalling', l:name)
    call delete(l:lsp_server_dir, 'rf')
  endif

  call mkdir(l:lsp_server_dir, 'p')
  call easycomplete#util#info('Installing', l:name, 'lsp server ...')

  if has('nvim')
    split new
    call termopen(l:install_script, {
          \ 'cwd': l:lsp_server_dir,
          \ 'on_exit': function('s:InstallServerPost', [l:name])
          \ })
    startinsert
  else
    let l:bufnr = term_start(l:install_script, {'cwd': l:lsp_server_dir})
    let l:job = term_getjob(l:bufnr)
    if l:job != v:null
      call job_setoptions(l:job, {'exit_cb': function('s:InstallServerPost', [l:name])})
    endif
  endif
endfunction

function! s:InstallServerPost(command, job, code, ...) abort
  if a:code != 0
    return
  endif
  if s:executable(a:command)
    call easycomplete#Enable()
  endif
  call easycomplete#util#info('Done!', a:command, 'lsp server installed successfully!')
endfunction

function! s:executable(cmd) abort
  if executable(a:cmd)
    return v:true
  endif
  let plug_name = easycomplete#GetPlugNameByCommand(a:cmd)
  if empty(plug_name) | return v:false | endif
  let local_cmd = easycomplete#installer#LspServerDir() . '/' . plug_name . '/' . a:cmd
  if executable(local_cmd)
    return v:true
  endif
  return v:false
endfunction

function! easycomplete#installer#executable(...)
  return call("s:executable", a:000)
endfunction

function! easycomplete#installer#LspServerInstalled(...)
  return call("s:LspCmdInstalled", a:000)
endfunction

function! s:log(...)
  return call('easycomplete#util#log', a:000)
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction
