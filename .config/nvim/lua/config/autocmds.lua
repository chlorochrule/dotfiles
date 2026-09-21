local group = vim.api.nvim_create_augroup("vimrc", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = group,
  pattern = { "yaml", "vim", "javascript", "cfg", "xml", "ruby" },
  callback = function()
    vim.opt_local.tabstop = 2
    vim.opt_local.softtabstop = 2
    vim.opt_local.shiftwidth = 2
  end,
})

-- Pick up files changed outside nvim (e.g. by Claude Code in another herdr
-- pane). 'autoread' alone only reloads when nvim happens to check, which
-- focus events don't reliably trigger inside a multiplexer; CursorHold fires
-- after 'updatetime' (200ms) of idle. Unmodified buffers reload silently;
-- modified ones get nvim's usual W12 conflict prompt instead of being
-- clobbered. Skipped in the command line / cmdwin, where :checktime errors.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold", "CursorHoldI" }, {
  group = group,
  callback = function()
    if vim.fn.mode() ~= "c" and vim.fn.getcmdwintype() == "" then
      vim.cmd.checktime()
    end
  end,
})

vim.api.nvim_create_autocmd("FileChangedShellPost", {
  group = group,
  callback = function(args)
    vim.notify("Reloaded (changed on disk): " .. vim.fn.fnamemodify(args.file, ":~:."), vim.log.levels.INFO)
  end,
})
