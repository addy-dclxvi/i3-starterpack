" Author: Prabir Shrestha <mail at prabir dot me>
" Modified: Jayli <bachi at taobao dot com>
" Website: https://github.com/prabirshrestha/async.vim
" License: The MIT License {{{
"   The MIT License (MIT)
"
"   Copyright (c) 2016 Prabir Shrestha
"   Hacked by Jayli@2025
"
"   Permission is hereby granted, free of charge, to any person obtaining a copy
"   of this software and associated documentation files (the "Software"), to deal
"   in the Software without restriction, including without limitation the rights
"   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
"   copies of the Software, and to permit persons to whom the Software is
"   furnished to do so, subject to the following conditions:
"
"   The above copyright notice and this permission notice shall be included in all
"   copies or substantial portions of the Software.
"
"   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
"   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
"   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
"   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
"   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
"   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
"   SOFTWARE.
" }}}

let s:save_cpo = &cpo
set cpo&vim

let s:jobidseq = 0
let s:jobs = {} " { job, opts, type: 'vimjob|nvimjob'}
let s:job_type_nvimjob = 'nvimjob'
let s:job_type_vimjob = 'vimjob'
let s:job_error_unsupported_job_type = -2 " unsupported job type

function! s:job_supported_types() abort
  let l:supported_types = []
  if has('nvim')
    let l:supported_types += [s:job_type_nvimjob]
  endif
  if !has('nvim') && has('job') && has('channel') && has('lambda')
    let l:supported_types += [s:job_type_vimjob]
  endif
  return l:supported_types
endfunction

function! s:job_supports_type(type) abort
  return index(s:job_supported_types(), a:type) >= 0
endfunction

function! s:out_cb(jobid, opts, job, data) abort
  if has_key(a:opts, 'on_stdout')
    call a:opts.on_stdout(a:jobid, split(a:data, "\n", 1), 'stdout')
  endif
endfunction

function! s:err_cb(jobid, opts, job, data) abort
  if has_key(a:opts, 'on_stderr')
    call a:opts.on_stderr(a:jobid, split(a:data, "\n", 1), 'stderr')
  endif
endfunction

function! s:exit_cb(jobid, opts, job, status) abort
  if has_key(a:opts, 'on_exit')
    call a:opts.on_exit(a:jobid, a:status, 'exit')
  endif
  if has_key(s:jobs, a:jobid)
    call remove(s:jobs, a:jobid)
  endif
endfunction

function! s:on_stdout(jobid, data, event) abort
  " call s:console("easycomplete, stdout", a:event, a:data)
  if has_key(s:jobs, a:jobid)
    let l:jobinfo = s:jobs[a:jobid]
    if has_key(l:jobinfo.opts, 'on_stdout')
      call l:jobinfo.opts.on_stdout(a:jobid, a:data, a:event)
    endif
  endif
endfunction

function! s:on_stderr(jobid, data, event) abort
  " call s:console("stderr", a:event, a:data)
  if has_key(s:jobs, a:jobid)
    let l:jobinfo = s:jobs[a:jobid]
    if has_key(l:jobinfo.opts, 'on_stderr')
      call l:jobinfo.opts.on_stderr(a:jobid, a:data, a:event)
    endif
  endif
endfunction

function! s:on_exit(jobid, status, event) abort
  " call s:console("exit", a:status)
  if has_key(s:jobs, a:jobid)
    let l:jobinfo = s:jobs[a:jobid]
    if has_key(l:jobinfo.opts, 'on_exit')
      call l:jobinfo.opts.on_exit(a:jobid, a:status, a:event)
    endif
    if has_key(s:jobs, a:jobid)
      call remove(s:jobs, a:jobid)
    endif
  endif
endfunction

