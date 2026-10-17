> [!IMPORTANT]
> **As of March 11, 2026, this repository is on [Codeberg](https://codeberg.org/lifepillar/vim-mucomplete).**

>We're coming down to the ground
>
>There's no better place to go
>
>(Peter Gabriel)

# What is it?

MUcomplete is a minimalist autocompletion plugin for Vim.

MUcomplete is an implementation of *chained (fallback) completion*, whereby
several completion methods are attempted one after another until a result is
returned.

Under the hood, MUcomplete does nothing more than typing some completion
mappings for you, either when you press `<tab>`/`<s-tab>` or automatically
while you are typing. You choose which completion methods to use and in which
order, and MUcomplete does the rest. It does no caching, no asynchronous
computation, no intelligent guessing. It just makes use of core Vim features.

MUcomplete brings Vim completion down to earth again.

[![Donate](https://img.shields.io/badge/Donate-PayPal-green.svg)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=7VXF4VMBTLKDQ)


# Getting Started

MUcomplete requires Vim 7.2 compiled with `+insert_expand` and `+menu`.
Automatic completion is available in Vim 7.4.143 or later, although Vim
8.0.0283 is recommended. MUcomplete is developed and tested on Vim 9.

Installation does not require anything special. If you need help, please read
[How to Install](https://github.com/lifepillar/vim-mucomplete/wiki/How-to-Install).

**Mandatory Vim settings:**

```vim
  set completeopt+=menuone
```

**Optional Vim settings:**

Starting with Vim 9.1.1178, Vim supports fuzzy completion by adding `fuzzy` to
`completeopt`, so if you want fuzzy matching, set:

```vim
  set completeopt+=fuzzy
```

Other recommended settings:

```vim
  set shortmess+=c   " Shut off completion messages
  set belloff+=ctrlg " Add only if Vim beeps during completion
```

No other configuration is needed. Just start pressing `<tab>` or `<s-tab>` to
complete a word. For autocompletion, see the next section.

Vim 9.1 has improved its support for both manual and automatic completion. To
make the most out of MUcomplete, make sure to get familiar with Vim's built-in
features, in particular:

```
:help ins-completion
:help 'completeopt'
:help 'complete'
:help 'autocomplete'
```


## Autocompletion

**NOTE:** *Vim 9.1.1590 has added an `'autocomplete'` option. If you set
`autocomplete` on, you need not—and must not—enable MUcomplete autocompletion,
and you may ignore this section.*

To get completion suggestions automatically as you type (with Vim 7.4.775 or
later), you must add either `noselect` or `noinsert` to `completeopt`:

```vim
  set completeopt+=noselect
```

or

```vim
  set completeopt+=noinsert
```

Automatic completion can be activated at any time with `:MUcompleteOn` and
disabled with `:MUcompleteOff`, or toggled with `:MUcompleteToggle`. To make
automatic completion available at startup, add the following to your `vimrc`:

```vim
g:mucomplete#enable_auto_at_startup = 1
```

If autocompletion looks a little overzealous to you, you may set:

```vim
let g:mucomplete#completion_delay = 1
```

Then, MUcomplete will kick in only when you pause typing. The delay can be
adjusted, of course: see `:help mucomplete-customization`.


## Completion Chains

By default, MUcomplete attempts:

1. path completion, if the text in front of the cursor looks like a path;
2. omni-completion, if enabled in the current buffer;
3. buffer keyword completion;
4. dictionary completion, if a dictionary is set for the current buffer;
5. spelling completion, if `'spell'` is on and `'spelllang'` is set;

in this order. This is called a *completion chain* and it is the core concept
of MUcomplete operation. At the first successful attempt, the pop-up menu shows
the results. When the pop-up menu is visible, you may cycle back and forth
through the completion chain and try different completion methods by pressing
`<c-h>` and `<c-j>`, respectively. In other words, `<c-h>` and `<c-j>` mean:
“cancel the current menu and try completing the text I originally typed in
a different way”. See below for an example.

Different completion chains can be defined for each filetype or at the buffer
level. They can also be scoped by syntax groups. MUcomplete is fully
customizable. See `:help mucomplete.txt` for detailed documentation.

**Note:** *MUcomplete maps `<tab>` and `<s-tab>` to act as manual completion
triggers by default. It also changes how `<c-j>` and `<c-h>` work when the
pop-up menu is visible (and only in that situation). You may override
MUcomplete's defaults, of course, or prevent MUcomplete to define any mappings
at all. Read the documentation for options and for hints about making MUcomplete
work with plugins having conflicting mappings.*


## Semantic Completion and Language Server Protocol (LSP) Support

MUcomplete offers no explicit support for “intellisense”/semantic completion or
for LSP. For that, you need to install suitable plugins. However, as long as
those other plugins expose their functionality through `omnifunc` or
`complete`'s `F` option (in Vim 9.1.1409 or later), MUcomplete should work just
fine with them.


# MUcomplete in action

With jedi-vim (Python)     |  With SQL (Vim)
:-------------------------:|:-------------------------:
![](https://raw.github.com/lifepillar/Resources/master/mucomplete/jedi.gif) | ![](https://raw.github.com/lifepillar/Resources/master/mucomplete/sql.gif)

The first example shows MUcomplete automatically offering suggestions from
[jedi-vim](https://github.com/davidhalter/jedi-vim), which provides semantic
completion for Python. Used settings:

```vim
set completeopt-=preview
set completeopt+=longest,menuone,noselect
let g:jedi#popup_on_dot = 0  " It may be 1 as well
let g:mucomplete#enable_auto_at_startup = 1
```

The second example shows how different completion methods (omni completion,
keyword completion, file completion) are automatically selected in different
contexts. Used settings:

```vim
set completeopt+=menuone,noselect
let g:mucomplete#user_mappings = { 'sqla' : "\<c-c>a" }
let g:mucomplete#chains = { 'sql' : ['file', 'sqla', 'keyn'] }
```

This example also shows how you can define custom completion methods. In this
case, a method called `'sqla'` (the name is arbitrary) is mapped to the key
sequence `<c-c>a` (see `:help sql-completion`).

With clang_complete        |  Extending completion
:-------------------------:|:-------------------------:
![](https://raw.github.com/lifepillar/Resources/master/mucomplete/clang.gif) | ![](https://raw.github.com/lifepillar/Resources/master/mucomplete/ctrlx-ctrln.gif)

The example above shows MUcomplete used with
[clang-complete](https://github.com/Rip-Rip/clang_complete). You may also see
how it is possible to switch between different completion methods (omni
completion and keyword completion in this case) when the pop-up menu is visible,
using `<c-j>` and `<c-h>` (pay attention when `lo` is completed). Relevant
settings:

```vim
set noinfercase
set completeopt-=preview
set completeopt+=menuone,noselect
" The following line assumes `brew install llvm` in macOS
let g:clang_library_path = '/usr/local/opt/llvm/lib/libclang.dylib'
let g:clang_user_options = '-std=c++14'
let g:clang_complete_auto = 1
let g:mucomplete#enable_auto_at_startup = 1
```

The last example shows how the current completion can be extended with words
following the previous expansion in other contexts. This is useful, for
instance, to complete sentences or terms made of several words (e.g., to
extend *New* to *New York* or *New Zealand*). Relevant settings:

```vim
imap <expr> <down> mucomplete#extend_fwd("\<down>")
```

In the example, `<tab>` was typed to trigger a completion, then `<down>` was
pressed repeatedly to extend the completion. To my knowledge, MUcomplete is the
only completion plugin that streamlines this Vim feature. See `:help
mucomplete-extend-compl` for more details.


# Compatibility

See `:help mucomplete-compatibility`.


# Troubleshooting

See `:help mucomplete-troubleshooting`.
