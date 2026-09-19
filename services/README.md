# ローカルサービス(Langfuse/Grafana/Prometheus)

[← dotfiles](../README.md)

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
サービス間の通信は`host.docker.internal`経由で行います。
`docker-compose.yml`に`extra_hosts`で`host.docker.internal`を明示指定しないでください
(127.0.0.1限定のサービスに届かなくなります。理由は`.claude/rules/services-terraform.md`参照)。

## Langfuse: Claude Codeの操作ログを記録する

`services/langfuse/`配下にLangfuse(LLMアプリ向けの可観測性OSS)のセルフホスト用Docker Compose定義を置いています。
Claude Codeのユーザープロンプト、モデルの応答、ツール呼び出しの入出力を、
このMac上だけで完結するLangfuseに記録できます(データは外部送信されません。
`terraform/local/langfuse.tf`が`.env`に`TELEMETRY_ENABLED=false`を書き出し、
Langfuse自体の利用統計送信も無効化しています)。

Claude Code側は公式の[langfuse/Claude-Observability-Plugin](https://github.com/langfuse/Claude-Observability-Plugin)
(hookでセッションtranscriptを読み取りLangfuseへ送信するプラグイン)を使い、
`hosts/MacBookPro-minami/claude/settings.json`の`extraKnownMarketplaces`/`enabledPlugins`/`pluginConfigs`で
宣言的にマーケットプレイス登録、有効化、`LANGFUSE_BASE_URL`の設定までを行っています。
APIキー(`LANGFUSE_PUBLIC_KEY`/`LANGFUSE_SECRET_KEY`)はgit管理下に置かず、
初回のみ`/plugin configure`での手動設定が必要です(下記「初回セットアップ」参照)。
どちらも`terraform/local/`がtfstateごとに乱数で発行する値で、SECRET_KEYは秘密情報でもあるためです。
PUBLIC_KEYは`~/.claude/settings.json`の`pluginConfigs`に書き込まれ、
rebuild時のマージでも宣言外のキーとして維持されます。

`services/langfuse/.env`(docker-compose.ymlのCHANGEME項目)や、
組織/プロジェクト/ログイン用ユーザーやAPIキーの初回作成(Langfuseの
[headless initialization](https://langfuse.com/self-hosting/administration/headless-initialization)、
`LANGFUSE_INIT_*`環境変数)は手動で行わず、`terraform/local/`が`terraform apply`のたびに冪等に実施します。
ブラウザでサインアップする必要はありません。
`docker-compose.yml`/`.envrc`自体は`services/langfuse/`に残しており、
`.envrc`(direnv)はTerraformが書いた`.env`をシェルにも読み込むだけの役割です。

## Grafana: ダッシュボードを見る

`services/grafana/`配下にGrafanaのセルフホスト用Docker Compose定義を置いています
(`http://localhost:3001`、外部公開しません)。
admin初期パスワードは`terraform/local/grafana.tf`が乱数で生成し`services/grafana/.env`に書き出します
(Langfuseの`.env`生成と同じ方針)。
`services/grafana/docker-compose.yml`では利用統計送信とバージョンチェック
(`GF_ANALYTICS_*`)も無効化しています。

ダッシュボード、データソース、adminアカウントは可能な限りTerraformの
[grafana/grafanaプロバイダー](https://registry.terraform.io/providers/grafana/grafana/latest/docs)で管理し、
Grafanaの管理画面からの手動設定を極力不要にしています。
データソースは下記のPrometheusのほか、組み込みのTestDataデータソースと、
それを使ったサンプルダッシュボード(`Local`フォルダ配下の`Welcome`)をTerraform管理下に置いています。
実データを見るダッシュボードを追加する際は`terraform/local/`の該当ファイル
(例: `langfuse_grafana.tf`、`prometheus_grafana.tf`)に`grafana_dashboard`リソースを追記してください。

LangfuseのトレースデータはClickHouseに保存されているため、
公式署名済みの[grafana-clickhouse-datasource](https://grafana.com/grafana/plugins/grafana-clickhouse-datasource/)
プラグインを`services/grafana/docker-compose.yml`の`GF_PLUGINS_PREINSTALL_SYNC`で導入し、
Langfuse自身のClickHouse(`services/langfuse/`)へのデータソースと、
Langfuseの[Dashboards](http://localhost:3000/project/claude-code/dashboards)
(Langfuse Home/Agent/Cost/Latency/Usage Management、Langfuse Maintained)相当のダッシュボードを
Terraform管理しています。

- `terraform/local/langfuse_grafana.tf`: Langfuse Home相当(`Langfuse Overview`)
- `terraform/local/langfuse_grafana_extra.tf`: Agent/Cost/Latency Dashboard相当
  (`Langfuse Agent`/`Langfuse Cost`/`Langfuse Latency`)

クエリはLangfuse v4のOTel統合スパンテーブル(`events_core`)に対する生SQLです。
Scores、Usage Managementの大半、Time To First Token系のパネルは対象外にしています
(何を対象外にしたか、なぜか、数値の検証方法は`.claude/rules/services-terraform.md`参照)。

GrafanaはこのClickHouseへ、SELECTのみ許可した専用ユーザー(`grafana_ro`)で接続しています
(設計の詳細は同上。ユーザー定義は`services/langfuse/clickhouse-users.d/`、
`terraform/local/langfuse_grafana.tf`が生成、git管理外)。

## Prometheus: macOSホストのメトリクスを収集する

`services/prometheus/`配下にPrometheusのセルフホスト用Docker Compose定義を置いています
(`http://localhost:9095`、外部公開しません。9090は`services/langfuse/`のminioが
既に使用しているため9095にずらしています)。
スクレイプ対象を定義する`services/prometheus/prometheus.yml`は秘密情報を含まないため
Terraform管理外で直接コミットしています。

CPU/メモリ/ディスク等、macOSホスト本体のメトリクスは
[node_exporter](https://github.com/prometheus/node_exporter)で収集します。
コンテナではなく`hosts/MacBookPro-minami/darwin.nix`でホストに直接インストールしており
(理由は`.claude/rules/services-terraform.md`参照)、`127.0.0.1:9100`限定でlistenさせています。
Prometheus側はこれを`host.docker.internal:9100`としてスクレイプします。

PrometheusのGrafanaデータソース登録(`terraform/local/prometheus.tf`の
`grafana_data_source.prometheus`)もTerraform管理です。
`terraform/local/prometheus_grafana.tf`では、そのデータソースを使ってmacOSホストの
node_exporterメトリクス(Uptime/CPU/メモリ/バッテリー/ロードアベレージ/
ディスクI/O/ネットワークI/O/ファイルシステム使用率)を見る`macOS Host (node_exporter)`
ダッシュボードも管理しています。

## 初回セットアップ

```bash
# 1. Claude Codeのプラグイン設定とnode_exporterを適用(claude/settings.jsonの
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

## 運用コマンド

Langfuse本体、redis、postgres、clickhouseに加え、Grafana本体とそのClickHouseプラグイン、
Prometheus本体のイメージバージョンを上げる際は、手でdocker-compose.ymlのタグを書き換えるのではなく
`.claude/skills/upgrade-services`(このリポジトリで作業する時にClaude Codeが自動検出する
プロジェクトスコープのskill)を使ってください。Grafanaダッシュボードが依存する
ClickHouseスキーマ、PromQLへの影響を確認する手順まで含みます。

```bash
cd ~/.dotfiles/terraform/local

# 起動/停止(3サービスまとめて)
terraform apply
docker compose -f ../../services/langfuse/docker-compose.yml down
docker compose -f ../../services/grafana/docker-compose.yml down
docker compose -f ../../services/prometheus/docker-compose.yml down

# 発行済みのAPIキーとログイン情報を確認
terraform output -raw langfuse_public_key
terraform output -raw langfuse_secret_key
terraform output -raw langfuse_login_password
terraform output -raw grafana_login_password

# Langfuseの全データを消してやり直す(APIキーとログイン情報は.envの内容を
# 維持したまま同じ値で再作成される。値ごと変えたい場合はterraform.tfstateも消す)
docker compose -f ../../services/langfuse/docker-compose.yml down -v
terraform apply -replace=terraform_data.compose_up

# Grafanaの全データを消してやり直す(ダッシュボード等はterraform apply時に
# 再作成される。admin初期パスワードも同様の理由で同じ値のまま再作成される)
docker compose -f ../../services/grafana/docker-compose.yml down -v
terraform apply -replace=terraform_data.grafana_compose_up

# Prometheusの蓄積データを消してやり直す
docker compose -f ../../services/prometheus/docker-compose.yml down -v
terraform apply -replace=terraform_data.prometheus_compose_up
```
