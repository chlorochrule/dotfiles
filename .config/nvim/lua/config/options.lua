local opt = vim.opt

-- display
opt.number = true
opt.cursorline = true
opt.ruler = true
opt.wrap = false
opt.title = false
opt.colorcolumn = "119"
opt.laststatus = 2
opt.showtabline = 2
opt.termguicolors = true
opt.signcolumn = "yes"
opt.updatetime = 200

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
opt.autoindent = true
opt.smartindent = true
opt.cindent = true

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
opt.history = 1000
opt.showcmd = true

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
opt.completeopt = { "menu", "longest", "noinsert" }
opt.mouse = "a"
