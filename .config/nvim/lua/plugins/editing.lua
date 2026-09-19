return {
  {
    -- Keeps vim-surround's ys/cs/ds/S keymaps; no setup() needed in v4.
    "kylechui/nvim-surround",
    version = "^4.0.0",
    event = "VeryLazy",
    config = function()
      -- Visual <char> surrounds the selection. remap = true is required: the
      -- RHS's "S" must resolve to nvim-surround's mapping, not Vim's builtin
      -- visual S (which deletes the selection).
      local function surround(lhs, char, opts)
        local rhs = "S" .. char .. "gv"
        vim.keymap.set("x", lhs, rhs, vim.tbl_extend("force", { remap = true }, opts or {}))
      end

      local pairs_map = { ["'"] = "'", ['"'] = '"', ["`"] = "`", ["("] = ")", [")"] = "(", ["{"] = "}", ["}"] = "{" }
      for lhs, char in pairs(pairs_map) do
        surround(lhs, char)
      end
      -- Buffer-local + nowait: [ and ] prefix other visual maps (matchit's
      -- [%, Neovim's [n/[N), which would otherwise make these wait.
      vim.api.nvim_create_autocmd("BufEnter", {
        group = vim.api.nvim_create_augroup("surround-brackets", { clear = true }),
        callback = function(args)
          surround("[", "]", { buffer = args.buf, nowait = true })
          surround("]", "[", { buffer = args.buf, nowait = true })
        end,
      })
    end,
  },
  {
    -- ga{pattern} aligns on every match of {pattern}; gA previews first.
    "nvim-mini/mini.align",
    version = "*",
    keys = {
      { "ga", mode = { "n", "x" } },
      { "gA", mode = { "n", "x" } },
    },
    opts = {},
  },
  {
    "tpope/vim-fugitive",
    keys = {
      { "<C-f>b", "<Cmd>Git blame<CR>", desc = "Git blame" },
      { "<C-f>d", "<Cmd>Gdiffsplit<CR>", desc = "Git diff" },
      { "<C-f>l", "<Cmd>Git log<CR>", desc = "Git log" },
      { "<C-f>s", "<Cmd>Git<CR>", desc = "Git status" },
    },
  },
  { "Vimjas/vim-python-pep8-indent", ft = "python" },
}
