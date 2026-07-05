return {
  {
    "tpope/vim-surround",
    config = function()
      local pairs_map = { ["'"] = "'", ['"'] = '"', ["`"] = "`", ["("] = ")", [")"] = "(", ["{"] = "}", ["}"] = "{" }
      for lhs, char in pairs(pairs_map) do
        vim.keymap.set("v", lhs, "S" .. char .. "gv")
      end
      vim.api.nvim_create_autocmd("BufEnter", {
        callback = function(args)
          vim.keymap.set("v", "[", "S]gv", { buffer = args.buf, nowait = true })
          vim.keymap.set("v", "]", "S[gv", { buffer = args.buf, nowait = true })
        end,
      })
    end,
  },
  {
    "junegunn/vim-easy-align",
    keys = {
      { "ga", "<Plug>(EasyAlign)", mode = { "x", "n" } },
    },
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
  { "christoomey/vim-tmux-navigator" },
}
