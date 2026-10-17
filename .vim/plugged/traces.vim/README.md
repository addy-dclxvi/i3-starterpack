# traces.vim

## Overview
This plugin highlights patterns and ranges for Ex commands in Command-line mode.
It also provides live preview for `:substitute`.

## Requirements
### Vim 8.1
or
### Neovim 0.2.3

## Feature comparison
**Note**: some of the features provided by this plugin are already present in Vim/Neovim.

|                                                              | traces.vim   | Vim               | Neovim            |
|--------------------------------------------------------------| :----------: | :---------------: | :---------------: |
| `:substitute` preview                                        | ✓            |                   | ✓                 |
| pattern preview for `:substitute`                            | ✓            | ✓<sup>[1]</sup>   | ✓                 |
| pattern preview for `:global`, `:vglobal`, `:sort`           | ✓            | ✓<sup>[1]</sup>   | ✓<sup>[2]</sup>   |
| pattern preview for `:vimgrep`                               |              | ✓<sup>[1]</sup>   | ✓<sup>[2]</sup>   |
| off-screen results window for `:substitute`                  | ✓            |                   | ✓                 |
| off-screen results window for `:global`, `:vglobal`, `:sort` | ✓            |                   |                   |
| range preview                                                | ✓            |                   |                   |

[1] added by patch [v8.1.0271](https://github.com/vim/vim/commit/b0acacd767a2b0618a7f3c08087708f4329580d0)  
[2] available in Neovim [0.5.0](https://github.com/neovim/neovim/pull/12721)

## Example
![example](img/traces_example.gif?raw=true)

## Installation
Use plugin/runtimepath manager of choice or install manually with the following command:

### Linux
`git clone --depth 1 https://github.com/markonm/traces.vim ~/.vim/pack/plugins/start/traces.vim`

### Windows
`git clone --depth 1 https://github.com/markonm/traces.vim %HOMEPATH%/vimfiles/pack/plugins/start/traces.vim`

## Inspiration
 - [vim-over](https://github.com/osyo-manga/vim-over)
 - [incsearch.vim](https://github.com/haya14busa/incsearch.vim)
 - [inccommand](https://neovim.io/doc/user/options.html#'inccommand')
 - [nvim-incnormal](https://github.com/bfredl/nvim-incnormal)
