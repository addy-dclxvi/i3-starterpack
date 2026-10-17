function! wilder#renderer#component#popupmenu_devicons#(opts) abort
  let l:padding = get(a:opts, 'padding', [0, 1])
  let l:state = {
        \ 'session_id': -1,
        \ 'cache': wilder#cache#cache(),
        \ 'created_hls': {},
        \ 'left_padding': repeat(' ', l:padding[0]),
        \ 'right_padding': repeat(' ', l:padding[1]),
        \ 'combine_selected_hl': get(a:opts, 'combine_selected_hl', 0),
        \ 'min_width': get(a:opts, 'min_width', 1),
        \ }

  if has_key(a:opts, 'get_icon')
    let l:state.get_icon = a:opts.get_icon
  endif

  if has_key(a:opts, 'get_hl')
    let l:state.get_hl = a:opts.get_hl
  endif

  return {ctx, result -> s:devicons(l:state, ctx, result)}
endfunction

function! s:devicons(state, ctx, result) abort
  if !has_key(a:result, 'data')
    return ''
  endif

  let l:expand = get(a:result.data, 'cmdline.expand', '')

  if l:expand !=# 'file' &&
        \ l:expand !=# 'file_in_path' &&
        \ l:expand !=# 'dir' &&
        \ l:expand !=# 'shellcmd' &&
        \ l:expand !=# 'buffer'
    return ''
  endif

  let l:session_id = a:ctx.session_id
  if a:state.session_id != l:session_id
    call a:state.cache.clear()
    let a:state.created_hls = {}
    let a:state.session_id = l:session_id
  endif

  let l:slash = !has('win32') && !has('win64')
        \ ? '/'
        \ : &shellslash
        \ ? '/'
        \ : '\'

  let [l:start, l:end] = a:ctx.page

  let l:rows = repeat([0], l:end - l:start + 1)

  if !has_key(a:state, 'get_icon')
    let a:state.get_icon = s:get_icon_func()
  endif

  if a:state.get_icon is v:null
    return []
  endif

  if !has_key(a:state, 'get_hl')
    let a:state.get_hl = s:get_hl_func()
  endif

  let l:i = l:start
  while l:i <= l:end
    let l:index = l:i - l:start

    let l:x = wilder#main#get_candidate(a:ctx, a:result, l:i)

    if a:state.cache.has_key(l:x)
      let l:rows[l:index] = a:state.cache.get(l:x)

      let l:i += 1
      continue
    endif

    let l:is_dir = l:x[-1:] ==# l:slash || l:x[-1:] ==# '/'

    let l:icon = a:state.get_icon(a:ctx, l:x, l:is_dir)
    let l:icon_width = strdisplaywidth(l:icon)
    if l:icon_width < a:state.min_width
      let l:icon .= repeat(' ', a:state.min_width - l:icon_width)
    endif

    if a:state.get_hl is v:null
      let l:chunks = [[a:state.left_padding . l:icon . a:state.right_padding]]
    else
      let l:hl = a:state.get_hl(a:ctx, l:x, l:is_dir, l:icon)

      if !has_key(a:state.created_hls, l:hl)
        let l:guifg = s:get_guifg(l:hl)
        let l:default_hl = s:make_temp_hl(l:hl, a:ctx.highlights['default'], l:guifg)

        if a:state.combine_selected_hl
          let l:selected_hl = s:make_temp_hl(l:hl . '_Selected', a:ctx.highlights['selected'], l:guifg)
        else
          let l:selected_hl = a:ctx.highlights['selected']
        endif

        let a:state.created_hls[l:hl] = [l:default_hl, l:selected_hl]
      endif

      let [l:default_hl, l:selected_hl] = a:state.created_hls[l:hl]
      let l:chunks = [[a:state.left_padding], [l:icon, l:default_hl, l:selected_hl], [a:state.right_padding]]
    endif

    call a:state.cache.set(l:x, l:chunks)

    let l:rows[l:index] = l:chunks

    let l:i += 1
  endwhile

  let l:height = a:ctx.height
  let l:width = empty(l:rows) ? 0 : wilder#render#chunks_displaywidth(l:rows[0])
  let l:empty_row = [[repeat(' ', l:width)]]
  let l:rows += repeat([l:empty_row], l:height - len(l:rows))

  return l:rows
endfunction

function! s:get_guifg(hl) abort
  let l:gui_colors = wilder#highlight#get_hl(a:hl)[2]

  return get(l:gui_colors, 'reverse', 0) || get(l:gui_colors, 'standout', 0) ?
        \ get(l:gui_colors, 'background', 'NONE') :
        \ get(l:gui_colors, 'foreground', 'NONE')
