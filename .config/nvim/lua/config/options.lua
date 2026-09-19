local opt = vim.opt

-- display
opt.number = true
opt.cursorline = true
opt.wrap = false
-- First column past .editorconfig's max_line_length (120).
opt.colorcolumn = "121"
-- laststatus: left untouched — lualine's globalstatus sets it to 3.
opt.showtabline = 2
opt.termguicolors = true
opt.signcolumn = "yes"
opt.updatetime = 200
opt.splitright = true
opt.splitbelow = true

-- case
opt.ignorecase = true
opt.smartcase = true
opt.infercase = true

-- tab and indent
opt.tabstop = 4
opt.softtabstop = 4
opt.shiftwidth = 4
opt.expandtab = true
opt.shiftround = true
-- cindent/smartindent are deliberately not enabled — see .claude/rules/nvim.md.

-- io
opt.writebackup = false
opt.swapfile = false
opt.undodir = vim.fn.expand("~/.cache/nvim/undo")
opt.undofile = true

-- cmd
opt.inccommand = "split"
opt.confirm = true
opt.shortmess:append("c")

-- misc
opt.clipboard = "unnamedplus"
opt.showmatch = true
opt.whichwrap:append("b,s,h,l,<,>,[,],~")
opt.matchpairs:append("<:>")
opt.wildignore:append({ "*.so", "*.swp", "*.o" })
opt.scrolloff = 5
opt.sidescrolloff = 15
opt.synmaxcol = 320
opt.fileformats = { "unix", "dos", "mac" }
opt.completeopt = { "menu", "menuone", "noselect" }
opt.mouse = "a"
