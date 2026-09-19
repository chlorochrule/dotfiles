---
paths:
  - ".config/nvim/**"
---

# .config/nvim background

Context for working on the Neovim config (Lua + lazy.nvim). Not needed to
use Neovim day to day — only when changing these files.

## nvim-treesitter (`main` branch, `lua/plugins/treesitter.lua`)

- Uses the `main` branch (Neovim 0.12+ rewrite), not `master`. Parser
  install is just `.install()`; enabling highlighting/indent is done via a
  `FileType` autocmd here, because `main` removed the old
  `highlight.enable`/`indent.enable` `setup(opts)` API that `master` has.
- `lazy = false` is required: `main` doesn't support lazy-loading (per
  upstream's README).
- Requires the external `tree-sitter` CLI on PATH: `main` shells out to it
  to build parsers, unlike `master`'s in-process build. Provided by
  `pkgs.tree-sitter` in `home/default.nix`'s `home.packages` — if parser
  builds start failing, check that's still there first.
- The `FileType` callback only sets `indentexpr` when
  `vim.treesitter.query.get(lang, "indents")` is non-nil. Languages without
  an indents query (most languages outside `ensure_installed`, including
  ones Neovim bundles a parser for, like C) fall through to Neovim's
  built-in indent handling instead — setting indentexpr unconditionally
  would silently break that fallback for those filetypes.
- Both `pcall`s in the callback guard real observed failures, not
  hypothetical ones: `vim.treesitter.start` can fail even after
  `language.add` succeeds (seen with fzf-lua's picker buffer, filetype
  `fzf`), and an uncaught error inside a `FileType` autocmd surfaces as a
  global Neovim error banner.
- `python` is deliberately excluded from treesitter indent
  (`indent_disabled_filetypes`): `vim-python-pep8-indent` handles
  continuation lines more accurately than the treesitter indent query does.

## Global indent settings (`lua/config/options.lua`)

- `autoindent` is the only carry-forward indent option enabled globally.
  `cindent`/`smartindent` are deliberately NOT enabled: turning them on
  reproduces C-style indenting (unclosed brackets, trailing `{`) for any
  filetype with no indentexpr of its own (plain text, toml, etc.), which is
  exactly what this setup avoids. Don't re-enable them without re-reading
  the treesitter section above — the two settings interact.

## herdr integration (`lua/config/keymaps.lua`)

- `<C-h/j/k/l>` pane navigation only activates when `$HERDR_SOCKET_PATH` is
  set (i.e. running inside herdr); outside herdr it falls through to plain
  `wincmd`.
- `herdr pane focus --direction` only fires when the `wincmd` didn't
  actually move the window (current window is unchanged before/after) —
  that's the signal that nvim hit a window boundary and the move should
  cross into herdr's own pane grid.
