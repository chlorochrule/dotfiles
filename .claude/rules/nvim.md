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

- `autoindent` is the only carry-forward indent option enabled globally
  (Neovim's default, so `options.lua` doesn't set it explicitly).
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

## Claude Code IDE integration (`lua/plugins/claudecode.lua`)

- `coder/claudecode.nvim` implements the protocol of Anthropic's official
  VS Code/JetBrains extensions: a WebSocket MCP server on a random port,
  advertised via `~/.claude/ide/<port>.lock` (removed again on a normal
  exit). Claude Code finds it via `/ide` or `claude --ide`.
- `terminal.provider = "none"`: Claude runs in its own herdr pane, not in
  an nvim terminal. That's also why snacks.nvim isn't a dependency — the
  plugin only `pcall(require, "snacks")`s it for the snacks terminal
  provider, despite the README listing it.
- Loaded on `VeryLazy`, which only fires with a UI. In `nvim --headless`
  the server never starts unless you `doautocmd User VeryLazy` yourself
  (that's how it was verified: MCP `initialize` + `tools/list` +
  `getOpenEditors` over the WebSocket, and a wrong auth token got 400).
- `claude -p` doesn't connect to IDEs, so it can't be used to test this.

## Reloading files changed on disk (`lua/config/autocmds.lua`)

- `checktime` runs on FocusGained/BufEnter/CursorHold(I) so edits Claude
  Code makes from another herdr pane show up without `:e`. `'autoread'` is
  on by default but only acts when nvim checks, and focus events don't
  reliably arrive through the multiplexer.
- Verified headless: an external write reloads an unmodified buffer after
  CursorHold (plain `nvim --clean` keeps the stale text); with unsaved
  edits in the buffer, neither side is lost — nvim raises its W12 conflict
  prompt instead.

## JSON schemas for jsonls (`lua/plugins/lsp.lua`)

- jsonls gets schemastore's catalog from `b0o/SchemaStore.nvim`: unlike
  VS Code, nvim hands jsonls no schemas, so it validated nothing (a
  misspelled key in `.claude/settings.json` produced zero diagnostics).
  yamlls needs no equivalent — it fetches the catalog itself by default.
- The `extra` entry maps `hosts/*/claude/settings.json` to the Claude Code
  settings schema, since the catalog only matches `.claude/settings.json`.
  CI checks the same files against the same schema (`make claude-settings`).
