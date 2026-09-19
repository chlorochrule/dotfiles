---
name: upgrade-services
description: >-
  dotfilesリポジトリのローカル専用サービス(services/langfuse, services/grafana,
  services/prometheus)でバージョンを明示的に固定しているイメージ・プラグインを上げる手順。
  対象はLangfuse本体(langfuse-web/langfuse-worker)・redis・postgres・clickhouse、
  Grafana本体・grafana-clickhouse-datasourceプラグイン、Prometheus本体。
  「Langfuseを最新にして」「Grafanaのバージョン上げて」「ClickHouseプラグイン更新して」
  「Prometheusをアップグレードして」のように名前が出た場合はもちろん、このリポジトリで
  作業中に対象がこれらのサービスで「バージョン上げて」「更新して」「アップグレードして」
  と言われた場合も必ず使うこと。GrafanaダッシュボードがLangfuseのClickHouseスキーマ
  (events_core)に生SQLで直接依存しており、docker-compose.ymlのタグを書き換えるだけでは
  検証不足になるため、素朴な書き換えではなくこのスキルの確認・適用・検証・ロールバック
  手順に従う。
---

# ローカルサービスのバージョンを上げる

## 前提

- `services/langfuse/docker-compose.yml`では、上流(langfuse/langfuse公式リポジトリ)が
  メジャーバージョンのみの移動タグ(`:4`/`:7`/`:17`)で追従させている4つのイメージ
  (`langfuse-worker`、`langfuse`、`redis`、`postgres`)を、導入時点の実バージョンへ明示的に
  固定している。理由はdocker-compose.yml先頭のコメントを参照。
- `clickhouse`も同じ理由で固定している。ただし上流はマイナー系列の移動タグ(`:25.12`)で
  指定しており、Langfuseとの組み合わせで検証されているのはその系列なので、
  **系列は上流のdocker-compose.ymlに合わせ、系列内の最新パッチに固定する**方針にしている。
- `services/grafana/docker-compose.yml`ではGrafana本体のイメージタグと、
  `GF_PLUGINS_PREINSTALL_SYNC`で導入しているclickhouseプラグイン
  (`grafana-clickhouse-datasource@X.Y.Z`)を固定している。
- `services/prometheus/docker-compose.yml`ではPrometheus本体のイメージタグを固定している。
- `minio`(services/langfuse)はこのスキルの対象外。Chainguardの無料枠が`latest`タグしか
  提供していないため、あえて固定していない(理由はdocker-compose.ymlのコメント参照)。
- node_exporterはこのスキルの対象外。Dockerイメージではなく、
  `hosts/MacBookPro-minami/darwin.nix`が管理するホスト直接インストールのバイナリのため。
- 作業前に`git status`でこのリポジトリがクリーンであることを確認する。無関係な変更が
  混ざっているとバージョン更新のコミットが追いにくくなる。

## 手順

### 1. 対象と現在のバージョンを確認する

ユーザーの依頼からどのサービスが対象か特定し、該当するdocker-compose.ymlのimageタグを読む。

- Langfuse: `services/langfuse/docker-compose.yml`の5箇所
  (`langfuse-worker`、`langfuse`、`redis`、`postgres:${POSTGRES_VERSION:-...}`、`clickhouse`)。
  `langfuse-worker`と`langfuse`は同じLangfuseアプリケーションのサーバー/ワーカーなので、
  常に同じバージョンに揃えること(片方だけ上げると動作しない)。
- Grafana: `services/grafana/docker-compose.yml`の`image:`と`GF_PLUGINS_PREINSTALL_SYNC`。
- Prometheus: `services/prometheus/docker-compose.yml`の`image:`。

### 2. 最新版を確認する

`scripts/list-registry-tags.sh`でDocker Hub(またはそのミラー)からタグ一覧を取得し、
`scripts/latest-patch.sh`に現在のバージョンを渡して「同じメジャーバージョン内での最新パッチ」を求める。

#### Langfuse

postgresのタグは`17.11`のような2要素(メジャー.パッチ)、redis/langfuseは
`7.4.11`のような3要素(メジャー.マイナー.パッチ)で、書式が異なる。
`latest-patch.sh`はどちらの書式にも対応しており、`sort -V`を素朴に使うのと違って
**メジャーバージョンを跨いだ比較をしない**(跨いだ場合は別扱いで警告するだけ)。
これは、postgresの現行タグ(2要素)が旧書式(9.6.24のような3要素)の正規表現に
誤ってマッチしてしまうことや、redis 7→8のようなメジャー更新が「たまたま最新」として
素通りしてしまうことを実際に確認した上での対応。

