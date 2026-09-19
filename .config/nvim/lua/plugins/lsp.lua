-- Installed via mason.
local mason_servers = {
  "lua_ls",
  "pyright",
  "ts_ls",
  "bashls",
  "yamlls",
  "jsonls",
  "terraformls",
}

-- Use the Nix-provided binary instead (not mason-managed).
-- nil_ls: pkgs.nil, so it doesn't need cargo to build via mason.
local extra_servers = {
  "nil_ls",
}

local servers = vim.list_extend(vim.list_extend({}, mason_servers), extra_servers)

local function on_attach(_, bufnr)
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set("n", "<Leader>a", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "<Leader>k", vim.lsp.buf.hover, opts)
  vim.keymap.set("n", "<Leader>r", vim.lsp.buf.rename, opts)
  vim.keymap.set("n", "<C-n>", function() vim.diagnostic.jump({ count = 1 }) end, opts)
  vim.keymap.set("n", "<C-p>", function() vim.diagnostic.jump({ count = -1 }) end, opts)
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
      -- Enabled explicitly below instead, so non-mason servers (nil_ls) go
      -- through the same path and manually-installed mason servers stay off.
      automatic_enable = false,
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "saghen/blink.cmp" },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()

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
