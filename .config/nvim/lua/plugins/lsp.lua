-- mason経由でインストールするサーバー
local mason_servers = {
  "lua_ls",
  "pyright",
  "ts_ls",
  "bashls",
  "yamlls",
  "jsonls",
}

-- Nixで入れたバイナリをそのまま使うサーバー(mason管理外)
-- nil_ls: pkgs.nil (cargoが無い環境でもmasonでビルドせずに済む)
local extra_servers = {
  "nil_ls",
}

local servers = vim.list_extend(vim.list_extend({}, mason_servers), extra_servers)

local function on_attach(_, bufnr)
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set("n", "<Leader>a", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "<Leader>k", vim.lsp.buf.hover, opts)
  vim.keymap.set("n", "<Leader>r", vim.lsp.buf.rename, opts)
  vim.keymap.set("n", "<C-n>", vim.diagnostic.goto_next, opts)
  vim.keymap.set("n", "<C-p>", vim.diagnostic.goto_prev, opts)
end

return {
  {
    "folke/lazydev.nvim",
    ft = "lua",
    opts = {
      library = {
        { path = "${3rd}/luv/library", words = { "vim%.uv" } },
      },
    },
  },
  {
    "mason-org/mason.nvim",
    opts = {},
  },
  {
    "mason-org/mason-lspconfig.nvim",
    dependencies = { "mason-org/mason.nvim" },
    opts = {
      ensure_installed = mason_servers,
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "hrsh7th/cmp-nvim-lsp" },
    config = function()
      local capabilities = require("cmp_nvim_lsp").default_capabilities()

      for _, server in ipairs(servers) do
        vim.lsp.config(server, {
          capabilities = capabilities,
        })
        vim.lsp.enable(server)
      end

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
        callback = function(args)
          on_attach(nil, args.buf)
        end,
      })
    end,
  },
}
