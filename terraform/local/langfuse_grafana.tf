# LangfuseのトレースデータはClickHouse(services/langfuse、events_coreテーブル)に
# 保存されている。Grafana組み込みのTestDataとは別に、実データを可視化するための
# ClickHouseデータソースとダッシュボードをここで管理する(services/grafana/
# docker-compose.ymlのGF_INSTALL_PLUGINSでgrafana-clickhouse-datasourceを導入)。
#
# 接続情報(host.docker.internal:8123、langfuse.tfのrandom_password.clickhouse)は
# Langfuse自身のClickHouseインスタンスをそのまま参照している。

resource "grafana_data_source" "langfuse_clickhouse" {
  type = "grafana-clickhouse-datasource"
  name = "Langfuse (ClickHouse)"

  json_data_encoded = jsonencode({
    host            = "host.docker.internal"
    port            = 8123
    protocol        = "http"
    secure          = false
    username        = "clickhouse"
    defaultDatabase = "default"
  })

  secure_json_data_encoded = jsonencode({
    password = random_password.clickhouse.result
  })

  depends_on = [
    null_resource.grafana_compose_up,
    null_resource.compose_up,
  ]
}

# LangfuseのHomeダッシュボード(Traces/Model costs/Observations by time/Model Usage/
# 各種latency percentiles)相当をClickHouseへの生SQLで再現したもの。
# クエリはevents_core(Langfuse v4のOTel統合スパンテーブル)に対して直接発行しており、
# 実際にLangfuse UI(http://localhost:3000)に表示される数値と一致することを
# `/api/ds/query`経由で確認済み。Scores関連パネル(このプロジェクトではデータ無し)は
# 対応するデータが無いため実装していない。
locals {
  ch_ds = { type = "grafana-clickhouse-datasource", uid = grafana_data_source.langfuse_clickhouse.uid }

  ch_duration_expr = "dateDiff('millisecond', start_time, end_time)"

  q_traces = <<-SQL
    SELECT count() AS traces FROM events_core
    WHERE is_deleted = 0 AND is_app_root = 1 AND $__timeFilter(start_time)
  SQL

  q_total_cost = <<-SQL
    SELECT sum(total_cost) AS total_cost FROM events_core
    WHERE is_deleted = 0 AND type = 'GENERATION' AND $__timeFilter(start_time)
  SQL

  q_observations = <<-SQL
    SELECT count() AS observations FROM events_core
    WHERE is_deleted = 0 AND $__timeFilter(start_time)
  SQL

  q_observations_by_time = <<-SQL
    SELECT toStartOfInterval(start_time, INTERVAL 1 hour) AS time, count() AS observations
    FROM events_core
    WHERE is_deleted = 0 AND $__timeFilter(start_time)
    GROUP BY time ORDER BY time
  SQL

  q_cost_by_time = <<-SQL
    SELECT toStartOfInterval(start_time, INTERVAL 1 hour) AS time, sum(total_cost) AS cost
    FROM events_core
    WHERE is_deleted = 0 AND type = 'GENERATION' AND $__timeFilter(start_time)
    GROUP BY time ORDER BY time
  SQL

  q_model_usage = <<-SQL
    SELECT provided_model_name AS model, sum(usage_details['total']) AS tokens,
      sum(total_cost) AS cost_usd
    FROM events_core
    WHERE is_deleted = 0 AND type = 'GENERATION' AND $__timeFilter(start_time)
    GROUP BY model ORDER BY cost_usd DESC
  SQL

  q_trace_latency = <<-SQL
    SELECT trace_name,
      quantile(0.5)(${local.ch_duration_expr}) AS p50,
      quantile(0.9)(${local.ch_duration_expr}) AS p90,
      quantile(0.95)(${local.ch_duration_expr}) AS p95,
      quantile(0.99)(${local.ch_duration_expr}) AS p99
    FROM events_core
    WHERE is_deleted = 0 AND is_app_root = 1 AND $__timeFilter(start_time)
    GROUP BY trace_name ORDER BY p95 DESC
  SQL

  q_generation_latency = <<-SQL
    SELECT name,
      quantile(0.5)(${local.ch_duration_expr}) AS p50,
      quantile(0.9)(${local.ch_duration_expr}) AS p90,
      quantile(0.95)(${local.ch_duration_expr}) AS p95,
      quantile(0.99)(${local.ch_duration_expr}) AS p99
    FROM events_core
    WHERE is_deleted = 0 AND type = 'GENERATION' AND $__timeFilter(start_time)
    GROUP BY name ORDER BY p95 DESC
  SQL

  q_observation_latency = <<-SQL
    SELECT type, name,
      quantile(0.5)(${local.ch_duration_expr}) AS p50,
      quantile(0.9)(${local.ch_duration_expr}) AS p90,
      quantile(0.95)(${local.ch_duration_expr}) AS p95,
      quantile(0.99)(${local.ch_duration_expr}) AS p99
    FROM events_core
    WHERE is_deleted = 0 AND $__timeFilter(start_time)
    GROUP BY type, name ORDER BY type, p95 DESC
  SQL
}

