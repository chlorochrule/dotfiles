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

-- Nix-provided binaries (not mason-managed).
local extra_servers = {
  "nil_ls",
}

local servers = vim.list_extend(vim.list_extend({}, mason_servers), extra_servers)

local function on_attach(_, bufnr)
  local opts = { buffer = bufnr, silent = true }
  vim.keymap.set("n", "<Leader>a", vim.lsp.buf.definition, opts)
  vim.keymap.set("n", "<Leader>k", vim.lsp.buf.hover, opts)
  vim.keymap.set("n", "<Leader>r", vim.lsp.buf.rename, opts)
  vim.keymap.set("n", "<C-n>", function()
    vim.diagnostic.jump({ count = 1 })
  end, opts)
  vim.keymap.set("n", "<C-p>", function()
    vim.diagnostic.jump({ count = -1 })
  end, opts)
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
      -- Enabled below, together with extra_servers.
      automatic_enable = false,
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "saghen/blink.cmp", "b0o/SchemaStore.nvim" },
    config = function()
      local capabilities = require("blink.cmp").get_lsp_capabilities()

      for _, server in ipairs(servers) do
        vim.lsp.config(server, {
          capabilities = capabilities,
        })
        vim.lsp.enable(server)
      end

      -- yamlls fetches schemastore's catalog itself; jsonls needs it here.
      vim.lsp.config("jsonls", {
        settings = {
          json = {
            schemas = require("schemastore").json.schemas({
              extra = {
                {
                  name = "claude-code-settings (dotfiles hosts/)",
                  description = "Claude Code settings.json merged into ~/.claude",
                  fileMatch = { "**/hosts/*/claude/settings.json" },
                  url = "https://json.schemastore.org/claude-code-settings.json",
                },
              },
            }),
            validate = { enable = true },
          },
        },
      })

      vim.api.nvim_create_autocmd("LspAttach", {
        group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
        callback = function(args)
          on_attach(nil, args.buf)
        end,
      })
    end,
  },
}
