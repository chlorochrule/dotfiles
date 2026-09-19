return {
  "saghen/blink.cmp",
  -- v2 has ongoing breaking changes; pin to v1 for stability.
  version = "1.*",
  dependencies = {
    {
      "L3MON4D3/LuaSnip",
      dependencies = { "rafamadriz/friendly-snippets" },
      config = function()
        require("luasnip.loaders.from_vscode").lazy_load()
      end,
    },
  },
  opts = {
    snippets = { preset = "luasnip" },
    sources = {
      default = { "lsp", "path", "snippets", "buffer" },
    },
    keymap = {
      preset = "none",
      ["<C-n>"] = { "select_next", "fallback" },
      ["<C-p>"] = { "select_prev", "fallback" },
      ["<C-Space>"] = { "show" },
      ["<CR>"] = { "accept", "fallback" },
      ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
    },
    completion = {
      -- Replaces the old nvim-autopairs + cmp confirm_done hook.
      accept = { auto_brackets = { enabled = true } },
    },
  },
}