resource "grafana_dashboard" "langfuse_overview" {
  folder = grafana_folder.local.uid

  config_json = jsonencode({
    title         = "Langfuse Overview"
    uid           = "langfuse-overview"
    schemaVersion = 39
    time          = { from = "now-1d", to = "now" }
    panels = [
      # --- 上段: サマリー統計(Langfuse Homeの Traces / Model costs / Scores 相当) ---
      {
        id         = 1
        title      = "Traces"
        type       = "stat"
        gridPos    = { h = 4, w = 8, x = 0, y = 0 }
        datasource = local.ch_ds
        targets = [{
          refId      = "A"
          editorType = "sql"
          format     = 1
          rawSql     = local.q_traces
        }]
      },
      {
        id          = 2
        title       = "Total Cost"
        type        = "stat"
        gridPos     = { h = 4, w = 8, x = 8, y = 0 }
        datasource  = local.ch_ds
        fieldConfig = { defaults = { unit = "currencyUSD" } }
        targets = [{
          refId      = "A"
          editorType = "sql"
          format     = 1
          rawSql     = local.q_total_cost
        }]
      },
      {
        id         = 3
        title      = "Observations"
        type       = "stat"
        gridPos    = { h = 4, w = 8, x = 16, y = 0 }
        datasource = local.ch_ds
        targets = [{
          refId      = "A"
          editorType = "sql"
          format     = 1
          rawSql     = local.q_observations
        }]
      },
      # --- 中段: 時系列(Langfuse Homeの Observations by time / Model Usage 相当) ---
      {
        id         = 4
        title      = "Observations by time"
        type       = "timeseries"
        gridPos    = { h = 8, w = 12, x = 0, y = 4 }
        datasource = local.ch_ds
        targets = [{
          refId      = "A"
          editorType = "sql"
          format     = 0
          rawSql     = local.q_observations_by_time
        }]
      },
      {
        id          = 5
        title       = "Cost by time"
        type        = "timeseries"
        gridPos     = { h = 8, w = 12, x = 12, y = 4 }
        datasource  = local.ch_ds
        fieldConfig = { defaults = { unit = "currencyUSD" } }
        targets = [{
          refId      = "A"
          editorType = "sql"
          format     = 0
          rawSql     = local.q_cost_by_time
        }]
      },
      # --- 下段: テーブル(Langfuse Homeの Model costs / *latency percentiles 相当) ---
      {
        id         = 6
        title      = "Model usage"
        type       = "table"
        gridPos    = { h = 8, w = 12, x = 0, y = 12 }
        datasource = local.ch_ds
        targets = [{
          refId      = "A"
          editorType = "sql"
          format     = 1
          rawSql     = local.q_model_usage
        }]
      },
      {
        id         = 7
        title      = "Trace latency percentiles (ms)"
        type       = "table"
        gridPos    = { h = 8, w = 12, x = 12, y = 12 }
        datasource = local.ch_ds
        targets = [{
          refId      = "A"
          editorType = "sql"
          format     = 1
          rawSql     = local.q_trace_latency
        }]
      },
      {
        id         = 8
        title      = "Generation latency percentiles (ms)"
        type       = "table"
        gridPos    = { h = 8, w = 12, x = 0, y = 20 }
        datasource = local.ch_ds
        targets = [{
          refId      = "A"
          editorType = "sql"
          format     = 1
          rawSql     = local.q_generation_latency
        }]
      },
      {
        id         = 9
        title      = "Observation latency percentiles (ms)"
        type       = "table"
        gridPos    = { h = 8, w = 12, x = 12, y = 20 }
        datasource = local.ch_ds
        targets = [{
          refId      = "A"
          editorType = "sql"
          format     = 1
          rawSql     = local.q_observation_latency
        }]
      },
    ]
  })

  depends_on = [grafana_data_source.langfuse_clickhouse]
}
