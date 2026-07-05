return {
  "nvim-treesitter/nvim-treesitter",
  branch = "master",
  build = ":TSUpdate",
  opts = {
    ensure_installed = {
      "lua",
      "vim",
      "vimdoc",
      "python",
      "javascript",
      "typescript",
      "yaml",
      "json",
      "bash",
      "markdown",
      "nix",
      "ruby",
    },
    auto_install = true,
    highlight = { enable = true },
    -- pythonはvim-python-pep8-indentに任せる(継続行などtreesitterより正確)
    indent = { enable = true, disable = { "python" } },
  },
  config = function(_, opts)
    require("nvim-treesitter.configs").setup(opts)
  end,
}
