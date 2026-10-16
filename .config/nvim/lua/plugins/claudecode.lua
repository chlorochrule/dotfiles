-- Claude Code IDE integration. Claude runs in its own herdr pane: start
-- `claude` in the same directory and run /ide (or `claude --ide`).
return {
  "coder/claudecode.nvim",
  event = "VeryLazy",
  opts = {
    terminal = { provider = "none" },
  },
  keys = {
    { "<Leader>cs", "<Cmd>ClaudeCodeSend<CR>", mode = "v", desc = "Send selection to Claude" },
    { "<Leader>cb", "<Cmd>ClaudeCodeAdd %<CR>", desc = "Add buffer to Claude context" },
    { "<Leader>cy", "<Cmd>ClaudeCodeDiffAccept<CR>", desc = "Accept Claude's diff" },
    { "<Leader>cn", "<Cmd>ClaudeCodeDiffDeny<CR>", desc = "Deny Claude's diff" },
  },
}
