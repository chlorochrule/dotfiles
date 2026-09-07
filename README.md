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
│       │                         #     commands/skills/agents/hooksへの追加分、
│       │                         #     ローカルLLM(Ollama)関連設定
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
├── .config/herdr/config.toml    # herdr(ghosttyのマルチプレクサ)の設定
├── .tigrc, .editorconfig, bin/  # mkOutOfStoreSymlinkで~/に実ファイル参照
├── langfuse/                    # ローカルLangfuse(Docker Compose定義)。Nix管理外
├── grafana/                     # ローカルGrafana(Docker Compose定義)。Nix管理外
├── terraform/
│   └── local/                    # ↑2つのプロビジョニング用Terraform(ローカルMac
│                                 #     provisioning専用ディレクトリ)。Nix管理外
│                                 # (詳細は「ローカルサービス(Langfuse/Grafana)を
│                                 #     Terraformでプロビジョニングする」参照)
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

# ローカルLLMモデルの取得(MacBookPro-minami、初回のみ・数十GB)
ollama pull qwen3.6:27b        # dense 27B, 18GB(q4_K_M), SWE-bench Verified 77.2
ollama pull qwen3-coder-next   # 80B MoE/3B active, 46GB, コーディングエージェント特化

# ローカルLLM(Ollama)経由でClaude Codeを起動
claude-q36    # Qwen3.6-27B
claude-q3cn   # Qwen3-Coder-Next
```

## ローカルサービス(Langfuse/Grafana)をTerraformでプロビジョニングする

`terraform/local/`は、このMac上だけで完結するローカル専用サービス群を
Docker Composeで起動し、Terraformで冪等にプロビジョニングするための
共通ディレクトリです(Nix管理外)。1つの`terraform apply`で以下の
両方がまとめて起動・provisioningされます。サービスごとの資源は
`langfuse.tf`/`grafana.tf`のようにファイル単位で分けており、出力名も
`langfuse_*`/`grafana_*`のようにprefixしています。生成したパスワード等の
資格情報はローカルの`terraform/local/terraform.tfstate`(git管理外)に
保存されます。Dockerは`hosts/MacBookPro-minami/darwin.nix`のHomebrew
cask `rancher`(Rancher Desktop)で提供されるものを使うため、Rancher
Desktopを起動しておく必要があります。

### Langfuse: Claude Codeの操作ログを記録する

`langfuse/`配下にLangfuse(LLMアプリ向けの可観測性OSS)のセルフホスト用
Docker Compose定義を置いています。Claude Codeのユーザープロンプト、
モデルの応答、ツール呼び出しの入出力を、このMac上だけで完結するLangfuseに
記録できます(データは外部送信されません)。

Claude Code側は公式の[langfuse/Claude-Observability-Plugin](https://github.com/langfuse/Claude-Observability-Plugin)
(hookでセッションtranscriptを読み取りLangfuseへ送信するプラグイン)を使い、
`hosts/MacBookPro-minami/claude-settings.json`の`extraKnownMarketplaces`/
`enabledPlugins`/`pluginConfigs`で宣言的にマーケットプレイス登録・有効化・
`LANGFUSE_BASE_URL`の設定までを行っています。APIキー(`LANGFUSE_PUBLIC_KEY`/
`LANGFUSE_SECRET_KEY`)だけは秘密情報のためgit管理下に置かず、初回のみ
手動設定が必要です。

`langfuse/.env`(docker-compose.ymlのCHANGEME項目)や、組織/プロジェクト/
ログイン用ユーザー・APIキーの初回作成(Langfuseの
[headless initialization](https://langfuse.com/self-hosting/administration/headless-initialization)、
`LANGFUSE_INIT_*`環境変数)は手動で行わず、`terraform/local/`が
`terraform apply`のたびに冪等に実施します。ブラウザでサインアップする
必要はありません。`docker-compose.yml`/`.envrc`自体は`langfuse/`に
残しており、`langfuse/.envrc`(direnv)はTerraformが書いた`.env`を
シェルにも読み込むだけの役割です。

### Grafana: ダッシュボードを見る

`grafana/`配下にGrafanaのセルフホスト用Docker Compose定義を置いています
(`http://localhost:3001`、外部公開しません)。admin初期パスワードは
`terraform/local/grafana.tf`が乱数で生成し`grafana/.env`に書き出します
(Langfuseの`.env`生成と同じ方針)。

