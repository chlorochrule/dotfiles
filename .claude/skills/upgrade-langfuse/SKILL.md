---
name: upgrade-langfuse
description: >-
  dotfilesリポジトリ(services/langfuse/docker-compose.yml)でバージョンを明示的に固定している
  Langfuse本体(langfuse-web/langfuse-worker)・redis・postgres・clickhouseのイメージタグを上げる手順。
  「Langfuseを最新にして」「langfuse-workerのバージョン上げて」「redis/postgres/clickhouseのイメージ更新して」
  のように名前が出た場合はもちろん、このリポジトリで作業中に「バージョン上げて」「更新して」
  「アップグレードして」と言われた場合も、対象がこれらのサービスなら必ず使うこと。
  GrafanaダッシュボードがLangfuseのClickHouseスキーマ(events_core)に生SQLで直接依存しており、
  docker-compose.ymlのタグを書き換えるだけでは検証不足になるため、素朴な書き換えではなく
  このスキルの確認・適用・検証・ロールバック手順に従う。
---

# Langfuseのバージョンを上げる

## 前提

- `services/langfuse/docker-compose.yml`では、上流(langfuse/langfuse公式リポジトリ)が
  メジャーバージョンのみの移動タグ(`:4`/`:7`/`:17`)で追従させている4つのイメージ
  (`langfuse-worker`、`langfuse`、`redis`、`postgres`)を、導入時点の実バージョンへ明示的に
  固定している。理由はdocker-compose.yml先頭のコメントを参照。
- `clickhouse`も同じ理由で固定している。ただし上流はマイナー系列の移動タグ(`:25.12`)で
  指定しており、Langfuseとの組み合わせで検証されているのはその系列なので、
  **系列は上流のdocker-compose.ymlに合わせ、系列内の最新パッチに固定する**方針にしている。
- `minio`・Grafana・Prometheusのバージョンはこのスキルの対象外(別の考慮が必要)。
- 作業前に`git status`でこのリポジトリがクリーンであることを確認する。無関係な変更が
  混ざっているとバージョン更新のコミットが追いにくくなる。

## 手順

### 1. 現在のバージョンを確認する

`services/langfuse/docker-compose.yml`の5箇所のimageタグ
(`langfuse-worker`、`langfuse`、`redis`、`postgres:${POSTGRES_VERSION:-...}`、`clickhouse`)を読む。
`langfuse-worker`と`langfuse`は同じLangfuseアプリケーションのサーバー/ワーカーなので、
常に同じバージョンに揃えること(片方だけ上げると動作しない)。

### 2. 最新版を確認する

`scripts/list-registry-tags.sh`でDocker Hub(langfuseは`docker.langfuse.com`経由のミラー)から
タグ一覧を取得し、`scripts/latest-patch.sh`に現在のバージョンを渡して
「同じメジャーバージョン内での最新パッチ」を求める。

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

現在のバージョンと「同じメジャー内での最新パッチ」を表にしてユーザーに提示し、
どこまで上げるか確認を取る。既定では**同じメジャー内のパッチ更新のみ**を提案する。

`latest-patch.sh`が「新しいメジャーバージョンが存在する」と警告した場合、それだけで
自動的に候補へは含めない。特にLangfuseのメジャーバージョンが変わる場合は、通常の
パッチ/マイナー更新より破壊的変更(ClickHouseスキーマ変更やマイグレーション)のリスクが
高いことを明示し、Langfuseの[Changelog](https://langfuse.com/changelog)を一読した上で
ユーザーが明示的に希望した場合のみ検討する。redis/postgresも同様。

ユーザーの明示的な確認を取るまでファイルは書き換えない。

### 3. docker-compose.ymlを更新する

対象イメージのタグを確認済みの新バージョンに書き換える。
`postgres`は`${POSTGRES_VERSION:-17.11}`のようにデフォルト値部分を書き換える
(環境変数で上書きする運用はしていないため、実質的にこの値がそのまま使われる)。

### 4. 適用する

```bash
cd terraform/local
terraform apply
```

`docker-compose.yml`のハッシュが`null_resource`の`triggers`に含まれているため、
変更を検知して対象サービスのコンテナが`docker compose down` → `up -d --wait`で
作り直される(`--wait`がヘルスチェック通過まで待つ)。

### 5. 反映されたことを確認する

```bash
docker inspect langfuse-langfuse-web-1 --format '{{.Config.Image}}'
docker inspect langfuse-langfuse-worker-1 --format '{{.Config.Image}}'
docker inspect langfuse-redis-1 --format '{{.Config.Image}}'
docker inspect langfuse-postgres-1 --format '{{.Config.Image}}'
docker inspect langfuse-clickhouse-1 --format '{{.Config.Image}}'
docker ps --format '{{.Names}} {{.Status}}' | grep langfuse
```

いずれも新バージョンで`healthy`になっていることを確認する。

### 6. Grafanaダッシュボードへの影響を確認する

`scripts/check-grafana-dashboards.py`が、GrafanaのClickHouseデータソースを使う全パネルの
クエリを`/api/ds/query`経由で実際に実行し、エラーが無いか確認する
(Prometheus/TestDataパネルは対象外)。

```bash
cd terraform/local
python3 ../../.claude/skills/upgrade-langfuse/scripts/check-grafana-dashboards.py \
  "$(terraform output -raw grafana_url)" \
  "$(terraform output -raw grafana_login_user)" \
  "$(terraform output -raw grafana_login_password)"
```

`all ClickHouse panel queries succeeded`と出れば完了。
失敗した場合は、失敗したダッシュボード名・パネル名・エラー内容が出力されるので、
対応するSQL(`terraform/local/langfuse_grafana.tf`・`langfuse_grafana_extra.tf`)を
Langfuseの新しいClickHouseスキーマに合わせて修正するか、後述のロールバックを検討する。

さらに、実際にLangfuse本体(`http://localhost:3000`)にログインし、既存のトレースが
問題なく表示されることも目視で確認するとより確実(ログインには
`terraform output -raw langfuse_login_email` / `terraform output -raw langfuse_login_password`
を使う)。

### 7. うまくいかなかった場合のロールバック

`docker-compose.yml`のタグを元のバージョンへ戻し、再度`terraform apply`する。
これでコンテナは元のバージョンに戻る。

ただし、Postgres/ClickHouseのマイグレーションは新バージョンのコンテナ起動時に
**自動的に**実行され、通常は後方互換のないものもある。マイグレーション後に古いバージョンへ
戻すと、スキーマの不整合で正しく動かないことがある。ここはローカル専用の個人利用環境
(README「既知の注意点」参照)なので、最終手段として以下でボリュームを含めて
まっさらにする選択肢もある(トレース履歴は失われる)。

```bash
cd services/langfuse
docker compose down -v
cd ../../terraform/local
terraform apply -replace=null_resource.compose_up
```

### 8. コミットする

`services/langfuse/docker-compose.yml`の変更のみを、旧バージョン→新バージョンと
Grafana検証済みであることが分かるコミットメッセージでコミットする。