endfunction

function! s:make_temp_hl(name, hl, guifg) abort
  let l:name = 'WilderDevicons_' . a:name

  let l:gui_colors = wilder#highlight#get_hl(a:hl)[2]
  let l:reverse = get(l:gui_colors, 'reverse', 0) || get(l:gui_colors, 'standout', 0)

  return wilder#make_temp_hl(l:name, a:hl,
        \ [{}, {}, l:reverse ? {'background': a:guifg} : {'foreground': a:guifg}])
endfunction

function! s:get_icon_func()
  if has('nvim-0.5')
    try
      call luaeval("require'nvim-web-devicons'")
      return wilder#devicons_get_icon_from_nvim_web_devicons()
    catch
    endtry
  endif

  if exists('*WebDevIconsGetFileTypeSymbol')
    return wilder#devicons_get_icon_from_vim_devicons()
  endif

  try
    call nerdfont#find('')
    return wilder#devicons_get_icon_from_nerdfont_vim()
  catch
  endtry

  return v:null
endfunction

function! s:get_hl_func()
  if has('nvim-0.5')
    try
      call luaeval("require'nvim-web-devicons'")
      return wilder#devicons_get_hl_from_nvim_web_devicons()
    catch
    endtry
  endif

  if exists('g:loaded_glyph_palette')
    return wilder#devicons_get_hl_from_glyph_palette_vim()
  endif

  return v:null
endfunction

function! wilder#renderer#component#popupmenu_devicons#get_icon_from_vim_devicons()
  return {ctx, name, is_dir -> WebDevIconsGetFileTypeSymbol(name, is_dir)}
endfunction

function! wilder#renderer#component#popupmenu_devicons#get_icon_from_nerdfont_vim()
  return {ctx, name -> nerdfont#find(name)}
endfunction

function! wilder#renderer#component#popupmenu_devicons#get_icon_from_nvim_web_devicons(opts)
  return {ctx, name, is_dir -> s:get_icon_from_nvim_web_devicons(a:opts, name, is_dir)}
endfunction

function! s:get_icon_from_nvim_web_devicons(opts, name, is_dir)
  if a:is_dir
    return get(a:opts, 'dir_icon', '')
  endif

  let l:data = s:get_data_from_nvim_web_devicons(a:name)

  return empty(l:data) ? get(a:opts, 'default_icon', '') : l:data[0]
endfunction

function! wilder#renderer#component#popupmenu_devicons#get_hl_from_nvim_web_devicons(opts)
  if !luaeval("require'nvim-web-devicons'.has_loaded()")
    call luaeval("require'nvim-web-devicons'.setup()")
  endif

  return {ctx, name, is_dir, icon -> s:get_hl_from_nvim_web_devicons(a:opts, name, is_dir)}
endfunction

function! s:get_hl_from_nvim_web_devicons(opts, name, is_dir)
  if a:is_dir
    return get(a:opts, 'dir_hl', 'Directory')
  endif

  let l:data = s:get_data_from_nvim_web_devicons(a:name)
  let l:hl = get(l:data, 1, '')

  return hlexists(l:hl) ? l:hl : get(a:opts, 'default_hl', 'DevIconDefault')
endfunction

function! s:get_data_from_nvim_web_devicons(name)
  let l:name = fnamemodify(a:name, ':t')
  let l:ext = fnamemodify(l:name, ':e')
  return luaeval("{require'nvim-web-devicons'.get_icon(_A[1], _A[2])}", [l:name, l:ext])
endfunction

function! wilder#renderer#component#popupmenu_devicons#get_hl_from_glyph_palette_vim(opts)
  return {ctx, name, is_dir, icon -> s:get_hl_from_glyph_palette_vim(a:opts, ctx, icon)}
endfunction

let s:glyph_hls = {}
let s:glyph_hls_session_id = -1

function! s:get_hl_from_glyph_palette_vim(opts, ctx, icon)
  if a:ctx.session_id > s:glyph_hls_session_id
    let s:glyph_hls_session_id = a:ctx.session_id

    let s:glyph_hls = {}
    for l:key in keys(g:glyph_palette#palette)
      for l:icon in g:glyph_palette#palette[l:key]
        let s:glyph_hls[l:icon] = l:key
      endfor
    endfor
  endif

  if has_key(s:glyph_hls, a:icon)
    return s:glyph_hls[a:icon]
  endif

  return get(a:opts, 'default_hl', 'Normal')
endfunction
