-- Formatters come from home.packages (stylua, nixfmt, terraform). Filetypes
-- not listed here are left alone: no LSP formatting fallback, so opening a
-- JSON/YAML/TS file in another project never reformats it on save.
return {
  "stevearc/conform.nvim",
  event = "BufWritePre",
  cmd = "ConformInfo",
  opts = {
    formatters_by_ft = {
      lua = { "stylua" },
      nix = { "nixfmt" },
      terraform = { "terraform_fmt" },
      ["terraform-vars"] = { "terraform_fmt" },
    },
    format_on_save = { timeout_ms = 1000 },
  },
}
