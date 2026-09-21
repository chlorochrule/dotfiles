-- Claude Code IDE integration: the same MCP-over-WebSocket protocol as the
-- official VS Code/JetBrains extensions, so Claude sees the open file, the
-- visual selection and LSP diagnostics, and can show diffs here. Claude runs
-- in its own herdr pane rather than inside nvim, so no terminal is managed
-- here (provider "none"): start `claude` in the same directory and run /ide
-- (or `claude --ide`). snacks.nvim is only needed for the terminal provider,
-- so it isn't pulled in. See .claude/rules/nvim.md.
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
