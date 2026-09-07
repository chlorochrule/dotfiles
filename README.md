# dotfiles

macOS環境をNix (nix-darwin + home-manager) + Homebrew (casksのみ) + miseで宣言的に管理するdotfilesリポジトリです。

## 設計方針

| ツール | 役割 |
|---|---|
| **Nix** (nix-darwin + home-manager) | macOSシステム設定の宣言管理、グローバルCLIツール、dotfiles配置、Homebrew自体の宣言管理 |
| **Homebrew** | GUIアプリ(casks)専用。formulaは使わない |
| **mise** | プロジェクト単位の言語ランタイムバージョン管理(node, python等) |

ランタイム(node/python等)とCLIツールを二重管理しないことが重要です。
ランタイムはmise、CLIツールはNixで明確に分担します(ただし`nodejs`は例外です。
`mason.nvim`がLSPサーバーをnpm経由でインストールするための裏方インフラとしてNix側に置いています。
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
    run nix-darwin/nix-darwin-25.11#darwin-rebuild -- switch --flake ~/.dotfiles
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
├── services/                    # ローカル専用サービス群(Docker Compose定義)。Nix管理外
│   ├── langfuse/                 # ローカルLangfuse
│   ├── grafana/                  # ローカルGrafana
│   └── prometheus/               # ローカルPrometheus
├── terraform/
│   └── local/                    # ↑3つのプロビジョニング用Terraform(ローカルMac
│                                 #     provisioning専用ディレクトリ)。Nix管理外
│                                 # (詳細は「ローカルサービス(Langfuse/Grafana/
│                                 #     Prometheus)をTerraformでプロビジョニングする」参照)
└── CLAUDE.md                    # このリポジトリで作業する際のClaude Code向け指示
```

`home/`配下と`.tigrc`等の実ファイルは、home-managerの`mkOutOfStoreSymlink`で`~/`配下からシンボリックリンクされます。
Nix storeへコピーされないため、手編集してもrebuildなしで即座に反映されます。

### `~/.claude/{commands,skills,agents,hooks}` の共通/ホスト別マージ

これらは「全マシン共通(`home/claude/<name>/`) + このホスト固有(`hosts/<hostname>/claude/<name>/`、
存在する場合のみ)」をファイル単位でマージして`~/.claude/<name>/`を構成します
(`hosts/<hostname>/home.nix`内のマージ処理)。
同名ファイルがあればホスト固有側が優先されます。

この仕組みにより、例えば私用PCと仕事用PCの両方で共通のコマンド/スキルを使いつつ、
仕事用PCだけに追加のコマンドを持たせる、といった構成が可能です。
ただしファイル単位のシンボリックリンクになるため、**新規ファイルを追加した場合はrebuildが必要**です
(ディレクトリ単位のシンボリックリンクと違い、置くだけでは即反映されません)。

`~/.claude/settings.json` と `~/.claude/CLAUDE.md` はマージ対象外で、それぞれ単一ファイルとして扱われます。
`settings.json`はマシンごとに内容を変えたい設定(モデル選択、権限モード、hookの登録等)なので
`hosts/<hostname>/claude-settings.json` に置き、`CLAUDE.md`は全マシン共通なので
`home/claude/CLAUDE.md` に置きます。

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

## ローカルサービス(Langfuse/Grafana/Prometheus)をTerraformでプロビジョニングする

`terraform/local/`は、このMac上だけで完結するローカル専用サービス群をDocker Composeで起動し、
Terraformで冪等にプロビジョニングするための共通ディレクトリです(Nix管理外)。
1つの`terraform apply`で以下の3つがまとめて起動し、provisioningされます。
サービスごとの資源は`langfuse.tf`/`grafana.tf`/`prometheus.tf`のようにファイル単位で分けており、
出力名も`langfuse_*`/`grafana_*`/`prometheus_*`のようにprefixしています。
生成したパスワード等の資格情報はローカルの`terraform/local/terraform.tfstate`(git管理外)に保存されます。
Dockerは`hosts/MacBookPro-minami/darwin.nix`のHomebrew cask `rancher`(Rancher Desktop)で
提供されるものを使うため、Rancher Desktopを起動しておく必要があります。

各サービスは独立したdocker-compose project(`services/langfuse/`/`services/grafana/`/
`services/prometheus/`)として起動しており、共有のDockerネットワークは作っていません。
サービス間の通信(GrafanaからPrometheusへ、Prometheusからホストのnode_exporterへ)は
Rancher Desktopが提供する`host.docker.internal`(127.0.0.1限定のサービスにも到達できる)
経由で行います。
`docker-compose.yml`で`extra_hosts`により`host.docker.internal`を明示上書きすると
Linux流のブリッジゲートウェイIPになり127.0.0.1限定のサービスに届かなくなるため、
あえて指定していません。

### Langfuse: Claude Codeの操作ログを記録する

`services/langfuse/`配下にLangfuse(LLMアプリ向けの可観測性OSS)のセルフホスト用Docker Compose定義を置いています。
Claude Codeのユーザープロンプト、モデルの応答、ツール呼び出しの入出力を、
このMac上だけで完結するLangfuseに記録できます(データは外部送信されません)。

Claude Code側は公式の[langfuse/Claude-Observability-Plugin](https://github.com/langfuse/Claude-Observability-Plugin)
(hookでセッションtranscriptを読み取りLangfuseへ送信するプラグイン)を使い、
`hosts/MacBookPro-minami/claude-settings.json`の`extraKnownMarketplaces`/`enabledPlugins`/`pluginConfigs`で
宣言的にマーケットプレイス登録、有効化、`LANGFUSE_BASE_URL`の設定までを行っています。
APIキー(`LANGFUSE_PUBLIC_KEY`/`LANGFUSE_SECRET_KEY`)だけは秘密情報のためgit管理下に置かず、
初回のみ手動設定が必要です。

`services/langfuse/.env`(docker-compose.ymlのCHANGEME項目)や、
組織/プロジェクト/ログイン用ユーザーやAPIキーの初回作成(Langfuseの
[headless initialization](https://langfuse.com/self-hosting/administration/headless-initialization)、
`LANGFUSE_INIT_*`環境変数)は手動で行わず、`terraform/local/`が`terraform apply`のたびに冪等に実施します。
ブラウザでサインアップする必要はありません。
`docker-compose.yml`/`.envrc`自体は`services/langfuse/`に残しており、
`.envrc`(direnv)はTerraformが書いた`.env`をシェルにも読み込むだけの役割です。

### Grafana: ダッシュボードを見る

`services/grafana/`配下にGrafanaのセルフホスト用Docker Compose定義を置いています
(`http://localhost:3001`、外部公開しません)。
admin初期パスワードは`terraform/local/grafana.tf`が乱数で生成し`services/grafana/.env`に書き出します
(Langfuseの`.env`生成と同じ方針)。

ダッシュボード、データソース、adminアカウントは可能な限りTerraformの
[grafana/grafanaプロバイダー](https://registry.terraform.io/providers/grafana/grafana/latest/docs)で管理し、
Grafanaの管理画面からの手動設定を極力不要にしています。
データソースは下記のPrometheusのほか、組み込みのTestDataデータソースと、
それを使ったサンプルダッシュボード(`Local`フォルダ配下の`Welcome`)をTerraform管理下に置いています。
実データを見るダッシュボードを追加する際は`terraform/local/grafana.tf`に`grafana_dashboard`リソースを追記してください。

LangfuseのトレースデータはClickHouseに保存されているため、
公式署名済みの[grafana-clickhouse-datasource](https://grafana.com/grafana/plugins/grafana-clickhouse-datasource/)
プラグインを`services/grafana/docker-compose.yml`の`GF_INSTALL_PLUGINS`で導入し、
Langfuse自身のClickHouse(`services/langfuse/`)へのデータソースと、
Langfuseの[Dashboards](http://localhost:3000/project/claude-code/dashboards)
(Langfuse Home/Agent/Cost/Latency/Usage Management、Langfuse Maintained)相当のダッシュボードを
Terraform管理しています。

- `terraform/local/langfuse_grafana.tf`: Langfuse Home相当(`Langfuse Overview`)
- `terraform/local/langfuse_grafana_extra.tf`: Agent/Cost/Latency Dashboard相当
  (`Langfuse Agent`/`Langfuse Cost`/`Langfuse Latency`)

クエリはLangfuse v4のOTel統合スパンテーブル(`events_core`)に対する生SQLで、
Langfuse UIの数値と一致することを確認済みです。
Scores関連(スコアデータ無し)、Usage Managementの大半(Traces/Observations統計とほぼ重複)、
Time To First Token/出力トークン毎秒系(`completion_start_time`が未記録でLangfuse UI側も常にNo data)は
対象外にしています。

### Prometheus: macOSホストのメトリクスを収集する

`services/prometheus/`配下にPrometheusのセルフホスト用Docker Compose定義を置いています
(`http://localhost:9095`、外部公開しません。
コンテナ内部ポートは既定の9090ですが、ホスト側は`services/langfuse/`のminioが既に`9090`を
使っているため`9095`にずらしています)。
スクレイプ対象を定義する`services/prometheus/prometheus.yml`は秘密情報を含まないため
Terraform管理外で直接コミットしています。

CPU/メモリ/ディスク等、macOSホスト本体のメトリクスは
[node_exporter](https://github.com/prometheus/node_exporter)で収集します。
Dockerコンテナの中からでは真のホストメトリクスが取れないため、
`hosts/MacBookPro-minami/darwin.nix`の`services.prometheus.exporters.node`
(nix-darwin組み込みのlaunchd daemonモジュール)でホストに直接インストールし、
`127.0.0.1:9100`限定でlistenさせています。
Prometheus側はこれを`host.docker.internal:9100`としてスクレイプします。

PrometheusのGrafanaデータソース登録(`terraform/local/prometheus.tf`の
`grafana_data_source.prometheus`)もTerraform管理です。
`terraform/local/prometheus_grafana.tf`では、そのデータソースを使ってmacOSホストの
node_exporterメトリクス(Uptime/CPU/メモリ/バッテリー/ロードアベレージ/
ディスクI/O/ネットワークI/O/ファイルシステム使用率)を見る`macOS Host (node_exporter)`
ダッシュボードも管理しています。

### 初回セットアップ

```bash
# 1. Claude Codeのプラグイン設定・node_exporterを適用(claude-settings.jsonの
#    変更反映と、Prometheusがスクレイプするhost側node_exporterの有効化を兼ねる)
sudo darwin-rebuild switch --flake ~/.dotfiles

# 2. Langfuse/Grafana/Prometheusを起動(初回のprovisioningも同時に行われる)
cd ~/.dotfiles/terraform/local
terraform init
terraform apply

# 3. Claude Codeを起動し、Terraformが発行したLangfuseのAPIキーを登録
#    (SECRET_KEYはOSキーチェーンに保存される)
claude
/plugin configure langfuse-observability@langfuse-observability
#   LANGFUSE_PUBLIC_KEY: `terraform output -raw langfuse_public_key`
#   LANGFUSE_SECRET_KEY: `terraform output -raw langfuse_secret_key`
```

ブラウザからログインしたい場合、Langfuse(`http://localhost:3000`)は`terraform output langfuse_login_email` /
`terraform output -raw langfuse_login_password`、Grafana(`http://localhost:3001`)は
`terraform output grafana_login_user` / `terraform output -raw grafana_login_password`で確認できます。
Prometheus(`http://localhost:9095`)はログイン不要です。

### 運用コマンド

```bash
cd ~/.dotfiles/terraform/local

# 起動/停止(3サービスまとめて)
terraform apply
docker compose -f ../../services/langfuse/docker-compose.yml down
docker compose -f ../../services/grafana/docker-compose.yml down
docker compose -f ../../services/prometheus/docker-compose.yml down

# 発行済みAPIキー・ログイン情報の確認
terraform output -raw langfuse_public_key
terraform output -raw langfuse_secret_key
terraform output -raw langfuse_login_password
terraform output -raw grafana_login_password

# Langfuseの全データを消してやり直す(APIキー・ログイン情報は.envの内容を
# 維持したまま同じ値で再作成される。値ごと変えたい場合はterraform.tfstateも消す)
docker compose -f ../../services/langfuse/docker-compose.yml down -v
terraform apply -replace=null_resource.compose_up

# Grafanaの全データを消してやり直す(ダッシュボード等はterraform apply時に
# 再作成される。admin初期パスワードも同様の理由で同じ値のまま再作成される)
docker compose -f ../../services/grafana/docker-compose.yml down -v
terraform apply -replace=null_resource.grafana_compose_up

# Prometheusの蓄積データを消してやり直す
docker compose -f ../../services/prometheus/docker-compose.yml down -v
terraform apply -replace=null_resource.prometheus_compose_up
```

## 既知の注意点

- `darwin-rebuild switch` は `sudo` が必須です
- flakeはgit管理下のファイルしか見ません。
    新規ファイル追加後は必ず `git add` してから rebuild してください
- `$HOME is not owned by you` という警告は、
    `sudo` 実行時にrootへのfallbackが起きているだけで実害はありません
- Homebrewは casks 専用です。
    本来 `homebrew.onActivation.cleanup = "zap"` にしており、`hosts/<hostname>/darwin.nix` の
    `casks` リストに宣言していないcaskはrebuild時に自動アンインストールされます。
    新しいGUIアプリをHomebrew経由で入れる場合は必ずリストに追加してください
    (Homebrew 6.0.22で`--cleanup`フラグが廃止され、nix-darwin-25.11ブランチの対応がまだ
    未リリースのため、現在は一時的に `cleanup = "none"` にしてcleanupを無効化しています。
    修正が取り込まれ次第 `zap` に戻す予定)
- `homebrew.onActivation.autoUpdate`/`upgrade` は `true` にしてあり、`darwin-rebuild switch` の
    たびにHomebrewのタップ情報が更新され、古くなったcaskは自動で最新版へアップグレードされます
- BSLなどunfreeライセンスのパッケージ(`terraform`等)を`home.packages`に追加する場合は、
    `darwin.nix`の`nixpkgs.config.allowUnfreePredicate`にパッケージ名を追加する必要があります
- `~/.claude/{commands,skills,agents,hooks}`配下に新規ファイルを追加した場合は、
    他の`home/`配下の変更と違ってrebuildしないと反映されません(上記「ファイル構成」セクション参照)
- Claude Codeのユーザースコープ(全プロジェクト共通)MCPサーバーは`~/.claude.json`の
    `mcpServers`キーで管理されます。
    このファイルにはプロジェクト履歴やtrust状態などClaude Code自身が書き込む可変な実行時状態も
    同居しているため、home-manager側ではファイル全体をリンクせず、
    `home.activation.claudeMcpServers`(`hosts/MacBookPro-minami/home.nix`)がrebuildのたびに
    `jq`で`mcpServers`キーだけをマージします。
    現在`chrome-devtools`(`chrome-devtools-mcp`、npx経由)と`playwright`
    (nixpkgsの`playwright-mcp`)を登録しています。
    ブラウザ自動化用途のPlaywright本体(CLI)も`playwright-test`パッケージとして
    このホストの`home.packages`に含めています
- Anthropic公式のChrome拡張機能「Claude for Chrome」はChromeウェブストア経由での
    インストールが必要(現状ベータ/招待制のため)で、Nixでの宣言的管理はしていません。
    claude.aiのアカウント設定からベータを有効化し、案内されるリンクからインストールしてください
- Claude Codeの`/model`コマンドはAnthropic公式モデルのみが選択肢で、
    ローカルLLMを直接そのリストに追加する機能はありません。
    代わりに`hosts/MacBookPro-minami/home.nix`で`services.ollama.enable = true`を有効化して
    Ollama(Anthropic Messages API互換モード搭載、`127.0.0.1:11434`でlaunchd agentとして
    自動起動)を常駐させ、`ANTHROPIC_BASE_URL`等の環境変数でエンドポイントごと切り替える
    `claude-q36`/`claude-q3cn`というzsh関数(同ファイル内)を用意しています。
    通常の`claude`コマンド(Anthropic本家)には影響しません。
    モデル本体は`ollama pull`で別途取得が必要です(上記「よく使う運用コマンド」参照)。
    未知モデル名に対する警告を避けるため`CLAUDE_CODE_MAX_CONTEXT_TOKENS`も
    実際のコンテキストウィンドウ(256K)に設定しています。
    `services.ollama`の`OLLAMA_CONTEXT_LENGTH`も262144(256K、両モデルの実際の学習時
    ウィンドウ)に設定していますが、これは必須です。
    Ollamaのデフォルト`num_ctx`は4096しかなく、Claude Codeが送る長大なsystem prompt+tool
    定義だけでcontext windowをほぼ使い切ってしまい、肝心のユーザー指示が実質無視される
    (無関係な応答を返す)現象が実測で確認されたため。
    256Kに拡張後は実際のタスク(ファイル内容の正確な読み取り等)も問題なく遂行できることを
    確認済みです。
    メモリはQwen3.6-27Bで約20GB、Qwen3-Coder-Nextで約59GB(いずれも256Kコンテキスト込み)で、
    128GB環境なら問題なく収まります
- `hosts/MacBookPro-minami/darwin.nix`では、Ollamaパッケージだけ`flake.nix`の
    `nixpkgs-unstable` inputからoverlayで差し替えています。
    `nixpkgs-25.11-darwin`収録のollama(0.21.1)はアップストリームのバックポートが
    追いついておらず、Qwen3.6やQwen3-Coder-Nextのような新しいモデルのマニフェストが
    要求するバージョンを満たせず`pull`が失敗するためです。
    将来`nixpkgs-25.11-darwin`側のollamaが更新されたらこのoverlayは不要になる可能性があります
- `herdr`(AIコーディングエージェント用のターミナルワークスペースマネージャ)はnixpkgs未収録のため、
    `flake.nix`で公式の`herdr-nix`(herdr本体のprebuiltバイナリをcachix経由でハッシュ検証込みで
    取得するラッパー)をinputとして追加し、`home-manager.extraSpecialArgs`経由で全マシン共通の
    `home/default.nix`の`home.packages`に渡しています。
    cachixの`extra-substituters`/`extra-trusted-public-keys`は`darwin.nix`の`nix.extraOptions`で
    設定しています
- Ghosttyのマルチプレクサはtmuxからherdrに置き換えました。関連する変更点:
    - 起動: `home/default.nix`のzsh `initContent`が、Ghostty上の対話シェルで
        (`$HERDR_ENV`が未設定なら)`exec herdr`します。
        引数なしの`herdr`はデフォルトセッションへのアタッチ/新規作成を自動判定するため、
        tmux版のような`has-session`分岐は不要です
    - キーバインド: `.config/herdr/config.toml`でprefixを`ctrl+g`(旧tmuxと同じ)に設定し、
        旧`.tmux.conf`の`-n`(prefixなし)バインドを`alt+`キーとして再現しています
        (新規workspace/tab、workspace/tab切替、pane分割/削除等)。
        rebuild時は`home.activation`で起動中のherdrサーバーへ`herdr server reload-config`が
        自動実行されます
    - セッション永続化: herdrはサーバー再起動時にworkspace/tab/pane/cwd/layoutを標準で
        復元するため、旧tpm(`tmux-resurrect`/`tmux-continuum`)相当のプラグインは
        不要になり削除しました
    - Claude Codeとの連携: 旧`tmux-status.sh`(hookでウィンドウタブの色を手動で塗り分ける
        仕組み)を削除し、`home/claude/hooks/herdr-agent-state.sh`
        (`herdr integration install claude`が生成する公式フックと同内容)に置き換えました。
        作業中/入力待ち等のエージェント状態はherdr側の画面解析で自動検知されるため、
        hookはセッション識別情報の報告のみを行います。
        herdrのメジャーアップデートで統合フックの内容が変わった場合は、
        `herdr integration install claude`を再実行して生成物をこのファイルに反映してください
    - Neovimとの連携: `vim-tmux-navigator`を削除し、
        `.config/nvim/lua/config/keymaps.lua`に同等のCtrl+h/j/k/l境界越え移動を自前で
        実装しました(herdr内実行時のみ`$HERDR_SOCKET_PATH`で有効化、
        `herdr pane focus --direction`を呼びます)。
        `vim-tmux-navigator`はlazy.nvimの起動spec(`plugins/editing.lua`)から既に
        削除済みですが、ディスク上のプラグイン自体を消すには次回nvim起動時に
        `:Lazy clean`を実行してください
    - 旧`C-t`(現在のペインの状態に応じてtig/tig statusを開く動的な仕組み)は
        `ctrl+t`でtigをポップアップ表示する固定バインドに簡略化しました
        (`[[keys.command]]`、`.config/herdr/config.toml`)
    - `bin/tmux-kill-pane`、`tmux-kill-session`、`tmux-renumber-sessions`は削除しました。
        pane/tab/workspaceを閉じた際の「他へ退避してから閉じる」制御やid再割り当ては
        herdr側の標準動作に委ねています
