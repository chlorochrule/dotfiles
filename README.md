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
ランタイムはmise、CLIツールはNix、で明確に分担します(ただし`nodejs`は例外で、
`mason.nvim`がLSPサーバーをnpm経由でインストールするための裏方インフラとして
Nix側に置いています。ディレクトリに依存せず常に同じものが使える必要があるためです)。

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

`hosts/<ホスト名>/` を新規作成します(既存の `hosts/MacBookPro-minami/` を
参考にしてください)。最低限必要なのは `default.nix` だけです。

```nix
# hosts/<ホスト名>/default.nix
{
    hostname = "<ホスト名>";   # scutil --get LocalHostName の出力と一致させる
    username = "<ユーザー名>";
    system = "aarch64-darwin";
}
```

このマシン固有の設定を追加したい場合は、同じディレクトリに以下を置きます
(どれも任意、無くてもよい)。

- `darwin.nix` — このマシンだけのnix-darwin設定(例: Homebrew casksの構成)
- `home.nix` — このマシンだけのhome-manager設定(例: git identity、
    `~/.claude/settings.json`)

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
│                                 # (system.defaults, フォント, unfreeパッケージの許可等)
├── hosts/
│   └── <hostname>/
│       ├── default.nix          # マシン固有の値(hostname, username, system)
│       ├── darwin.nix           # (任意)マシン固有のnix-darwin設定。例: Homebrew casks
│       ├── home.nix             # (任意)マシン固有のhome-manager設定
│       │                         # 例: git identity、~/.claude/settings.json、
│       │                         #     commands/skills/agents/hooksへの追加分
│       └── claude-settings.json # (任意)このホスト用の~/.claude/settings.json
├── home/
│   ├── default.nix              # 全マシン共通のhome-manager設定
│   │                             # (zsh, git, mise, fzf, eza, starship, ghostty等)
│   └── claude/                  # ~/.claude/配下、全マシン共通の内容
│       ├── CLAUDE.md
│       ├── commands/
│       ├── skills/
│       ├── agents/
│       └── hooks/
├── .config/nvim/                # Neovim設定(Lua + lazy.nvim)
├── .tigrc, .tmux.conf, .editorconfig, bin/  # mkOutOfStoreSymlinkで~/に実ファイル参照
└── CLAUDE.md                    # このリポジトリで作業する際のClaude Code向け指示
```

`home/`配下と`.tigrc`等の実ファイルは、home-managerの`mkOutOfStoreSymlink`で
`~/`配下からシンボリックリンクされます。Nix storeへコピーされないため、
手編集してもrebuildなしで即座に反映されます。

### `~/.claude/{commands,skills,agents,hooks}` の共通/ホスト別マージ

これらは「全マシン共通(`home/claude/<name>/`) + このホスト固有
(`hosts/<hostname>/claude/<name>/`、存在する場合のみ)」をファイル単位で
マージして`~/.claude/<name>/`を構成します(`hosts/<hostname>/home.nix`内の
マージ処理)。同名ファイルがあればホスト固有側が優先されます。

この仕組みにより、例えば私用PCと仕事用PCの両方で共通のコマンド/スキルを
使いつつ、仕事用PCだけに追加のコマンドを持たせる、といった構成が可能です。
ただしファイル単位のシンボリックリンクになるため、**新規ファイルを追加した
場合はrebuildが必要**です(ディレクトリ単位のシンボリックリンクと違い、
置くだけでは即反映されません)。

`~/.claude/settings.json` と `~/.claude/CLAUDE.md` はマージ対象外で、
それぞれ単一ファイルとして扱われます。`settings.json`はマシンごとに
内容を変えたい設定(モデル選択、権限モード、hookの登録等)なので
`hosts/<hostname>/claude-settings.json` に置き、`CLAUDE.md`は
全マシン共通なので `home/claude/CLAUDE.md` に置きます。

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
    なっています。`hosts/<hostname>/darwin.nix` の `casks` リストに
    宣言していないcaskは rebuild時に自動アンインストールされるので、
    新しいGUIアプリをHomebrew経由で入れる場合は必ずリストに追加してください
- BSLなどunfreeライセンスのパッケージ(`terraform`等)を`home.packages`に
    追加する場合は、`darwin.nix`の`nixpkgs.config.allowUnfreePredicate`に
    パッケージ名を追加する必要があります
- `~/.claude/{commands,skills,agents,hooks}`配下に新規ファイルを追加した
    場合は、他の`home/`配下の変更と違ってrebuildしないと反映されません
    (上記「ファイル構成」セクション参照)
