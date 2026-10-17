# wilder.nvim
### A more adventurous wildmenu

`wilder.nvim` adds new features and capabilities to `wildmenu`.
- Automatically provides suggestions as you type
  - `:` cmdline support - autocomplete commands, expressions, filenames, etc.
  - `/` search support - get search suggestions from the current buffer
- High level of customisation
  - build your own custom pipeline to suit your needs
  - customisable look and appearance

![wilder](https://gist.githubusercontent.com/gelguy/018d7fb1d5292500b2f9bc6d209a7972/raw/3be41ed723b5eb31928787ee25e5545c08a96061/border.gif)

# Getting started

## Requirements

- Vim 8.1+ or Neovim 0.3+
- To use the optional Python features, Neovim or Vim with `yarp` is needed

## Install

With [Shougo/dein.nvim](https://github.com/Shougo/dein.nvim)

```vim
call dein#add('gelguy/wilder.nvim')

" To use Python remote plugin features in Vim, can be skipped
if !has('nvim')
  call dein#add('roxma/nvim-yarp')
  call dein#add('roxma/vim-hug-neovim-rpc')
endif
```

With [junegunn/vim-plug](https://github.com/junegunn/vim-plug)

```vim
if has('nvim')
  function! UpdateRemotePlugins(...)
    " Needed to refresh runtime files
    let &rtp=&rtp
    UpdateRemotePlugins
  endfunction

  Plug 'gelguy/wilder.nvim', { 'do': function('UpdateRemotePlugins') }
else
  Plug 'gelguy/wilder.nvim'

  " To use Python remote plugin features in Vim, can be skipped
  Plug 'roxma/nvim-yarp'
  Plug 'roxma/vim-hug-neovim-rpc'
endif
```

With [wbthomason/packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'gelguy/wilder.nvim',
  config = function()
    -- config goes here
  end,
}
```

## Minimal config

Start with the following minimal configuration in your `init.vim` or `.vimrc`:

```vim
" Key bindings can be changed, see below
call wilder#setup({'modes': [':', '/', '?']})
```

Be aware that `call wilder#setup` should be after `call plug#end()` if you use vim-plug.

When in `:` cmdline mode, `wildmenu` suggestions will be automatically provided.
When searching using `/`, suggestions from the current buffer will be provided. Substring matching is used by default.

Use `<Tab>` to cycle through the list forwards, and `<S-Tab>` to move backwards.

The keybinds can be changed:
```vim
" Default keys
call wilder#setup({
      \ 'modes': [':', '/', '?'],
      \ 'next_key': '<Tab>',
      \ 'previous_key': '<S-Tab>',
      \ 'accept_key': '<Down>',
      \ 'reject_key': '<Up>',
      \ })
```

Ideally `next_key` should be set to be the same as `&wildchar`.
Otherwise there might be a conflict when `wildmenu` is active at the same time as `wilder`.

To change the behavior so `wilder` does not activate automatically, set the `enable_cmdline_enter` option in `wilder#setup()` to `0`.
```vim
call wilder#setup({
      \ 'modes': [':', '/', '?'],
      \ 'enable_cmdline_enter': 0,
      \ })
```

Pressing `<Tab>` (or whichever key `next_key` is set to) will activate `wilder`.

## Lua config (Experimental)

For Neovim 0.5+, configuration in Lua is also supported. Note that this is experimental.

```lua
local wilder = require('wilder')
wilder.setup({modes = {':', '/', '?'}})
```

For every `wilder#foo()` method, the `wilder` Lua module exposes a `wilder.foo()` method in Lua.
All function arguments are the same and only needs to be translated to the Lua equivalent.

Note: this is achieved by using a Vim Script to Lua wrapper shim which introduces some overhead.
The core logic is still written in Vim Script so a Lua configuration is in general not more performant than a Vim Script configuration.

## Customising the pipeline

![Search](https://gist.githubusercontent.com/gelguy/018d7fb1d5292500b2f9bc6d209a7972/raw/3be41ed723b5eb31928787ee25e5545c08a96061/search.png)

Use `wilder#set_option('pipeline', <pipeline>)` to customise the pipeline.
The pipeline is a list of functions (referred to as pipes) which are executed
in order, passing the result of the previous function to the next one.

For example, in Neovim or Vim with `yarp`, to use fuzzy matching instead of substring matching:

<details>
<summary>Vim Script</summary>

```vim
" For Neovim or Vim with yarp
" For wild#cmdline_pipeline():
"   'language'   : set to 'python' to use python
"   'fuzzy'      : 0 - turns off fuzzy matching
"                : 1 - turns on fuzzy matching
"                : 2 - partial fuzzy matching (match does not have to begin with the same first letter)
" For wild#python_search_pipeline():
"   'pattern'    : can be set to wilder#python_fuzzy_delimiter_pattern() for stricter fuzzy matching
"   'sorter'     : omit to get results in the order they appear in the buffer
"   'engine'     : can be set to 're2' for performance, requires pyre2 to be installed
"                : see :h wilder#python_search() for more details
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#cmdline_pipeline({
      \       'language': 'python',
      \       'fuzzy': 1,
      \     }),
      \     wilder#python_search_pipeline({
      \       'pattern': wilder#python_fuzzy_pattern(),
      \       'sorter': wilder#python_difflib_sorter(),
      \       'engine': 're',
      \     }),
      \   ),
      \ ])
```

</details>

<details>
<summary>Lua</summary>

```lua
wilder.set_option('pipeline', {
  wilder.branch(
    wilder.cmdline_pipeline({
      -- sets the language to use, 'vim' and 'python' are supported
      language = 'python',
      -- 0 turns off fuzzy matching
      -- 1 turns on fuzzy matching
      -- 2 partial fuzzy matching (match does not have to begin with the same first letter)
      fuzzy = 1,
    }),
    wilder.python_search_pipeline({
      -- can be set to wilder#python_fuzzy_delimiter_pattern() for stricter fuzzy matching
      pattern = wilder.python_fuzzy_pattern(),
      -- omit to get results in the order they appear in the buffer
      sorter = wilder.python_difflib_sorter(),
      -- can be set to 're2' for performance, requires pyre2 to be installed
      -- see :h wilder#python_search() for more details
      engine = 're',
    })
  ),
})
```

</details>

`wilder#branch()` is a higher-order pipe which is able to provide control flow given its own lists of pipelines.
Note: For Lua, `wilder.branch()` takes a variadic list of arguments and so cannot have a trailing comma.

See the docs at `:h wilder-pipeline` for a more details. 

#### File finder pipeline (Neovim or Vim with `yarp`)

![File finder](https://gist.githubusercontent.com/gelguy/018d7fb1d5292500b2f9bc6d209a7972/raw/3be41ed723b5eb31928787ee25e5545c08a96061/file_finder.png)

When getting file completions, fuzzily search and match through all files under the project directory.
Has to be placed above `wilder#cmdline_pipeline()`.

<details>
<summary>Vim Script</summary>

```vim
" 'file_command' : for ripgrep : ['rg', '--files']
"                : for fd      : ['fd', '-tf']
" 'dir_command'  : for fd      : ['fd', '-td']
" 'filters'      : use ['cpsm_filter'] for performance, requires cpsm vim plugin
"                  found at https://github.com/nixprime/cpsm
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#python_file_finder_pipeline({
      \       'file_command': ['find', '.', '-type', 'f', '-printf', '%P\n'],
      \       'dir_command': ['find', '.', '-type', 'd', '-printf', '%P\n'],
      \       'filters': ['fuzzy_filter', 'difflib_sorter'],
      \     }),
      \     wilder#cmdline_pipeline(),
      \     wilder#python_search_pipeline(),
      \   ),
      \ ])
```

</details>

<details>
<summary>Lua</summary>

```lua
wilder.set_option('pipeline', {
  wilder.branch(
    wilder.python_file_finder_pipeline({
      -- to use ripgrep : {'rg', '--files'}
      -- to use fd      : {'fd', '-tf'}
      file_command = {'find', '.', '-type', 'f', '-printf', '%P\n'}, 
      -- to use fd      : {'fd', '-td'}
      dir_command = {'find', '.', '-type', 'd', '-printf', '%P\n'},
      -- use {'cpsm_filter'} for performance, requires cpsm vim plugin
      -- found at https://github.com/nixprime/cpsm
      filters = {'fuzzy_filter', 'difflib_sorter'},
    }),
    wilder.cmdline_pipeline(),
    wilder.python_search_pipeline()
  ),
})
```

</details>

To optimise for performance, the `file_command`, `dir_command` and `filters` options can be customised.
See `:h wilder#python_file_finder_pipeline()` for more details.

## Customising the renderer

Use `wilder#set_option('renderer', <renderer>)` to change how `wilder` draws the results.
By default, `wilder` tries its best to look like the default wildmenu.

### Wildmenu renderer

![Wildmenu](https://gist.githubusercontent.com/gelguy/018d7fb1d5292500b2f9bc6d209a7972/raw/3be41ed723b5eb31928787ee25e5545c08a96061/wildmenu.png)

`wilder#wildmenu_renderer()` draws the candidates above the cmdline.
For Neovim 0.4+, a floating window is used. For Vim 8.1+ with popup support, a popup window is used.
Otherwise the statusline is used. Note: When using the statusline, the wildmenu will only show on the statusline of the current window.

<details>
<summary>Vim Script</summary>

```vim
" 'highlighter' : applies highlighting to the candidates
call wilder#set_option('renderer', wilder#wildmenu_renderer({
      \ 'highlighter': wilder#basic_highlighter(),
      \ }))
```

</details>

<details>
<summary>Lua</summary>

```lua
wilder.set_option('renderer', wilder.wildmenu_renderer({
  -- highlighter applies highlighting to the candidates
  highlighter = wilder.basic_highlighter(),
}))
```

</details>

##### Minimal theme

An alternative theme which shows a spinner and the current number of items:

![Wildmenu Minimal](https://gist.githubusercontent.com/gelguy/018d7fb1d5292500b2f9bc6d209a7972/raw/3be41ed723b5eb31928787ee25e5545c08a96061/wildmenu_minimal.png)

<details>
<summary>Vim Script</summary>

```vim
call wilder#set_option('renderer', wilder#wildmenu_renderer({
      \ 'highlighter': wilder#basic_highlighter(),
      \ 'separator': ' · ',
      \ 'left': [' ', wilder#wildmenu_spinner(), ' '],
      \ 'right': [' ', wilder#wildmenu_index()],
      \ }))
```

</details>

<details>
<summary>Lua</summary>

```lua
wilder.set_option('renderer', wilder.wildmenu_renderer({
  highlighter = wilder.basic_highlighter(),
  separator = ' · ',
  left = {' ', wilder.wildmenu_spinner(), ' '},
  right = {' ', wilder.wildmenu_index()},
}))
```

</details>

##### Airline/Lightline theme

For Airline and Lightline users, `wilder#wildmenu_airline_theme()` and `wilder#wildmenu_lightline_theme()` can be used.

![Wildmenu Airline](https://gist.githubusercontent.com/gelguy/018d7fb1d5292500b2f9bc6d209a7972/raw/3be41ed723b5eb31928787ee25e5545c08a96061/wildmenu_airline.png)

<details>
<summary>Vim Script</summary>

```vim
" Use wilder#wildmenu_lightline_theme() if using Lightline
" 'highlights' : can be overriden, see :h wilder#wildmenu_renderer()
call wilder#set_option('renderer', wilder#wildmenu_renderer(
      \ wilder#wildmenu_airline_theme({
      \   'highlights': {},
      \   'highlighter': wilder#basic_highlighter(),
      \   'separator': ' · ',
      \ })))
```

</details>

<details>
<summary>Lua</summary>

```lua
wilder.set_option('renderer', wilder.wildmenu_renderer(
  -- use wilder.wildmenu_lightline_theme() if using Lightline
  wilder.wildmenu_airline_theme({
    -- highlights can be overriden, see :h wilder#wildmenu_renderer()
    highlights = {default = 'StatusLine'},
    highlighter = wilder.basic_highlighter(),
    separator = ' · ',
  })
))
```

</details>

### Popupmenu renderer

![Popupmenu](https://gist.githubusercontent.com/gelguy/018d7fb1d5292500b2f9bc6d209a7972/raw/3be41ed723b5eb31928787ee25e5545c08a96061/popupmenu.png)

For Neovim 0.4+ or Vim 8.1+ with popup support,
`wilder#popupmenu_renderer()` can be used to draw the results on a popupmenu, similar to `wildoptions+=pum`.
The implementation for Vim is still experimental.

<details>
<summary>Vim Script</summary>

```vim
" 'highlighter' : applies highlighting to the candidates
call wilder#set_option('renderer', wilder#popupmenu_renderer({
      \ 'highlighter': wilder#basic_highlighter(),
      \ }))
```

</details>

<details>
<summary>Lua</summary>

```lua
wilder.set_option('renderer', wilder.popupmenu_renderer({
  -- highlighter applies highlighting to the candidates
  highlighter = wilder.basic_highlighter(),
}))
```

</details>

Use `wilder#renderer_mux()` to choose which renderer to use for different cmdline modes.
This is helpful since the popupmenu might overlap the current window when searching with `/`.

<details>
<summary>Vim Script</summary>

```vim
call wilder#set_option('renderer', wilder#renderer_mux({
      \ ':': wilder#popupmenu_renderer(),
      \ '/': wilder#wildmenu_renderer(),
      \ }))
```

</details>

<details>
<summary>Lua</summary>

```lua
wilder.set_option('renderer', wilder.renderer_mux({
  [':'] = wilder.popupmenu_renderer({
    highlighter = wilder.basic_highlighter(),
  }),
  ['/'] = wilder.wildmenu_renderer({
    highlighter = wilder.basic_highlighter(),
  }),
}))
```

</details>

![Popupmenu pumblend](https://gist.githubusercontent.com/gelguy/018d7fb1d5292500b2f9bc6d209a7972/raw/22e0a7608df7dfd44bd5f607c41af34d0ac9225d/pumblend.png)

For Neovim, the `pumblend` option can be set to change the transparency of the popupmenu. By default, the value of the `&pumblend` option is used.
To disable transparency, set the value to `0`.

<details>
<summary>Vim Script</summary>

```vim
call wilder#set_option('renderer', wilder#popupmenu_renderer({
      \ 'pumblend': 20,
      \ }))
```

</details>

<details>
<summary>Lua</summary>

```lua
wilder.set_option('renderer', wilder.popupmenu_renderer({
  pumblend = 20,
}))
```

</details>

##### Popupmenu borders

![Popupmenu Border](https://gist.githubusercontent.com/gelguy/018d7fb1d5292500b2f9bc6d209a7972/raw/3be41ed723b5eb31928787ee25e5545c08a96061/popupmenu_border.png)

Use `wilder#popupmenu_border_theme()` to add a border around the popup menu.

<details>
<summary>Vim Script</summary>

```vim
" 'border'            : 'single', 'double', 'rounded' or 'solid'
"                     : can also be a list of 8 characters,
"                     : see :h wilder#popupmenu_border_theme() for more details
" 'highlights.border' : highlight to use for the border`
call wilder#set_option('renderer', wilder#popupmenu_renderer(wilder#popupmenu_border_theme({
      \ 'highlights': {
      \   'border': 'Normal',
      \ },
      \ 'border': 'rounded',
      \ })))
```

</details>

<details>
<summary>Lua</summary>

```lua
wilder.set_option('renderer', wilder.popupmenu_renderer(
  wilder.popupmenu_border_theme({
    highlights = {
      border = 'Normal', -- highlight to use for the border
    },
    -- 'single', 'double', 'rounded' or 'solid'
    -- can also be a list of 8 characters, see :h wilder#popupmenu_border_theme() for more details
    border = 'rounded',
  })
))
```

</details>

##### Fill up entire width like Emacs helm

![Helm](https://gist.githubusercontent.com/gelguy/018d7fb1d5292500b2f9bc6d209a7972/raw/3be41ed723b5eb31928787ee25e5545c08a96061/helm.png)

Set the `min_width` option to `100%`.

<details>
<summary>Vim Script</summary>

```vim
" wilder#popupmenu_border_theme() is optional.
" 'min_height' : sets the minimum height of the popupmenu
"              : can also be a number
" 'max_height' : set to the same as 'min_height' to set the popupmenu to a fixed height
" 'reverse'    : if 1, shows the candidates from bottom to top
call wilder#set_option('renderer', wilder#popupmenu_renderer(wilder#popupmenu_border_theme({
      \ 'highlighter': wilder#basic_highlighter(),
      \ 'min_width': '100%',
      \ 'min_height': '50%',
      \ 'reverse': 0,
      \ })))
```

</details>

<details>
<summary>Lua</summary>

```lua
wilder.set_option('renderer', wilder.popupmenu_renderer(
  wilder.popupmenu_border_theme({
    highlighter = wilder.basic_highlighter(),
    min_width = '100%', -- minimum height of the popupmenu, can also be a number
    min_height = '50%', -- to set a fixed height, set max_height to the same value
    reverse = 0,        -- if 1, shows the candidates from bottom to top
  })
))
```

</details>

##### Devicons for popupmenu

![Popupmenu Devicons](https://gist.githubusercontent.com/gelguy/018d7fb1d5292500b2f9bc6d209a7972/raw/3be41ed723b5eb31928787ee25e5545c08a96061/popupmenu_devicons.png)

Supports `ryanoasis/vim-devicons`, `kyazdani42/nvim-web-devicons` and `lambdalisue/nerdfont.vim` by default.
To use other plugins, the `get_icon` option can be changed.
See `:h wilder#popupmenu_devicons` for more details.

<details>
<summary>Vim Script</summary>

```vim
call wilder#set_option('renderer', wilder#popupmenu_renderer({
      \ 'highlighter': wilder#basic_highlighter(),
      \ 'left': [
      \   ' ', wilder#popupmenu_devicons(),
      \ ],
      \ 'right': [
      \   ' ', wilder#popupmenu_scrollbar(),
      \ ],
      \ }))
```

</details>

<details>
<summary>Lua</summary>

```lua
wilder.set_option('renderer', wilder.popupmenu_renderer({
  highlighter = wilder.basic_highlighter(),
  left = {' ', wilder.popupmenu_devicons()},
  right = {' ', wilder.popupmenu_scrollbar()},
}))
```

</details>

### Command Palette (Experimental)

![Palette](https://gist.githubusercontent.com/gelguy/018d7fb1d5292500b2f9bc6d209a7972/raw/6ffb5b116ce298e1d6c9411fe08457e0cffbe4aa/palette4.gif)

`wilder#popupmenu_palette_theme()` can be used to draw the popupmenu in the middle of the screen, similar to a command palette.

<details>
<summary>Vim Script</summary>

```vim
" 'border'            : 'single', 'double', 'rounded' or 'solid'
"                     : can also be a list of 8 characters,
"                     : see :h wilder#popupmenu_palette_theme() for more details
" 'max_height'        : max height of the palette
" 'min_height'        : set to the same as 'max_height' for a fixed height window
" 'prompt_position'   : 'top' or 'bottom' to set the location of the prompt
" 'reverse'           : set to 1 to reverse the order of the list
"                     : use in combination with 'prompt_position'
call wilder#set_option('renderer', wilder#popupmenu_renderer(wilder#popupmenu_palette_theme({
      \ 'border': 'rounded',
      \ 'max_height': '75%',
      \ 'min_height': 0,
      \ 'prompt_position': 'top',
      \ 'reverse': 0,
      \ })))
```

</details>

<details>
<summary>Lua</summary>

```lua
wilder.set_option('renderer', wilder.popupmenu_renderer(
  wilder.popupmenu_palette_theme({
    -- 'single', 'double', 'rounded' or 'solid'
    -- can also be a list of 8 characters, see :h wilder#popupmenu_palette_theme() for more details
    border = 'rounded',
    max_height = '75%',      -- max height of the palette
    min_height = 0,          -- set to the same as 'max_height' for a fixed height window
    prompt_position = 'top', -- 'top' or 'bottom' to set the location of the prompt
    reverse = 0,             -- set to 1 to reverse the order of the list, use in combination with 'prompt_position'
  })
))
```

</details>

### Better highlighting

![Popupmenu Fuzzy](https://gist.githubusercontent.com/gelguy/018d7fb1d5292500b2f9bc6d209a7972/raw/3be41ed723b5eb31928787ee25e5545c08a96061/popupmenu_fuzzy.png)

The `highlighter` option for both `wilder#wildmenu_renderer()` and `wilder#popupmenu_renderer()`
can be changed for better fuzzy highlighting.

The `highlights.accent` option sets the highlight group to use for the matched characters.
`wilder#make_hl()` is a helper method which creates a new highlight group based on the attributes of an existing one.

Basic configuration for both Vim and Neovim:

<details>
<summary>Vim Script</summary>

```vim
" Create the WilderAccent highlight by overriding the guifg attribute of Pmenu
" and return the name of the highlight
let l:hl = wilder#make_hl('WilderAccent', 'Pmenu', [{}, {}, {'foreground': '#f4468f'}]),

call wilder#set_option('renderer', wilder#popupmenu_renderer({
      \ 'highlighter': wilder#basic_highlighter(),
      \ 'highlights': {
      \   'accent': l:hl,
      \ },
      \ }))

" Can also be passed to the 'highlights' option
call wilder#set_option('renderer', wilder#popupmenu_renderer({
      \ 'highlighter': wilder#basic_highlighter(),
      \ 'highlights': {
      \   'accent': wilder#make_hl('WilderAccent', 'Pmenu', [{}, {}, {'foreground': '#f4468f'}]),
      \ },
      \ }))
```

</details>

For Neovim or Vim with `yarp`:

<details>
<summary>Vim Script</summary>

```vim
" For python_cpsm_highlighter : requires cpsm vim plugin found at
"                               https://github.com/nixprime/cpsm
call wilder#set_option('renderer', wilder#popupmenu_renderer({
      \ 'highlighter': [
      \   wilder#pcre2_highlighter(),
      \   wilder#python_cpsm_highlighter(),
      \ ],
      \ 'highlights': {
      \   'accent': wilder#make_hl('WilderAccent', 'Pmenu', [{}, {}, {'foreground': '#f4468f'}]),
      \ },
      \ }))
```

</details>

For Neovim:

<details>
<summary>Vim Script</summary>

```vim
" For lua_pcre2_highlighter : requires `luarocks install pcre2`
" For lua_fzy_highlighter   : requires fzy-lua-native vim plugin found
"                             at https://github.com/romgrk/fzy-lua-native
call wilder#set_option('renderer', wilder#popupmenu_renderer({
      \ 'highlighter': [
      \   wilder#lua_pcre2_highlighter(),
      \   wilder#lua_fzy_highlighter(),
      \ ],
      \ 'highlights': {
      \   'accent': wilder#make_hl('WilderAccent', 'Pmenu', [{}, {}, {'foreground': '#f4468f'}]),
      \ },
      \ }))
```

</details>

<details>
<summary>Lua</summary>

```lua
wilder.set_option('renderer', wilder.popupmenu_renderer({
  highlighter = {
    wilder.lua_pcre2_highlighter(), -- requires `luarocks install pcre2`
    wilder.lua_fzy_highlighter(),   -- requires fzy-lua-native vim plugin found
                                    -- at https://github.com/romgrk/fzy-lua-native
  },
  highlights = {
    accent = wilder.make_hl('WilderAccent', 'Pmenu', {{a = 1}, {a = 1}, {foreground = '#f4468f'}}),
  },
}))
```

</details>

#### Gradient highlighting

![Gradient](https://gist.githubusercontent.com/gelguy/018d7fb1d5292500b2f9bc6d209a7972/raw/3be41ed723b5eb31928787ee25e5545c08a96061/gradient_with_border.png)

`wilder#highlighter_with_gradient()` wraps other highlighters and applies a gradient highlight.

<details>
<summary>Vim Script</summary>

```vim
let s:scale = ['#f4468f', '#fd4a85', '#ff507a', '#ff566f', '#ff5e63',
      \ '#ff6658', '#ff704e', '#ff7a45', '#ff843d', '#ff9036',
      \ '#f89b31', '#efa72f', '#e6b32e', '#dcbe30', '#d2c934',
      \ '#c8d43a', '#bfde43', '#b6e84e', '#aff05b']
let s:gradient = map(s:scale, {i, fg -> wilder#make_hl(
      \ 'WilderGradient' . i, 'Pmenu', [{}, {}, {'foreground': fg}]
      \ )})

" Pass the highlighters as the argument to wilder#highlighter_with_gradient()
" 'highlights.gradient'          : must be set.
" 'highlights.selected_gradient' : can be set to apply gradient highlighting for the selected candidate.
call wilder#set_option('renderer', wilder#popupmenu_renderer({
      \ 'highlights': {
      \   'gradient': s:gradient,
      \ },
      \ 'highlighter': wilder#highlighter_with_gradient([
      \    ... highlighters ...
      \ ]),
      \ }))
```

</details>

<details>
<summary>Lua</summary>

```lua
local gradient = {
  '#f4468f', '#fd4a85', '#ff507a', '#ff566f', '#ff5e63',
  '#ff6658', '#ff704e', '#ff7a45', '#ff843d', '#ff9036',
  '#f89b31', '#efa72f', '#e6b32e', '#dcbe30', '#d2c934',
  '#c8d43a', '#bfde43', '#b6e84e', '#aff05b'
}

for i, fg in ipairs(gradient) do
  gradient[i] = wilder.make_hl('WilderGradient' .. i, 'Pmenu', {{a = 1}, {a = 1}, {foreground = fg}})
end

wilder.set_option('renderer', wilder.popupmenu_renderer({
  highlights = {
    gradient = gradient, -- must be set
    -- selected_gradient key can be set to apply gradient highlighting for the selected candidate.
  },
  highlighter = wilder.highlighter_with_gradient({
    wilder.basic_highlighter(), -- or wilder.lua_fzy_highlighter(),
  }),
}))
```

</details>

A nice set of color scales can be found at [d3-scale-chromatic](https://observablehq.com/@d3/color-schemes?collection=@d3/d3-scale-chromatic).
Use the dropdown to select `discrete(<x>)` for a smaller list of colors.
Click on a scale to copy it as a string.

Note: Gradient highlighting slows down performance by a lot.

# Example configs

### Basic config (for both Vim and Neovim)

<details>
<summary>Vim Script</summary>

```vim
call wilder#setup({'modes': [':', '/', '?']})

call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#cmdline_pipeline(),
      \     wilder#search_pipeline(),
      \   ),
      \ ])

call wilder#set_option('renderer', wilder#wildmenu_renderer({
      \ 'highlighter': wilder#basic_highlighter(),
      \ }))
```

</details>

<details>
<summary>Lua</summary>

```lua
local wilder = require('wilder')
wilder.setup({modes = {':', '/', '?'}})

wilder.set_option('pipeline', {
  wilder.branch(
    wilder.cmdline_pipeline(),
    wilder.search_pipeline()
  ),
})

wilder.set_option('renderer', wilder.wildmenu_renderer({
  highlighter = wilder.basic_highlighter(),
}))
```

</details>

### Fuzzy config (for Neovim or Vim with `yarp`)

<details>
<summary>Vim Script</summary>

```vim
call wilder#setup({'modes': [':', '/', '?']})

call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#cmdline_pipeline({
      \       'fuzzy': 1,
      \       'set_pcre2_pattern': 1,
      \     }),
      \     wilder#python_search_pipeline({
      \       'pattern': 'fuzzy',
      \     }),
      \   ),
      \ ])

let s:highlighters = [
        \ wilder#pcre2_highlighter(),
        \ wilder#basic_highlighter(),
        \ ]

call wilder#set_option('renderer', wilder#renderer_mux({
      \ ':': wilder#popupmenu_renderer({
      \   'highlighter': s:highlighters,
      \ }),
      \ '/': wilder#wildmenu_renderer({
      \   'highlighter': s:highlighters,
      \ }),
      \ }))
```

</details>

<details>
<summary>Lua</summary>

```lua
local wilder = require('wilder')
wilder.setup({modes = {':', '/', '?'}})

wilder.set_option('pipeline', {
  wilder.branch(
    wilder.cmdline_pipeline({
      fuzzy = 1,
      set_pcre2_pattern = 1,
    }),
    wilder.python_search_pipeline({
      pattern = 'fuzzy',
    })
  ),
})

local highlighters = {
  wilder.pcre2_highlighter(),
  wilder.basic_highlighter(),
}

wilder.set_option('renderer', wilder.renderer_mux({
  [':'] = wilder.popupmenu_renderer({
    highlighter = highlighters,
  }),
  ['/'] = wilder.wildmenu_renderer({
    highlighter = highlighters,
  }),
}))
```

</details>

### Neovim Lua only config

- Requires `fzy-lua-native` from [romgrk/fzy-lua-native](https://github.com/romgrk/fzy-lua-native)

<details>
<summary>Lua</summary>

```lua
local wilder = require('wilder')
wilder.setup({modes = {':', '/', '?'}})
-- Disable Python remote plugin
wilder.set_option('use_python_remote_plugin', 0)

wilder.set_option('pipeline', {
  wilder.branch(
    wilder.cmdline_pipeline({
      fuzzy = 1,
      fuzzy_filter = wilder.lua_fzy_filter(),
    }),
    wilder.vim_search_pipeline()
  )
})

wilder.set_option('renderer', wilder.renderer_mux({
  [':'] = wilder.popupmenu_renderer({
    highlighter = wilder.lua_fzy_highlighter(),
    left = {
      ' ',
      wilder.popupmenu_devicons()
    },
    right = {
      ' ',
      wilder.popupmenu_scrollbar()
    },
  }),
  ['/'] = wilder.wildmenu_renderer({
    highlighter = wilder.lua_fzy_highlighter(),
  }),
}))
```

</details>

### Advanced config (for Neovim only or Vim with `yarp`)

This is a good approximatiton of the configuration used in the GIF from the beginning of the README. The colorscheme used if `tokyonight`.

- Requires `fd` from [sharkdp/fd](https://github.com/sharkdp/fd)  (see `:h wilder#python_file_finder_pipeline()` on using other commands)
- Requires `cpsm` from [nixprime/cpsm](https://github.com/nixprime/cpsm)
- Requires `fzy-lua-native` from [romgrk/fzy-lua-native](https://github.com/romgrk/fzy-lua-native)
- Requires `nvim-web-devicons` from [kyazdani42/nvim-web-devicons](https://github.com/kyazdani42/nvim-web-devicons) or
  `vim-devicons` from [ryanoasis/vim-devicons](https://github.com/ryanoasis/vim-devicons) or
  `nerdfont.vim` from [lambdalisue/nerdfont.vim](https://github.com/lambdalisue/nerdfont.vim)

<details>
<summary>Vim Script</summary>

```vim
call wilder#setup({'modes': [':', '/', '?']})

call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#python_file_finder_pipeline({
      \       'file_command': {_, arg -> stridx(arg, '.') != -1 ? ['fd', '-tf', '-H'] : ['fd', '-tf']},
      \       'dir_command': ['fd', '-td'],
      \       'filters': ['cpsm_filter'],
      \     }),
      \     wilder#substitute_pipeline({
      \       'pipeline': wilder#python_search_pipeline({
      \         'skip_cmdtype_check': 1,
      \         'pattern': wilder#python_fuzzy_pattern({
      \           'start_at_boundary': 0,
      \         }),
      \       }),
      \     }),
      \     wilder#cmdline_pipeline({
      \       'fuzzy': 2,
      \       'fuzzy_filter': has('nvim') ? wilder#lua_fzy_filter() : wilder#vim_fuzzy_filter(),
      \     }),
      \     [
      \       wilder#check({_, x -> empty(x)}),
      \       wilder#history(),
      \     ],
      \     wilder#python_search_pipeline({
      \       'pattern': wilder#python_fuzzy_pattern({
      \         'start_at_boundary': 0,
      \       }),
      \     }),
      \   ),
      \ ])

let s:highlighters = [
      \ wilder#pcre2_highlighter(),
      \ has('nvim') ? wilder#lua_fzy_highlighter() : wilder#cpsm_highlighter(),
      \ ]

let s:popupmenu_renderer = wilder#popupmenu_renderer(wilder#popupmenu_border_theme({
      \ 'border': 'rounded',
      \ 'empty_message': wilder#popupmenu_empty_message_with_spinner(),
      \ 'highlighter': s:highlighters,
      \ 'left': [
      \   ' ',
      \   wilder#popupmenu_devicons(),
      \   wilder#popupmenu_buffer_flags({
      \     'flags': ' a + ',
      \     'icons': {'+': '', 'a': '', 'h': ''},
      \   }),
      \ ],
      \ 'right': [
      \   ' ',
      \   wilder#popupmenu_scrollbar(),
      \ ],
      \ }))

let s:wildmenu_renderer = wilder#wildmenu_renderer({
      \ 'highlighter': s:highlighters,
      \ 'separator': ' · ',
      \ 'left': [' ', wilder#wildmenu_spinner(), ' '],
      \ 'right': [' ', wilder#wildmenu_index()],
      \ })

call wilder#set_option('renderer', wilder#renderer_mux({
      \ ':': s:popupmenu_renderer,
      \ '/': s:wildmenu_renderer,
      \ 'substitute': s:wildmenu_renderer,
      \ }))
```

</details>

<details>
<summary>Lua</summary>

```lua
local wilder = require('wilder')
wilder.setup({modes = {':', '/', '?'}})

wilder.set_option('pipeline', {
  wilder.branch(
    wilder.python_file_finder_pipeline({
      file_command = function(ctx, arg)
        if string.find(arg, '.') ~= nil then
          return {'fdfind', '-tf', '-H'}
        else
          return {'fdfind', '-tf'}
        end
      end,
      dir_command = {'fd', '-td'},
      filters = {'cpsm_filter'},
    }),
    wilder.substitute_pipeline({
      pipeline = wilder.python_search_pipeline({
        skip_cmdtype_check = 1,
        pattern = wilder.python_fuzzy_pattern({
          start_at_boundary = 0,
        }),
      }),
    }),
    wilder.cmdline_pipeline({
      fuzzy = 2,
      fuzzy_filter = wilder.lua_fzy_filter(),
    }),
    {
      wilder.check(function(ctx, x) return x == '' end),
      wilder.history(),
    },
    wilder.python_search_pipeline({
      pattern = wilder.python_fuzzy_pattern({
        start_at_boundary = 0,
      }),
    })
  ),
})

local highlighters = {
  wilder.pcre2_highlighter(),
  wilder.lua_fzy_highlighter(),
}

local popupmenu_renderer = wilder.popupmenu_renderer(
  wilder.popupmenu_border_theme({
    border = 'rounded',
    empty_message = wilder.popupmenu_empty_message_with_spinner(),
    highlighter = highlighters,
    left = {
      ' ',
      wilder.popupmenu_devicons(),
      wilder.popupmenu_buffer_flags({
        flags = ' a + ',
        icons = {['+'] = '', a = '', h = ''},
      }),
    },
    right = {
      ' ',
      wilder.popupmenu_scrollbar(),
    },
  })
)

local wildmenu_renderer = wilder.wildmenu_renderer({
  highlighter = highlighters,
  separator = ' · ',
  left = {' ', wilder.wildmenu_spinner(), ' '},
  right = {' ', wilder.wildmenu_index()},
})

wilder.set_option('renderer', wilder.renderer_mux({
  [':'] = popupmenu_renderer,
  ['/'] = wildmenu_renderer,
  substitute = wildmenu_renderer,
}))
```

</details>

# Tips

### Reducing input latency

Input latency when typing in the cmdline is due to `wilder` rendering synchronously.
Rendering time increases for each `wilder#wildmenu_renderer()` item, `wilder#popupmenu_renderer()` column,
or by having a slow `highlighter`.

#### Use minimal configuration

The fastest configuration for `wilder` is to use the non-fuzzy pipelines and the default renderers.
For Vim, the Python cmdline pipeline might be slow due to the overhead of the remote plugin.

For searching, the Python pipeline is faster as it is non-blocking and Python's regex is faster than Vim's.

```vim
" Neovim or Vim with yarp
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#cmdline_pipeline({'language': has('nvim') ? 'python' : 'vim'}),
      \     wilder#python_search_pipeline(),
      \   ),
      \ ])

" The wildmenu renderer is faster than the popupmenu renderer.
" By default no highlighting is applied.

" call wilder#set_option('renderer', wilder#popupmenu_renderer())
call wilder#set_option('renderer', wilder#wildmenu_renderer())
```

If this configuration is still not fast enough, the available options are to
implement a faster renderer e.g. using Lua or to improve the current rendering
code.

If highlighting is important, use the Lua highlighters for best performance.
For Vim, avoid using the python highlighers (e.g.
`wilder#python_cpsm_highlighter()`) due to the overhead introduced by the
remote plugin.

Avoid `wilder#wildmenu_spinner()` and `wilder#popupmenu_spinner()` as they cause frequent re-renders.

#### Use debounce

Use `wilder#debounce()` or the `debounce` option in pipelines to avoid rendering too often.
The `debounce` option is currently supported by `wilder#search_pipeline()`,
`wilder#cmdline_pipeline()` and `wilder#python_file_finder_pipeline()`.
The debounce interval is in milliseconds.

There is a tradeoff in increased latency for the final result due to the debounce versus the
increased input latency per character typed due to the rendering of intermediate results.

```vim
" Debounce the whole pipeline
call wilder#set_option('pipeline', [
      \ wilder#debounce(10),
      \ wilder#branch(
      \   ...
      \ ),
      \ ])

" Or debounce individual pipelines
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#cmdline_pipeline({
      \       'debounce': 10,
      \     }),
      \     wilder#search_pipeline({
      \       'debounce': 10,
      \     }),
      \   ),
      \ ])
```

### Faster Startup time

Set up an `autocmd` to defer initialisation to the first `CmdlineEnter`:

```vim
" ++once supported in Nvim 0.4+ and Vim 8.1+
autocmd CmdlineEnter * ++once call s:wilder_init() | call wilder#main#start()

function! s:wilder_init() abort
  call wilder#setup(...)
  call wilder#set_option(..., ...)

  call wilder#set_option('pipeline', ...)
  call wilder#set_option('renderer', ...)
endfunction
```

### Vim-specific optimisations

Using the Python remote plugin is slow, which may cause latency when getting cmdline completions.

`wilder#vim_fuzzy_filter()` should be performant enough as long as the number of candidates is not too large.

```vim
call wilder#set_option('pipeline', [
      \   wilder#branch(
      \     wilder#cmdline_pipeline({
      \       'language': 'vim',
      \       'fuzzy': 1,
      \       'fuzzy_filter': wilder#vim_fuzzy_filter(),
      \     }),
      \     ...
      \   ),
      \ ])
```

Avoid using the Python highlighters e.g. `wilder#cpsm_highlighter()` or `wilder#pcre2_highlighter()`.

# Troubleshooting

### Disabling in the case of errors

Use `q:` to open the `cmdline-window` and enter the following command

```vim
call wilder#disable()
```

Alternatively, define a mapping in your `init.vim` or `.vimrc`

```vim
nnoremap <Leader>w :call wilder#toggle()<CR>
```

### Cannot scroll through `/`-search history with `<Up>` or `<Down>`

A workaround was added for https://github.com/gelguy/wilder.nvim/issues/30.
This workaround breaks the `/` history when using the `wilder#wildmenu_renderer()`.

The workaround can be disabled by setting:
```vim
call wilder#set_option('renderer', wilder#wildmenu_renderer({
      \ 'apply_incsearch_fix': 0,
      \ }))
```

### `dein.vim` lazy loading remote plugins

If you have `g:dein#lazy_rplugins` set to true, the remote plugin will not load until the plugin is sourced.

```vim
call dein#add('gelguy/wilder.nvim', {
      \ 'lazy': 1,
      \ 'on_event' : 'CmdlineEnter',
      \ })
```

# Acknowledgements

Many thanks to the following codebases for providing ideas and reference:
> [Shougo/denite.nvim](https://github.com/Shougo/denite.nvim)

> [junegunn/fzf.vim](https://github.com/junegunn/fzf.vim)

> [vim-airline/vim-airline](https://github.com/vim-airline/vim-airline)

> [itchyny/lightline.vim](https://github.com/itchyny/lightline.vim)

> [nixprime/cpsm](https://github.com/nixprime/cpsm)

> [raghur/fruzzy](https://github.com/raghur/fruzzy)

> [Yggdroot/LeaderF](https://github.com/Yggdroot/LeaderF)

> [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)

> [ryanoasis/vim-devicons](https://github.com/ryanoasis/vim-devicons)

> [Xuyuanp/scrollbar.nvim](https://github.com/Xuyuanp/scrollbar.nvim)

> [liuchengxu/vim-clap](https://github.com/liuchengxu/vim-clap)

> and many more!