function! s:job_start(cmd, opts) abort
  let l:jobtypes = s:job_supported_types()
  let l:jobtype = ''
  if type(a:cmd) == type([])
    let cmd_str = join(a:cmd, ' ')
  else
    let cmd_str = a:cmd
  endif

  if has_key(a:opts, 'type')
    if type(a:opts.type) == type('')
      if !s:job_supports_type(a:opts.type)
        return s:job_error_unsupported_job_type
      endif
      let l:jobtype = a:opts.type
    else
      let l:jobtypes = a:opts.type
    endif
  endif

  if empty(l:jobtype)
    " find the best jobtype
    for l:jobtype2 in l:jobtypes
      if s:job_supports_type(l:jobtype2)
        let l:jobtype = l:jobtype2
      endif
    endfor
  endif

  if l:jobtype ==? ''
    return s:job_error_unsupported_job_type
  endif

  " options shared by both vim and neovim
  let l:jobopt = {}
  if has_key(a:opts, 'cwd')
    let l:jobopt.cwd = a:opts.cwd
  endif

  if l:jobtype == s:job_type_nvimjob
    call extend(l:jobopt, {
          \ 'on_stdout': function('s:on_stdout'),
          \ 'on_stderr': function('s:on_stderr'),
          \ 'on_exit': function('s:on_exit'),
          \})
    let l:job = jobstart(cmd_str, l:jobopt)
    if l:job <= 0
      return l:job
    endif
    let l:jobid = l:job " nvimjobid and internal jobid is same
    let s:jobs[l:jobid] = {
          \ 'type': s:job_type_nvimjob,
          \ 'opts': a:opts,
          \ }
    let s:jobs[l:jobid].job = l:job
  elseif l:jobtype == s:job_type_vimjob
    let s:jobidseq = s:jobidseq + 1
    let l:jobid = s:jobidseq
    call extend(l:jobopt, {
          \ 'out_cb': function('s:out_cb', [l:jobid, a:opts]),
          \ 'err_cb': function('s:err_cb', [l:jobid, a:opts]),
          \ 'exit_cb': function('s:exit_cb', [l:jobid, a:opts]),
          \ 'mode': 'raw',
          \ })
    if has('patch-8.1.889')
      let l:jobopt['noblock'] = 1
    endif

    let l:job  = job_start(cmd_str, l:jobopt)
    if job_status(l:job) !=? 'run'
      return -1
    endif
    let s:jobs[l:jobid] = {
          \ 'type': s:job_type_vimjob,
          \ 'opts': a:opts,
          \ 'job': l:job,
          \ 'channel': job_getchannel(l:job),
          \ 'buffer': ''
          \ }
  else
    return s:job_error_unsupported_job_type
  endif

  return l:jobid
endfunction

function! s:job_stop(jobid) abort
  if has_key(s:jobs, a:jobid)
    let l:jobinfo = s:jobs[a:jobid]
    if l:jobinfo.type == s:job_type_nvimjob
      " See: vital-Whisky/System.Job
      try
        call jobstop(a:jobid)
      catch /^Vim\%((\a\+)\)\=:E900/
        " NOTE:
        " Vim does not raise exception even the job has already closed so fail
        " silently for 'E900: Invalid job id' exception
      endtry
    elseif l:jobinfo.type == s:job_type_vimjob
      if type(s:jobs[a:jobid].job) == v:t_job
        call job_stop(s:jobs[a:jobid].job)
      elseif type(s:jobs[a:jobid].job) == v:t_channel
        call ch_close(s:jobs[a:jobid].job)
      endif
    endif
  endif
endfunction

function! s:job_send(jobid, data, opts) abort
  " INFO 在一个window里切换 buffer 时，job 会停止
  " Added by jayli
  let l:jobinfo = get(s:jobs,a:jobid)
  if empty(l:jobinfo) | return | endif
  let l:close_stdin = get(a:opts, 'close_stdin', 0)
  if l:jobinfo.type == s:job_type_nvimjob
    try
      call chansend(a:jobid, a:data)
    catch
      " Bugfix: Can't send data to closed stream
    endtry
    if l:close_stdin
      call chanclose(a:jobid, 'stdin')
    endif
  elseif l:jobinfo.type == s:job_type_vimjob
    " There is no easy way to know when ch_sendraw() finishes writing data
    " on a non-blocking channels -- has('patch-8.1.889') -- and because of
    " this, we cannot safely call ch_close_in().  So when we find ourselves
    " in this situation (i.e. noblock=1 and close stdin after send) we fall
    " back to using s:flush_vim_sendraw() and wait for transmit buffer to be
    " empty
    "
    " Ref: https://groups.google.com/d/topic/vim_dev/UNNulkqb60k/discussion
    try
      if has('patch-8.1.818') && (!has('patch-8.1.889') || !l:close_stdin)
        call ch_sendraw(l:jobinfo.channel, a:data)
      else
        let l:jobinfo.buffer .= a:data
        call s:flush_vim_sendraw(a:jobid, v:null)
      endif
      if l:close_stdin
        while len(l:jobinfo.buffer) != 0
          sleep 1m
        endwhile
        call ch_close_in(l:jobinfo.channel)
      endif
    catch /^Vim\%((\a\+)\)\=:E631/
      " Channel msg sending error, terminated and do nothing
    endtry
  endif
endfunction

function! s:flush_vim_sendraw(jobid, timer) abort
  " https://github.com/vim/vim/issues/2548
  " https://github.com/natebosch/vim-lsc/issues/67#issuecomment-357469091
  let l:jobinfo = s:jobs[a:jobid]
  sleep 1m
  if len(l:jobinfo.buffer) <= 4096
    call ch_sendraw(l:jobinfo.channel, l:jobinfo.buffer)
    let l:jobinfo.buffer = ''
  else
    let l:to_send = l:jobinfo.buffer[:4095]
    let l:jobinfo.buffer = l:jobinfo.buffer[4096:]
    call ch_sendraw(l:jobinfo.channel, l:to_send)
    call timer_start(1, function('s:flush_vim_sendraw', [a:jobid]))
  endif
endfunction

