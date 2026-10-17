# vim-highlightedyank
Make the yanked region apparent!

## Usage

### If you are using Vim 8.0.1394 (or later version),

there is no need for configuration, as the highlight event is automatically triggered by the `TextYankPost` event.

### If you are using older Vim,

define a keymapping to `<Plug>(highlightedyank)`. Checking the existence of `TextYankPost` event would be good.

```vim
if !exists('##TextYankPost')
  nmap y <Plug>(highlightedyank)
  xmap y <Plug>(highlightedyank)
  omap y <Plug>(highlightedyank)
endif
```

### If you are using Neovim,

you don't need this plugin. Check out [here](https://neovim.io/doc/user/lua.html#_vim.hl).


## Optimizing highlight duration

If you want to optimize highlight duration, use `g:highlightedyank_highlight_duration` or `b:highlightedyank_highlight_duration`. Assign a number of time in milliseconds.

```vim
let g:highlightedyank_highlight_duration = 1000
```

A negative number makes the highlight persistent.

```vim
let g:highlightedyank_highlight_duration = -1
```

When a new text is yanked or user starts editing, the old highlighting would be deleted.

## Highlight coloring

If the highlight is not visible for some reason, you can redefine the `HighlightedyankRegion` highlight group like:

```vim
highlight HighlightedyankRegion cterm=reverse gui=reverse
```

Note that the line should be located after `:colorscheme` command execution in your vimrc.

## Suppress highlight in visual mode

The highlight may not be needed or even annoying in visual mode.

```vim
let g:highlightedyank_highlight_in_visual = 0
```

## Inspired by

 - [atom-vim-mode-plus](https://github.com/t9md/atom-vim-mode-plus)
 - [vim-operator-flashy](https://github.com/haya14busa/vim-operator-flashy)

## Demo
![vim-highlightedyank](http://i.imgur.com/HulyZ6n.gif)
