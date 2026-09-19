# dotfiles

macOS環境をNix (nix-darwin + home-manager) + Homebrew (casksのみ) + miseで宣言的に管理するdotfilesリポジトリです。
Claude Codeとも深く統合しており、rules/skills/hooksの配布から、herdr(ターミナルマルチプレクサ)連携、
操作ログを可視化するローカル観測スタックまでこのリポジトリで管理しています。

著者(minami)個人の環境設定です。`hosts/MacBookPro-minami/`はその一例で、
自分の環境で使う場合は「セットアップ手順」に従って自分のホスト定義を追加してください。

## 設計方針

| ツール | 役割 |
|---|---|
| **Nix** (nix-darwin + home-manager) | macOSシステム設定の宣言管理、グローバルCLIツール、dotfiles配置、Homebrew自体の宣言管理 |
| **Homebrew** | GUIアプリ(casks)専用。formulaは使わない |
| **mise** | プロジェクト単位の言語ランタイムバージョン管理(node, python等) |

ランタイムはmise、CLIツールはNixで分担します(ただし`nodejs`は例外です。
`mason.nvim`がLSPサーバーをnpm経由でインストールする裏方インフラとしてNix側に置いています。
ディレクトリに依存せず常に同じものが使える必要があるためです)。

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

`hosts/<ホスト名>/` を新規作成します(既存の `hosts/MacBookPro-minami/` を参考にしてください)。
最低限必要なのは `default.nix` だけです。

```nix
# hosts/<ホスト名>/default.nix
{
    hostname = "<ホスト名>";   # scutil --get LocalHostName の出力と一致させる
    username = "<ユーザー名>";
    system = "aarch64-darwin";
}
```

このマシン固有の設定を追加したい場合は、同じディレクトリに以下を置きます(どれも任意、無くてもよい)。

- **`darwin.nix`**：このマシンだけのnix-darwin設定(例: Homebrew casksの構成)
- **`home.nix`**：このマシンだけのhome-manager設定(例: git identity、`~/.claude/settings.json`)

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
    run nix-darwin/nix-darwin-26.05#darwin-rebuild -- switch --flake ~/.dotfiles
```

`/etc/bashrc` や `/etc/zshrc` など、nix-darwinが管理しようとするファイルが既に存在する場合は `Unexpected files in /etc` のようなエラーで止まります。
表示される指示に従い、対象ファイルを `<ファイル名>.before-nix-darwin` にリネームしてから再実行してください。

### 5. 以降の運用

2回目以降は通常の `darwin-rebuild` コマンドが使えます。

```bash
sudo darwin-rebuild switch --flake ~/.dotfiles
```

設定ファイルを編集したら、`git add` してから上記コマンドを実行してください(flakeはgit管理下のファイルしか見ません)。
home-manager側の設定(zsh、git、mise、Ghostty等)もこの1コマンドで一緒に適用されます。

## よく使う運用コマンド

```bash
# 設定変更を適用
sudo darwin-rebuild switch --flake ~/.dotfiles

# inputsを最新化(flake.lockを更新)。flake.lockの書き込みだけなのでsudo不要
nix --extra-experimental-features "nix-command flakes" flake update

# 特定inputのみ更新
nix --extra-experimental-features "nix-command flakes" flake update <input名>

# 世代の確認とロールバック
darwin-rebuild --list-generations
sudo darwin-rebuild switch --rollback

# ガベージコレクション
sudo nix-collect-garbage --delete-older-than 30d

# ローカルLLMモデルの取得(MacBookPro-minami、初回のみ、数十GB)
ollama pull qwen3.6:27b        # dense 27B, 18GB(q4_K_M)
ollama pull qwen3-coder-next   # 80B MoE/3B active, 46GB

# pull後、256Kコンテキストを焼き込んだ派生モデル(*-262k)を作るためrebuildが必要
sudo darwin-rebuild switch --flake ~/.dotfiles

