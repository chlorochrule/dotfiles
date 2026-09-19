-- Uses the `main` branch — see .claude/rules/nvim.md before touching this file.

local ensure_installed = {
  "lua",
  "vim",
  "vimdoc",
  "python",
  "javascript",
  "typescript",
  "yaml",
  "json",
  "bash",
  "markdown",
  "nix",
  "ruby",
}

-- python: left to vim-python-pep8-indent instead (more accurate for
-- continuation lines than the treesitter indent query).
local indent_disabled_filetypes = { python = true }

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  lazy = false, -- `main` doesn't support lazy-loading.
  config = function()
    require("nvim-treesitter").install(ensure_installed)

    -- Enable highlighting/indent only for filetypes with an installed
    -- parser (ensure_installed + Neovim's bundled ones).
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("treesitter-start", { clear = true }),
      callback = function(args)
        local ft = vim.bo[args.buf].filetype
        local lang = vim.treesitter.language.get_lang(ft)
        if not lang or not pcall(vim.treesitter.language.add, lang) then
          return
        end
        if not pcall(vim.treesitter.start, args.buf, lang) then
          return
        end
        if not indent_disabled_filetypes[ft] and vim.treesitter.query.get(lang, "indents") then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