function! s:job_wait_single(jobid, timeout, start) abort
  if !has_key(s:jobs, a:jobid)
    return -3
  endif

  let l:jobinfo = s:jobs[a:jobid]
  if l:jobinfo.type == s:job_type_nvimjob
    let l:timeout = a:timeout - reltimefloat(reltime(a:start)) * 1000
    return jobwait([a:jobid], float2nr(l:timeout))[0]
  elseif l:jobinfo.type == s:job_type_vimjob
    let l:timeout = a:timeout / 1000.0
    try
      while l:timeout < 0 || reltimefloat(reltime(a:start)) < l:timeout
        let l:info = s:job_info(l:jobinfo.job)
        if l:info.status ==# 'dead'
          return l:info.exitval
        elseif l:info.status ==# 'fail'
          return -3
        endif
        sleep 1m
      endwhile
    catch /^Vim:Interrupt$/
      return -2
    endtry
  endif
  return -1
endfunction

function! s:job_wait(jobids, timeout) abort
  let l:start = reltime()
  let l:exitcode = 0
  let l:ret = []
  for l:jobid in a:jobids
    if l:exitcode != -2  " Not interrupted.
      let l:exitcode = s:job_wait_single(l:jobid, a:timeout, l:start)
    endif
    let l:ret += [l:exitcode]
  endfor
  return l:ret
endfunction

function! s:job_info(id)
  if has("nvim")
    let status = s:job_pid(a:id) == 0 ? "dead" : "run"
    return {"process":s:job_pid(a:id), "status": status,
          \ "exitval": status == "dead" ? 1 : 0}
  endif
  if !has("nvim")
    return job_info(a:id)
  endif
endfunction

function! s:job_pid(jobid) abort
  if !has_key(s:jobs, a:jobid)
    return 0
  endif

  let l:jobinfo = s:jobs[a:jobid]
  if l:jobinfo.type == s:job_type_nvimjob
    try
      return jobpid(a:jobid)
    catch /E900/
      return 0
    endtry
  elseif l:jobinfo.type == s:job_type_vimjob
    let l:vimjobinfo = s:job_info(a:jobid)
    if type(l:vimjobinfo) == type({}) && has_key(l:vimjobinfo, 'process')
      return l:vimjobinfo['process']
    endif
  endif
  return 0
endfunction

function! s:callback_cb(jobid, opts, ch, data) abort
  if has_key(a:opts, 'on_stdout')
    call a:opts.on_stdout(a:jobid, split(a:data, "\n", 1), 'stdout')
  endif
endfunction

function! s:close_cb(jobid, opts, ch) abort
  if has_key(a:opts, 'on_exit')
    call a:opts.on_exit(a:jobid, 'closed', 'exit')
  endif
  if has_key(s:jobs, a:jobid)
    call remove(s:jobs, a:jobid)
  endif
endfunction

" public apis {{{
function! easycomplete#job#start(cmd, opts) abort
  return s:job_start(a:cmd, a:opts)
endfunction

function! easycomplete#job#stop(jobid) abort
  call s:job_stop(a:jobid)
endfunction

function! easycomplete#job#send(jobid, data, ...) abort
  let l:opts = get(a:000, 0, {})
  call s:job_send(a:jobid, a:data, l:opts)
endfunction

function! easycomplete#job#wait(jobids, ...) abort
  let l:timeout = get(a:000, 0, -1)
  return s:job_wait(a:jobids, l:timeout)
endfunction

function! easycomplete#job#pid(jobid) abort
  return s:job_pid(a:jobid)
endfunction

function! easycomplete#job#status(jobid)
  if has_key(s:jobs, a:jobid)
    let l:jobinfo = s:jobs[a:jobid]
    if has_key(l:jobinfo, "job")
      return s:job_info(l:jobinfo.job).status
    endif
  endif
  return "dead"
endfunction

function! easycomplete#job#jobs()
  return s:jobs
endfunction

function! easycomplete#job#connect(addr, opts) abort
  let s:jobidseq = s:jobidseq + 1
  let l:jobid = s:jobidseq
  let l:retry = 0
  while l:retry < 5
    let l:ch = ch_open(a:addr, {'waittime': 1000})
    call ch_setoptions(l:ch, {
          \ 'callback': function('s:callback_cb', [l:jobid, a:opts]),
          \ 'close_cb': function('s:close_cb', [l:jobid, a:opts]),
          \ 'mode': 'raw',
          \})
    if ch_status(l:ch) ==# 'open'
      break
    endif
    sleep 100m
    let l:retry += 1
  endwhile
  let s:jobs[l:jobid] = {
        \ 'type': s:job_type_vimjob,
        \ 'opts': a:opts,
        \ 'job': l:ch,
        \ 'channel': l:ch,
        \ 'buffer': ''
        \}
  return l:jobid
endfunction

function! s:log(msg)
  call easycomplete#log(a:msg)
endfunction

function! s:console(...)
  return call('easycomplete#log#log', a:000)
endfunction
" }}}

let &cpo = s:save_cpo
unlet s:save_cpo
