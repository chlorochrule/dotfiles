# dotfiles

macOS環境をNix (nix-darwin + home-manager) + Homebrew (casksのみ) + mise で
宣言的に管理するdotfilesリポジトリです。

## 設計方針

| ツール | 役割 |
|---|---|
| **Nix** (nix-darwin + home-manager) | macOSシステム設定の宣言管理、グローバルCLIツール、dotfiles配置、Homebrew自体の宣言管理 |
| **Homebrew** | GUIアプリ(casks)専用。formulaは使わない |
| **mise** | プロジェクト単位の言語ランタイムバージョン管理(node, python等) |

ランタイム(node/python等)とCLIツールを二重管理しないことが重要です。
ランタイムはmise、CLIツールはNix、で明確に分担します。

## 前提

- macOS (Apple Silicon / `aarch64-darwin`)
- zsh(ログインシェル)

## セットアップ手順(新規マシン)

### 1. Nixのインストール

upstream Nix(Determinate Nixではない)を、daemon方式(multi-user)でインストールします。

```bash
sh <(curl -L https://nixos.org/nix/install) --daemon
```

インストール後、ターミナルを開き直してください。

### 2. リポジトリを取得

```bash
mkdir -p ~/src/github.com/chlorochrule
git clone https://github.com/chlorochrule/dotfiles ~/src/github.com/chlorochrule/dotfiles
ln -s ~/src/github.com/chlorochrule/dotfiles ~/.dotfiles
```

### 3. ホスト定義を追加

現在のホスト名を確認します。

```bash
scutil --get LocalHostName
```

`hosts/<ホスト名>/default.nix` を新規作成します(既存の
`hosts/MacBookPro-minami/default.nix` を参考にしてください)。

```nix
{
  hostname = "<ホスト名>";   # scutil --get LocalHostName の出力と一致させる
  username = "<ユーザー名>";
  system = "aarch64-darwin";
}
```

`flake.nix` の `hosts` リストに、追加したパスを1行加えます。

```nix
hosts = [
  ./hosts/MacBookPro-minami
  ./hosts/<新ホストのディレクトリ名>
];
```

新規ファイルはgitに `add` してからでないとflakeから見えないので、忘れずに:

```bash
cd ~/.dotfiles
git add hosts/<新ホストのディレクトリ名> flake.nix
```

### 4. nix-darwinをブートストラップ

初回は `darwin-rebuild` コマンドがまだ存在しないため、`nix run` 経由で実行します。

```bash
sudo nix --extra-experimental-features "nix-command flakes" \
  run nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake ~/.dotfiles
```

`/etc/bashrc` や `/etc/zshrc` など、nix-darwinが管理しようとするファイルが
既に存在する場合は `Unexpected files in /etc` のようなエラーで止まります。
表示される指示に従い、対象ファイルを `<ファイル名>.before-nix-darwin` に
リネームしてから再実行してください。

### 5. 以降の運用

2回目以降は通常の `darwin-rebuild` コマンドが使えます。

```bash
sudo darwin-rebuild switch --flake ~/.dotfiles
```

設定ファイルを編集したら、`git add` してから上記コマンドを実行してください
(flakeはgit管理下のファイルしか見ません)。home-manager側の設定
(zsh、git、mise、Ghostty等)もこの1コマンドで一緒に適用されます。

## ファイル構成

```
~/.dotfiles/
├── flake.nix                    # inputs定義、ホストをdarwinConfigurationsへ自動展開
├── darwin.nix                   # 全マシン共通のnix-darwin設定
│                                 # (system.defaults, Homebrew casks, フォント等)
├── hosts/
│   └── <hostname>/default.nix   # マシン固有の値(hostname, username, system)
├── home/
│   ├── default.nix              # home-manager設定
│   │                             # (zsh, git, mise, fzf, eza, starship, ghostty等)
│   └── claude/                  # ~/.claude/ 配下へディレクトリごとシンボリックリンク
│       ├── settings.json        #   (commands/skills/agents/hooksは新規ファイルを
│       ├── CLAUDE.md            #    置くだけで即反映、rebuild不要)
│       ├── commands/
│       ├── skills/
│       ├── agents/
│       └── hooks/
├── .config/nvim/                # Neovim設定(Lua + lazy.nvim)
├── .tigrc, .tmux.conf, .editorconfig, bin/  # mkOutOfStoreSymlinkで~/に実ファイル参照
└── nix-mise.md                  # 移行時の詳細な作業ログ・注意点
```

`home/`配下と`.tigrc`等の実ファイルは、home-managerの`mkOutOfStoreSymlink`で
`~/`配下からシンボリックリンクされます。Nix storeへコピーされないため、
手編集してもrebuildなしで即座に反映されます(`home/claude/`配下のような
ディレクトリ単位のリンクは、新規ファイル追加も即反映されます)。

## よく使う運用コマンド

```bash
# 設定変更を適用
sudo darwin-rebuild switch --flake ~/.dotfiles

# inputsを最新化(flake.lockを更新)
sudo nix --extra-experimental-features "nix-command flakes" flake update

# 特定inputのみ更新
sudo nix --extra-experimental-features "nix-command flakes" flake update <input名>

# 世代確認・ロールバック
darwin-rebuild --list-generations
sudo darwin-rebuild switch --rollback

# ガベージコレクション
sudo nix-collect-garbage --delete-older-than 30d
```

## 既知の注意点

- `darwin-rebuild switch` は `sudo` が必須です
- flakeはgit管理下のファイルしか見ません。新規ファイル追加後は必ず
  `git add` してから rebuild してください
- `$HOME is not owned by you` という警告は、`sudo` 実行時にrootへの
  fallbackが起きているだけで実害はありません
- Homebrewは casks 専用で `homebrew.onActivation.cleanup = "zap"` に
  なっています。`darwin.nix` の `casks` リストに宣言していないcaskは
  rebuild時に自動アンインストールされるので、新しいGUIアプリを
  Homebrew経由で入れる場合は必ずリストに追加してください

より詳細な移行の経緯・トラブルシュート事例は `nix-mise.md` を参照してください。
