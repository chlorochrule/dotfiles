return {
  "thinca/vim-quickrun",
  keys = {
    { "<Leader>e", "<Cmd>cclose<CR><Cmd>w<CR><Cmd>QuickRun<CR>", desc = "Run current file" },
  },
  init = function()
    vim.g.quickrun_config = {
      _ = {
        outputter = "error",
        ["outputter/error/success"] = "buffer",
        ["outputter/error/error"] = "quickfix",
        ["outputter/buffer/split"] = ":rightbelow 8sp",
        ["outputter/buffer/close_on_empty"] = 1,
      },
    }
  end,
}