```bash
scripts/list-registry-tags.sh docker.langfuse.com langfuse/langfuse-worker \
  | scripts/latest-patch.sh <現在のバージョン>
scripts/list-registry-tags.sh docker.langfuse.com langfuse/langfuse \
  | scripts/latest-patch.sh <現在のバージョン>
scripts/list-registry-tags.sh registry-1.docker.io library/redis \
  | scripts/latest-patch.sh <現在のバージョン>
scripts/list-registry-tags.sh registry-1.docker.io library/postgres \
  | scripts/latest-patch.sh <現在のバージョン>
```

clickhouseのタグは`25.12.11.4`(年.月.パッチ.ビルド)の4要素で、先頭が年のため
`latest-patch.sh`の「同じメジャー内」の比較は使えない。代わりに、上流の
docker-compose.ymlが指定している系列を確認し、その系列内の最新パッチを求める。

```bash
curl -fsSL https://raw.githubusercontent.com/langfuse/langfuse/main/docker-compose.yml \
  | grep 'clickhouse-server:'
scripts/list-registry-tags.sh registry-1.docker.io clickhouse/clickhouse-server \
  | grep -E '^<上流の系列(例: 25\.12)>\.[0-9]+\.[0-9]+$' | sort -V | tail -1
```

上流の系列が現在の固定値の系列から変わっていた場合は、系列の移行として別扱いで提示する。
ClickHouseはデータ形式の都合で新しい系列から古い系列へ戻せないことがあるため、
移行する場合は事前に`langfuse_clickhouse_data`ボリュームのバックアップを取るよう伝える。

#### Grafana本体

`grafana/grafana`は`13.0.2`のような3要素タグなので、そのまま使える。

```bash
scripts/list-registry-tags.sh registry-1.docker.io grafana/grafana \
  | scripts/latest-patch.sh <現在のバージョン>
```

#### Grafanaのclickhouseプラグイン(grafana-clickhouse-datasource)

Docker registryではなくGrafanaのプラグインカタログAPIから取得する。

```bash
curl -fsSL https://grafana.com/api/plugins/grafana-clickhouse-datasource | jq -r '.version'
```

同じレスポンスの`.json.dependencies.grafanaDependency`(例: `>=10.4.0`)で、その版が
要求するGrafana本体の最小バージョンも確認する。Grafana本体を上げずにプラグインだけ
上げる場合は、この要件を満たしているか必ず確認すること。

#### Prometheus

`prom/prometheus`のタグは`v3.14.0`のように先頭に`v`が付く点が他と異なる。
`latest-patch.sh`は`v`無しの数値タグしか扱えないため、比較前後で`v`を付け外しする。

```bash
scripts/list-registry-tags.sh registry-1.docker.io prom/prometheus \
  | sed 's/^v//' | scripts/latest-patch.sh <現在のバージョン(vを除いた形)>
# 結果に`v`を付け直したものがdocker-compose.ymlへ書く値
```

#### 共通

現在のバージョンと「同じメジャー内での最新パッチ」を表にしてユーザーに提示し、
どこまで上げるか確認を取る。既定では**同じメジャー内のパッチ更新のみ**を提案する。