ダッシュボード・データソース・adminアカウントは可能な限りTerraformの
[grafana/grafanaプロバイダー](https://registry.terraform.io/providers/grafana/grafana/latest/docs)
で管理し、Grafanaの管理画面からの手動設定を極力不要にしています。
現時点では外部メトリクスソース(Prometheus等)を構築していないため、
組み込みのTestDataデータソースと、それを使ったサンプルダッシュボード
(`Local`フォルダ配下の`Welcome`)のみをTerraform管理下に置いています。
実際のデータソースを追加する際は`terraform/local/grafana.tf`に
`grafana_data_source`/`grafana_dashboard`リソースを追記してください。

### 初回セットアップ

```bash
# 1. Langfuse/Grafanaを起動(初回のprovisioningも同時に行われる)
cd ~/.dotfiles/terraform/local
terraform init
terraform apply

# 2. Claude Codeのプラグイン設定を適用(claude-settings.jsonの変更を反映)
sudo darwin-rebuild switch --flake ~/.dotfiles

# 3. Claude Codeを起動し、Terraformが発行したLangfuseのAPIキーを登録
#    (SECRET_KEYはOSキーチェーンに保存される)
claude
/plugin configure langfuse-observability@langfuse-observability
#   LANGFUSE_PUBLIC_KEY: `terraform output -raw langfuse_public_key`
#   LANGFUSE_SECRET_KEY: `terraform output -raw langfuse_secret_key`
```

ブラウザからログインしたい場合、Langfuse(`http://localhost:3000`)は
`terraform output langfuse_login_email` /
`terraform output -raw langfuse_login_password`、
Grafana(`http://localhost:3001`)は
`terraform output grafana_login_user` /
`terraform output -raw grafana_login_password`で確認できます。

### 運用コマンド

```bash
cd ~/.dotfiles/terraform/local

# 起動/停止(両サービスまとめて)
terraform apply
docker compose -f ../../langfuse/docker-compose.yml down
docker compose -f ../../grafana/docker-compose.yml down

# 発行済みAPIキー・ログイン情報の確認
terraform output -raw langfuse_public_key
terraform output -raw langfuse_secret_key
terraform output -raw langfuse_login_password
terraform output -raw grafana_login_password

# Langfuseの全データを消してやり直す(APIキー・ログイン情報は.envの内容を
# 維持したまま同じ値で再作成される。値ごと変えたい場合はterraform.tfstateも消す)
docker compose -f ../../langfuse/docker-compose.yml down -v
terraform apply -replace=null_resource.compose_up

# Grafanaの全データを消してやり直す(ダッシュボード等はterraform apply時に
# 再作成される。admin初期パスワードも同様の理由で同じ値のまま再作成される)
docker compose -f ../../grafana/docker-compose.yml down -v
terraform apply -replace=null_resource.grafana_compose_up
```

## 既知の注意点

- `darwin-rebuild switch` は `sudo` が必須です
- flakeはgit管理下のファイルしか見ません。新規ファイル追加後は必ず
    `git add` してから rebuild してください
- `$HOME is not owned by you` という警告は、`sudo` 実行時にrootへの
    fallbackが起きているだけで実害はありません
- Homebrewは casks 専用です。本来 `homebrew.onActivation.cleanup = "zap"` にしており、
    `hosts/<hostname>/darwin.nix` の `casks` リストに宣言していないcaskは
    rebuild時に自動アンインストールされます。新しいGUIアプリをHomebrew経由で
    入れる場合は必ずリストに追加してください
    (Homebrew 6.0.22で`--cleanup`フラグが廃止され、nix-darwin-25.11ブランチの
    対応がまだ未リリースのため、現在は一時的に `cleanup = "none"` にしてcleanupを
    無効化しています。修正が取り込まれ次第 `zap` に戻す予定)
- `homebrew.onActivation.autoUpdate`/`upgrade` は `true` にしてあり、
    `darwin-rebuild switch` のたびにHomebrewのタップ情報が更新され、
    古くなったcaskは自動で最新版へアップグレードされます
- BSLなどunfreeライセンスのパッケージ(`terraform`等)を`home.packages`に
    追加する場合は、`darwin.nix`の`nixpkgs.config.allowUnfreePredicate`に
    パッケージ名を追加する必要があります
- `~/.claude/{commands,skills,agents,hooks}`配下に新規ファイルを追加した
    場合は、他の`home/`配下の変更と違ってrebuildしないと反映されません
    (上記「ファイル構成」セクション参照)
- Claude Codeのユーザースコープ(全プロジェクト共通)MCPサーバーは
    `~/.claude.json`の`mcpServers`キーで管理されます。この
    ファイルにはプロジェクト履歴やtrust状態などClaude Code自身が書き込む
    可変な実行時状態も同居しているため、home-manager側では
    ファイル全体をリンクせず、`home.activation.claudeMcpServers`
    (`hosts/MacBookPro-minami/home.nix`)がrebuildのたびに`jq`で
    `mcpServers`キーだけをマージします。現在`chrome-devtools`
    (`chrome-devtools-mcp`、npx経由)と`playwright`
    (nixpkgsの`playwright-mcp`)を登録しています。ブラウザ自動化用途の
    Playwright本体(CLI)も`playwright-test`パッケージとして
    このホストの`home.packages`に含めています
- Anthropic公式のChrome拡張機能「Claude for Chrome」はChromeウェブストア
    経由でのインストールが必要(現状ベータ/招待制のため)で、Nixでの宣言的
    管理はしていません。claude.aiのアカウント設定からベータを有効化し、
    案内されるリンクからインストールしてください
- Claude Codeの`/model`コマンドはAnthropic公式モデルのみが選択肢で、
    ローカルLLMを直接そのリストに追加する機能はありません。代わりに
    `hosts/MacBookPro-minami/home.nix`で`services.ollama.enable = true`を
    有効化してOllama(Anthropic Messages API互換モード搭載、
    `127.0.0.1:11434`でlaunchd agentとして自動起動)を常駐させ、
    `ANTHROPIC_BASE_URL`等の環境変数でエンドポイントごと切り替える
    `claude-q36`/`claude-q3cn`というzsh関数(同ファイル内)を用意しています。
    通常の`claude`コマンド(Anthropic本家)には影響しません。モデル本体は
    `ollama pull`で別途取得が必要です(上記「よく使う運用コマンド」参照)。
    未知モデル名に対する警告を避けるため`CLAUDE_CODE_MAX_CONTEXT_TOKENS`も
    実際のコンテキストウィンドウ(256K)に設定しています。`services.ollama`の
    `OLLAMA_CONTEXT_LENGTH`も262144(256K、両モデルの実際の学習時ウィンドウ)に
    設定していますが、これは必須です。Ollamaのデフォルト`num_ctx`は4096しか
    なく、Claude Codeが送る長大なsystem prompt+tool定義だけでcontext windowを
    ほぼ使い切ってしまい、肝心のユーザー指示が実質無視される(無関係な応答を
    返す)現象が実測で確認されたため。256Kに拡張後は実際のタスク(ファイル内容の
    正確な読み取り等)も問題なく遂行できることを確認済みです。メモリは
    Qwen3.6-27Bで約20GB、Qwen3-Coder-Nextで約59GB(いずれも256Kコンテキスト
    込み)で、128GB環境なら問題なく収まります
- `hosts/MacBookPro-minami/darwin.nix`では、Ollamaパッケージだけ
    `flake.nix`の`nixpkgs-unstable` inputからoverlayで差し替えています。
    `nixpkgs-25.11-darwin`収録のollama(0.21.1)はアップストリームの
    バックポートが追いついておらず、Qwen3.6やQwen3-Coder-Nextのような
    新しいモデルのマニフェストが要求するバージョンを満たせず`pull`が
    失敗するためです。将来`nixpkgs-25.11-darwin`側のollamaが更新されたら
    このoverlayは不要になる可能性があります
- `herdr`(AIコーディングエージェント用のターミナルワークスペースマネージャ)は
    nixpkgs未収録のため、`flake.nix`で公式の`herdr-nix`(herdr本体のprebuilt
    バイナリをcachix経由でハッシュ検証込みで取得するラッパー)をinputとして
    追加し、`home-manager.extraSpecialArgs`経由で全マシン共通の`home/default.nix`の
    `home.packages`に渡しています。cachixの`extra-substituters`/
    `extra-trusted-public-keys`は`darwin.nix`の`nix.extraOptions`で設定しています
- Ghosttyのマルチプレクサはtmuxからherdrに置き換えました。関連する変更点:
    - 起動: `home/default.nix`のzsh `initContent`が、Ghostty上の対話シェルで
        (`$HERDR_ENV`が未設定なら)`exec herdr`します。引数なしの`herdr`は
        デフォルトセッションへのアタッチ/新規作成を自動判定するため、tmux版の
        ような`has-session`分岐は不要です
    - キーバインド: `.config/herdr/config.toml`でprefixを`ctrl+g`(旧tmuxと同じ)
        に設定し、旧`.tmux.conf`の`-n`(prefixなし)バインドを`alt+`キーとして
        再現しています(新規workspace/tab、workspace/tab切替、pane分割/削除等)。
        rebuild時は`home.activation`で起動中のherdrサーバーへ
        `herdr server reload-config`が自動実行されます
    - セッション永続化: herdrはサーバー再起動時にworkspace/tab/pane/cwd/layoutを
        標準で復元するため、旧tpm(`tmux-resurrect`/`tmux-continuum`)相当の
        プラグインは不要になり削除しました
    - Claude Codeとの連携: 旧`tmux-status.sh`(hookでウィンドウタブの色を
        手動で塗り分ける仕組み)を削除し、`home/claude/hooks/herdr-agent-state.sh`
        (`herdr integration install claude`が生成する公式フックと同内容)に
        置き換えました。作業中/入力待ち等のエージェント状態はherdr側の画面解析で
        自動検知されるため、hookはセッション識別情報の報告のみを行います。herdrの
        メジャーアップデートで統合フックの内容が変わった場合は、`herdr integration
        install claude`を再実行して生成物をこのファイルに反映してください
    - Neovimとの連携: `vim-tmux-navigator`を削除し、`.config/nvim/lua/config/keymaps.lua`
        に同等のCtrl+h/j/k/l境界越え移動を自前で実装しました(herdr内実行時のみ
        `$HERDR_SOCKET_PATH`で有効化、`herdr pane focus --direction`を呼びます)。
        `vim-tmux-navigator`はlazy.nvimの起動spec(`plugins/editing.lua`)から
        既に削除済みですが、ディスク上のプラグイン自体を消すには次回nvim起動時に
        `:Lazy clean`を実行してください
    - 旧`C-t`(現在のペインの状態に応じてtig/tig statusを開く動的な仕組み)は
        `ctrl+t`でtigをポップアップ表示する固定バインドに簡略化しました
        (`[[keys.command]]`、`.config/herdr/config.toml`)
    - `bin/tmux-kill-pane`・`tmux-kill-session`・`tmux-renumber-sessions`は
        削除しました。pane/tab/workspaceを閉じた際の「他へ退避してから閉じる」
        制御やid再割り当てはherdr側の標準動作に委ねています
