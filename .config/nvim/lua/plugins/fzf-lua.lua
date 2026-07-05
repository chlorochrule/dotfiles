return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  keys = {
    { "<Leader>g", "<Cmd>FzfLua live_grep<CR>", desc = "Grep" },
    { "<Leader>G", "<Cmd>FzfLua resume<CR>", desc = "Resume last picker" },
    { "<Leader>s", "<Cmd>FzfLua grep_cword<CR>", desc = "Grep word under cursor" },
  },
  opts = {},
}