`latest-patch.sh`が「新しいメジャーバージョンが存在する」と警告した場合、それだけで
自動的に候補へは含めない。特にLangfuseやGrafana、Prometheusのメジャーバージョンが変わる
場合は、通常のパッチ/マイナー更新より破壊的変更のリスクが高いことを明示し、該当サービスの
Changelog([Langfuse](https://langfuse.com/changelog)、
[Grafana](https://grafana.com/docs/grafana/latest/release-notes/)、
[Prometheus](https://github.com/prometheus/prometheus/blob/main/CHANGELOG.md))を
一読した上でユーザーが明示的に希望した場合のみ検討する。redis/postgres/プラグインも同様。

ユーザーの明示的な確認を取るまでファイルは書き換えない。

### 3. docker-compose.ymlを更新する

対象イメージのタグ(またはGrafanaプラグインのバージョン)を確認済みの新バージョンに書き換える。
`postgres`は`${POSTGRES_VERSION:-17.11}`のようにデフォルト値部分を書き換える
(環境変数で上書きする運用はしていないため、実質的にこの値がそのまま使われる)。

### 4. 適用する

```bash
cd terraform/local
terraform apply
```

各docker-compose.ymlのハッシュが対応する`terraform_data`(`compose_up`/
`grafana_compose_up`/`prometheus_compose_up`)の`triggers_replace`に含まれているため、
変更を検知して対象サービスのコンテナが`docker compose down` → `up -d --wait`で
作り直される(`--wait`がヘルスチェック通過まで待つ)。

### 5. 反映されたことを確認する

```bash
# Langfuse
docker inspect langfuse-langfuse-web-1 --format '{{.Config.Image}}'
docker inspect langfuse-langfuse-worker-1 --format '{{.Config.Image}}'
docker inspect langfuse-redis-1 --format '{{.Config.Image}}'
docker inspect langfuse-postgres-1 --format '{{.Config.Image}}'
docker inspect langfuse-clickhouse-1 --format '{{.Config.Image}}'
docker ps --format '{{.Names}} {{.Status}}' | grep langfuse

# Grafana
docker inspect grafana-grafana-1 --format '{{.Config.Image}}'
docker ps --format '{{.Names}} {{.Status}}' | grep grafana

# Prometheus
docker inspect prometheus-prometheus-1 --format '{{.Config.Image}}'
docker ps --format '{{.Names}} {{.Status}}' | grep prometheus
```

いずれも新バージョンで`healthy`になっていることを確認する。

### 6. Grafanaダッシュボードへの影響を確認する

Langfuse・Grafana・Prometheusいずれを更新した場合も実施する
(Langfuseの更新はClickHouseスキーマに、Grafana/プラグインの更新はクエリの実行結果に、
Prometheusの更新はPromQLの互換性に影響しうるため)。

`scripts/check-grafana-dashboards.py`が、ClickHouse/Prometheusデータソースを使う
全パネルのクエリを`/api/ds/query`経由で実際に実行し、エラーが無いか確認する
(TestDataパネルは対象外)。

```bash
cd terraform/local
GRAFANA_PASSWORD="$(terraform output -raw grafana_login_password)" \
  python3 ../../.claude/skills/upgrade-services/scripts/check-grafana-dashboards.py \
  "$(terraform output -raw grafana_url)" \
  "$(terraform output -raw grafana_login_user)"
```

`all panel queries succeeded`と出れば完了。
失敗した場合は、失敗したダッシュボード名・パネル名・エラー内容が出力されるので、
対応するSQL/PromQL(`terraform/local/langfuse_grafana.tf`・`langfuse_grafana_extra.tf`・
`prometheus_grafana.tf`)を新しいスキーマ/バージョンに合わせて修正するか、
後述のロールバックを検討する。

さらに、実際にLangfuse本体(`http://localhost:3000`)にログインし、既存のトレースが
問題なく表示されることも目視で確認するとより確実(ログインには
`terraform output -raw langfuse_login_email` / `terraform output -raw langfuse_login_password`
を使う)。

### 7. うまくいかなかった場合のロールバック

`docker-compose.yml`のタグを元のバージョンへ戻し、再度`terraform apply`する。
これでコンテナは元のバージョンに戻る。

ただし、Langfuseの場合はPostgres/ClickHouseのマイグレーションが新バージョンのコンテナ
起動時に**自動的に**実行され、通常は後方互換のないものもある。マイグレーション後に
古いバージョンへ戻すと、スキーマの不整合で正しく動かないことがある。ここはローカル専用の
個人利用環境(README「既知の注意点」参照)なので、最終手段として以下でボリュームを含めて
まっさらにする選択肢もある(トレース履歴は失われる)。

```bash
cd services/langfuse
docker compose down -v
cd ../../terraform/local
terraform apply -replace=terraform_data.compose_up
```

Grafana・Prometheusはこれよりロールバックの心理的コストが低い。ダッシュボード・
データソース・adminアカウントは全てTerraform管理で再現できるため
(Prometheusはスクレイプしたメトリクス履歴のみが失われる)、うまくいかない場合は
同様にボリュームごと作り直してよい。

```bash
# Grafana
cd services/grafana
docker compose down -v
cd ../../terraform/local
terraform apply -replace=terraform_data.grafana_compose_up

# Prometheus
cd services/prometheus
docker compose down -v
cd ../../terraform/local
terraform apply -replace=terraform_data.prometheus_compose_up
```

### 8. コミットする

変更したdocker-compose.ymlのみを、旧バージョン→新バージョンと検証済みであることが
分かるコミットメッセージでコミットする。