# ローカルLLM(Ollama)経由でClaude Codeを起動
claude-q36    # Qwen3.6-27B
claude-q3cn   # Qwen3-Coder-Next
```

## ファイル構成

```
~/.dotfiles/
├── .claude/
│   ├── skills/                  # このリポジトリで作業する時だけ使うプロジェクトスコープの
│   │                             # skill(Claude Codeがこのリポジトリ内で自動検出する)。
│   │                             # ~/.claude/配下へはデプロイされない(home/claude/skills/とは別物)。
│   │                             # 例: upgrade-services(services/配下のバージョンを上げる手順)
│   └── rules/                   # 各設定の「なぜ」をまとめたLLM向け背景情報
│                                 # (frontmatterのpathsでpath-scopedロード。人間が読んでも構わない)
├── flake.nix                    # inputs定義、ホストをdarwinConfigurationsへ自動展開
├── darwin.nix                   # 全マシン共通のnix-darwin設定
│                                 # (system.defaults, フォント, unfreeパッケージの許可等)
├── hosts/
│   └── <hostname>/
│       ├── default.nix          # マシン固有の値(hostname, username, system)
│       ├── darwin.nix           # (任意)マシン固有のnix-darwin設定。例: Homebrew casks
│       ├── home.nix             # (任意)マシン固有のhome-manager設定
│       │                         # 例: git identity、~/.claude/settings.json、
│       │                         #     commands/skills/agents/hooksへの追加分、
│       │                         #     ローカルLLM(Ollama)関連設定
│       └── claude/
│           └── settings.json    # (任意)このホスト用の~/.claude/settings.json
├── home/
│   ├── default.nix              # 全マシン共通のhome-manager設定
│   │                             # (zsh, git, mise, fzf, eza, starship, ghostty等)
│   └── claude/                  # ~/.claude/配下、全マシン共通の内容
│       ├── CLAUDE.md
│       ├── commands/            # (任意)現在は中身が無いためgit上には存在しない
│       ├── skills/              # (任意)同上
│       ├── agents/              # (任意)同上
│       └── hooks/               # editorconfig-check.sh, herdr-agent-state.sh
├── .config/nvim/                # Neovim設定(Lua + lazy.nvim)
├── .config/herdr/config.toml    # herdr(ghosttyのマルチプレクサ)の設定
├── .tigrc, .editorconfig, bin/  # mkOutOfStoreSymlinkで~/に実ファイル参照
├── services/                    # ローカル専用サービス群(Docker Compose定義)。Nix管理外
│   ├── README.md                 # 詳細ガイド(下記「ローカルサービス」参照)
│   ├── langfuse/                 # ローカルLangfuse
│   ├── grafana/                  # ローカルGrafana
│   └── prometheus/               # ローカルPrometheus
├── terraform/
│   └── local/                    # ↑3つをプロビジョニングするTerraform(ローカルMac専用)。Nix管理外
└── CLAUDE.md                    # このリポジトリで作業する際のClaude Code向け指示
```

`home/`配下と`.tigrc`等の実ファイルは、home-managerの`mkOutOfStoreSymlink`で`~/`配下からシンボリックリンクされます。
Nix storeへコピーされないため、手編集してもrebuildなしで即座に反映されます
(`~/.claude/settings.json`は例外。後述)。

### `~/.claude/{commands,skills,agents,hooks}` の共通/ホスト別マージ

全マシン共通(`home/claude/<name>/`)とホスト固有(`hosts/<hostname>/claude/<name>/`)をファイル単位でマージして
`~/.claude/<name>/`を構成します(同名ファイルはホスト固有が優先)。
ファイル単位のシンボリックリンクのため、**新規ファイルを追加した場合はrebuildが必要**です。
詳しい仕組みは`.claude/rules/nix-hosts.md`を参照してください。

`~/.claude/settings.json`と`~/.claude/CLAUDE.md`はマージ対象外の単一ファイルです。
`settings.json`は`hosts/<hostname>/claude/settings.json`、`CLAUDE.md`は`home/claude/CLAUDE.md`に置きます。
`settings.json`は実ファイルとして置かれ、rebuildのたびにリポジトリの内容だけが上書きマージされます
(Claude Code自身が実行時に追加する権限やプラグイン設定はそのまま残ります)。

## 既知の注意点

- `darwin-rebuild switch` は `sudo` が必須です
- flakeはgit管理下のファイルしか見ません。
    新規ファイル追加後は必ず `git add` してから rebuild してください
- `$HOME is not owned by you` という警告は、
    `sudo` 実行時にrootへのfallbackが起きているだけで実害はありません
- Homebrewは casks 専用です。
    `homebrew.onActivation.cleanup = "zap"` にしており、`hosts/<hostname>/darwin.nix` の
    `casks` リストに宣言していないcaskはrebuild時に自動アンインストールされます。
    新しいGUIアプリをHomebrew経由で入れる場合は必ずリストに追加してください
- `homebrew.onActivation.autoUpdate`/`upgrade` は `true` にしてあり、`darwin-rebuild switch` の
    たびにHomebrewのタップ情報が更新され、古くなったcaskは自動で最新版へアップグレードされます
- 全リポジトリ共通のgitleaks pre-commitフックは`init.templateDir`経由で配布しているため、
    既存のリポジトリに導入するにはそのリポジトリで`git init`を再実行してください
    (既存のフックファイルは上書きされません)
- BSLなどunfreeライセンスのパッケージ(`terraform`等)を`home.packages`に追加する場合は、
    `darwin.nix`の`nixpkgs.config.allowUnfreePredicate`にパッケージ名を追加する必要があります
- Anthropic公式のChrome拡張機能「Claude for Chrome」はChromeウェブストア経由での
    インストールが必要(現状ベータ/招待制のため)で、Nixでの宣言的管理はしていません。
    claude.aiのアカウント設定からベータを有効化し、案内されるリンクからインストールしてください
- Ollama(`claude-q36`/`claude-q3cn`。上記「よく使う運用コマンド」参照)は`nixpkgs`のDarwin
    リリースブランチ収録版です。新しいモデルが要求するバージョンを`pull`が満たせない場合は、
    `nixpkgs-unstable`をflakeのinputに追加し、`hosts/<hostname>/darwin.nix`の
    `nixpkgs.overlays`でollamaだけ差し替えてください
- herdrのメジャーアップデートで統合フックの内容が変わった場合は、
    `herdr integration install claude`を再実行し、`home/claude/hooks/herdr-agent-state.sh`へ
    生成物を反映してください

## ローカルサービス(Langfuse/Grafana/Prometheus)

Claude Codeの操作ログ(Langfuse)、そのダッシュボード(Grafana)、macOSホストのメトリクス(Prometheus)を
このMac上だけで動かすオプション機能です。3つまとめてTerraformでプロビジョニングします。

```bash
cd ~/.dotfiles/terraform/local
terraform init
terraform apply
```

各サービスの役割、初回セットアップの完全な手順、バージョンアップ等の運用コマンドは
[services/README.md](services/README.md) を参照してください。
