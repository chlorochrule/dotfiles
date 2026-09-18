-- nvim-treesitterのmainブランチ(Neovim 0.12+向けの全面書き換え)を使う。
-- masterと違い、パーサーの導入は`install`関数を呼ぶだけ・ハイライト/インデントの
-- 有効化は自前のFileTypeオートコマンドで行う方式に変わった(highlight/indentの
-- setup(opts)相当は無くなった)。

local ensure_installed = {
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
}

-- pythonはvim-python-pep8-indentに任せる(継続行などtreesitterより正確)ため、
-- treesitterのインデントは有効化しない
local indent_disabled_filetypes = { python = true }

return {
  "nvim-treesitter/nvim-treesitter",
  branch = "main",
  build = ":TSUpdate",
  lazy = false, -- mainブランチは遅延ロードに対応していない(READMEのIMPORTANT注記)
  config = function()
    require("nvim-treesitter").install(ensure_installed)

    -- パーサーが導入済み(ensure_installedの言語とNeovim同梱のもの)のfiletypeを
    -- 開いたときだけ、ハイライトとインデントを有効化する。vim.treesitter.language.get_lang/addで
    -- filetype→パーサー名の対応(例: filetype "sh" → parser "bash")とパーサーの
    -- 導入済み判定を行い、未導入なら何もしない(pcallで安全に握り潰す)。
    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        local ft = vim.bo[args.buf].filetype
        local lang = vim.treesitter.language.get_lang(ft)
        if not lang or not pcall(vim.treesitter.language.add, lang) then
          return
        end
        vim.treesitter.start(args.buf, lang)
        -- Neovim同梱パーサー(c等)はensure_installed外でもここまで来るが、indentsクエリは
        -- nvim-treesitterで導入した言語にしか無い。無い言語で設定するとfiletype標準の
        -- インデント(cindent等)を無効化してしまうため、クエリがある場合だけ設定する
        if not indent_disabled_filetypes[ft] and vim.treesitter.query.get(lang, "indents") then
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end
      end,
    })
  end,
}
