# macOSホスト本体(node_exporter、hosts/MacBookPro-minami/darwin.nix参照)のメトリクスを
# 見るためのGrafanaダッシュボード。データソースはprometheus.tfのgrafana_data_source.prometheus。
#
# darwin版node_exporterはLinux版と収集項目が異なる(/procが無いためnode_cpu_seconds_totalの
# modeはidle/user/system/niceのみ、node_memory_*はLinuxのavailable/buffers/cached相当が無く
# wired/active/compressed/free/purgeable等のmacOS固有フィールドになる等)。ここでのPromQLは
# 127.0.0.1:9100の実際のメトリクス出力を確認したうえで書いている。

locals {
  prom_ds = { type = "prometheus", uid = grafana_data_source.prometheus.uid }

  pq_cpu_usage_percent = <<-EOT
    100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
  EOT

  pq_memory_used_percent = <<-EOT
    (node_memory_wired_bytes + node_memory_active_bytes + node_memory_compressed_bytes)
      / node_memory_total_bytes * 100
  EOT

  # /と/nixは同一APFSコンテナ内のボリュームのため使用率はほぼ同じ値になるが、
  # 将来別ディスクに分かれた場合にも対応できるようmountpointでフィルタしている。
  pq_filesystem_used_percent = <<-EOT
    100 * (1 - (
      node_filesystem_avail_bytes{mountpoint=~"^(/|/nix)$"}
        / node_filesystem_size_bytes{mountpoint=~"^(/|/nix)$"}
    ))
  EOT
}

resource "grafana_dashboard" "node_exporter" {
  folder = grafana_folder.local.uid

  config_json = jsonencode({
    title         = "macOS Host (node_exporter)"
    uid           = "node-exporter-macos"
    schemaVersion = 39
    time          = { from = "now-6h", to = "now" }
    panels = [
      # --- 上段: サマリー統計 ---
      {
        id          = 1
        title       = "Uptime"
        type        = "stat"
        gridPos     = { h = 4, w = 6, x = 0, y = 0 }
        datasource  = local.prom_ds
        fieldConfig = { defaults = { unit = "s" } }
        targets = [{
          refId   = "A"
          expr    = "time() - node_boot_time_seconds"
          instant = true
        }]
      },
      {
        id          = 2
        title       = "CPU Usage"
        type        = "stat"
        gridPos     = { h = 4, w = 6, x = 6, y = 0 }
        datasource  = local.prom_ds
        fieldConfig = { defaults = { unit = "percent", min = 0, max = 100 } }
        targets = [{
          refId   = "A"
          expr    = local.pq_cpu_usage_percent
          instant = true
        }]
      },
      {
        id          = 3
        title       = "Memory Usage"
        type        = "stat"
        gridPos     = { h = 4, w = 6, x = 12, y = 0 }
        datasource  = local.prom_ds
        fieldConfig = { defaults = { unit = "percent", min = 0, max = 100 } }
        targets = [{
          refId   = "A"
          expr    = local.pq_memory_used_percent
          instant = true
        }]
      },
      {
        id          = 4
        title       = "Battery"
        type        = "stat"
        gridPos     = { h = 4, w = 6, x = 18, y = 0 }
        datasource  = local.prom_ds
        fieldConfig = { defaults = { unit = "percent", min = 0, max = 100 } }
        targets = [{
          refId   = "A"
          expr    = "node_power_supply_current_capacity"
          instant = true
        }]
      },
      # --- 中段: 時系列 ---
      {
        id         = 5
        title      = "Load average"
        type       = "timeseries"
        gridPos    = { h = 8, w = 12, x = 0, y = 4 }
        datasource = local.prom_ds
        targets = [
          { refId = "A", expr = "node_load1", legendFormat = "1m" },
          { refId = "B", expr = "node_load5", legendFormat = "5m" },
          { refId = "C", expr = "node_load15", legendFormat = "15m" },
        ]
      },
      {
        id          = 6
        title       = "Memory breakdown"
        type        = "timeseries"
        gridPos     = { h = 8, w = 12, x = 12, y = 4 }
        datasource  = local.prom_ds
        fieldConfig = { defaults = { unit = "bytes", custom = { stacking = { mode = "normal" } } } }
        targets = [
          { refId = "A", expr = "node_memory_wired_bytes", legendFormat = "wired" },
          { refId = "B", expr = "node_memory_active_bytes", legendFormat = "active" },
          { refId = "C", expr = "node_memory_compressed_bytes", legendFormat = "compressed" },
          { refId = "D", expr = "node_memory_free_bytes", legendFormat = "free" },
        ]
      },
      {
        id          = 7
        title       = "CPU usage over time"
        type        = "timeseries"
        gridPos     = { h = 8, w = 12, x = 0, y = 12 }
        datasource  = local.prom_ds
        fieldConfig = { defaults = { unit = "percent", min = 0, max = 100 } }
        targets = [{
          refId        = "A"
          expr         = local.pq_cpu_usage_percent
          legendFormat = "cpu usage"
        }]
      },
      {
        id          = 8
        title       = "Disk I/O (disk0)"
        type        = "timeseries"
        gridPos     = { h = 8, w = 12, x = 12, y = 12 }
        datasource  = local.prom_ds
        fieldConfig = { defaults = { unit = "Bps" } }
        targets = [
          { refId = "A", expr = "rate(node_disk_read_bytes_total[5m])", legendFormat = "read" },
          { refId = "B", expr = "rate(node_disk_written_bytes_total[5m])", legendFormat = "write" },
        ]
      },
      # --- 下段: ネットワーク/ファイルシステム ---
      {
        id          = 9
        title       = "Network I/O (en0)"
        type        = "timeseries"
        gridPos     = { h = 8, w = 12, x = 0, y = 20 }
        datasource  = local.prom_ds
        fieldConfig = { defaults = { unit = "Bps" } }
        targets = [
          {
            refId        = "A"
            expr         = "rate(node_network_receive_bytes_total{device=\"en0\"}[5m])"
            legendFormat = "receive"
          },
          {
            refId        = "B"
            expr         = "rate(node_network_transmit_bytes_total{device=\"en0\"}[5m])"
            legendFormat = "transmit"
          },
        ]
      },
      {
        id          = 10
        title       = "Filesystem usage"
        type        = "table"
        gridPos     = { h = 8, w = 12, x = 12, y = 20 }
        datasource  = local.prom_ds
        fieldConfig = { defaults = { unit = "percent" } }
        targets = [{
          refId   = "A"
          expr    = local.pq_filesystem_used_percent
          instant = true
          format  = "table"
        }]
        # device/fstype/instance/job/Time列はノイズなので隠し、mountpoint/使用率だけを見せる
        transformations = [{
          id = "organize"
          options = {
            excludeByName = { Time = true, device = true, fstype = true, instance = true, job = true }
            renameByName  = { Value = "used %" }
          }
        }]
      },
    ]
  })

  depends_on = [grafana_data_source.prometheus]
}
