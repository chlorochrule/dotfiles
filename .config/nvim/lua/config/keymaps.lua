local map = vim.keymap.set

-- tmux ignore keys
map("", "<C-g>", "<Nop>")
map("", "<C-t>", "<Nop>")

-- leader
vim.g.mapleader = " "
map("n", "<Space>", "<Nop>")

-- quit current buffer, or the window if it's the last listed buffer
local function quit_buffer()
  local listed = vim.fn.getbufinfo({ buflisted = 1 })
  if #listed ~= 1 then
    vim.cmd("bd")
  else
    vim.cmd("q")
  end
end

map("n", "q", quit_buffer, { silent = true })
map("n", "<ESC>", "<Cmd>nohlsearch<CR>", { silent = true })
map("n", ">", ">>")
map("n", "<", "<<")
map("n", "<C-r>", "r")
map("n", "r", "<C-r>")
map("n", "R", "<Cmd>e!<CR>", { silent = true })
map("n", ":", ";")
map("n", ";", ":")
map("n", "j", "gj")
map("n", "gj", "j")
map("n", "k", "gk")
map("n", "gk", "k")
map("n", "ZQ", "<Nop>")
map("n", "s", "*N")
map("n", "x", '"_x')
map("n", "L", "<Cmd>bnext<CR>", { silent = true })
map("n", "H", "<Cmd>bprevious<CR>", { silent = true })
map("n", "K", "5gk")
map("n", "J", "5gj")
map("n", "Y", "y$")
map("n", "z", "g;")
map("n", "Z", "g,")
map("n", "<Tab>", "%")
map("n", "<Leader>w", "<Cmd>w<CR>", { silent = true })
map("n", "<Leader>q", "<Cmd>q<CR>", { silent = true })
map("n", "<Leader>Q", "<Cmd>bd<CR>", { silent = true })
map("n", "<Leader>-", "<Cmd>split<CR>", { silent = true })
map("n", "<Leader>\\", "<Cmd>vsplit<CR>", { silent = true })
map("n", "<C-o>", "o<ESC>")
map("n", "Q", "<C-o>", { silent = true })

-- insert mode
map("i", "jj", "<ESC>")
map("i", "<C-o>", "<C-o>o")
map("i", "<C-w>", "<ESC>ciw")
map("i", "<C-r>", "<C-o><C-r>")
map("i", "<C-u>", "<C-o>u")
map("i", "<C-d>", "<C-u>")
map("i", "<C-b>", "<Left>")
map("i", "<C-n>", function()
  return vim.fn.pumvisible() == 1 and "<C-n>" or "<Down>"
end, { expr = true })
map("i", "<C-p>", function()
  return vim.fn.pumvisible() == 1 and "<C-p>" or "<Up>"
end, { expr = true })
map("i", "<C-f>", "<Right>")
map("i", "<C-Space>", "<Space>")
map("i", "<C-BS>", "<BS>")

-- command mode
map("c", "jj", "<C-c>")
map("c", "<C-d>", "<Delete>")
map("c", "<C-o>", "<BS>")
map("c", "<C-h>", "<Left>")
map("c", "<C-j>", "<Down>")
map("c", "<C-k>", "<Up>")
map("c", "<C-l>", "<Right>")

-- visual mode
map("v", ";", "<ESC>")
map("v", ">", ">gv")
map("v", "<", "<gv")
map("v", "u", "<ESC>ugv")
map("v", "s", 'y/<C-r>"<CR>N')
map("v", "<Tab>", "%")
