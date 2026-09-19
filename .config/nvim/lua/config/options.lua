local opt = vim.opt

-- display
opt.number = true
opt.cursorline = true
opt.ruler = true
opt.wrap = false
opt.title = false
opt.colorcolumn = "119"
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
opt.smarttab = true
opt.shiftround = true
-- cindent/smartindent are deliberately not enabled — see .claude/rules/nvim.md.
opt.autoindent = true

-- search
opt.wrapscan = true
opt.hlsearch = true
opt.incsearch = true

-- io
opt.autoread = true
opt.hidden = true
opt.backup = false
opt.writebackup = false
opt.swapfile = false
opt.undodir = vim.fn.expand("~/.cache/nvim/undo")
opt.undofile = true

-- cmd
opt.wildmenu = true
-- History limit: Neovim's default is already 10000, no need to set it.
opt.showcmd = true
opt.inccommand = "split"
opt.confirm = true
opt.shortmess:append("c")

-- misc
opt.clipboard = "unnamedplus"
opt.showmatch = true
opt.backspace = { "indent", "eol", "start" }
opt.whichwrap:append("b,s,h,l,<,>,[,],~")
opt.matchpairs:append("<:>")
opt.wildignore:append({ "*.so", "*.swp", "*.o" })
opt.scrolloff = 5
opt.sidescrolloff = 15
opt.sidescroll = 1
opt.ambiwidth = "single"
opt.synmaxcol = 320
opt.fileformats = { "unix", "dos", "mac" }
opt.completeopt = { "menu", "menuone", "noselect" }
opt.mouse = "a"
