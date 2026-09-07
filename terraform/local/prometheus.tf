# Prometheusのdocker-compose.yml/prometheus.ymlの実体は../../prometheus
# (このディレクトリではない)に置く。scrape対象の定義に秘密情報を含まないため
# langfuse/grafanaと異なり.envの生成は不要で、docker-compose.ymlと合わせて
# 直接コミットしている。

locals {
  prometheus_dir = "${path.module}/../../prometheus"
  # ホスト側ポートは9095(9090はlangfuse/minioが既に使用しているため)。
  # コンテナ内部は既定の9090のまま(prometheus/docker-compose.yml参照)。
  prometheus_url = "http://localhost:9095"
}

# docker-compose.ymlの実体はTerraform化せず、`docker compose up`を呼ぶだけの
# null_resourceにする(langfuse/grafanaと同じ方針)。
resource "null_resource" "prometheus_compose_up" {
  triggers = {
    compose_sha256    = filesha256("${local.prometheus_dir}/docker-compose.yml")
    prometheus_sha256 = filesha256("${local.prometheus_dir}/prometheus.yml")
    # destroy時のprovisionerはself経由でしか値を参照できないためtriggers経由で渡す
    prometheus_dir = local.prometheus_dir
  }

  provisioner "local-exec" {
    working_dir = local.prometheus_dir
    command     = "docker compose up -d --wait"
  }

  provisioner "local-exec" {
    when        = destroy
    working_dir = self.triggers.prometheus_dir
    command     = "docker compose down"
  }
}

# GrafanaコンテナからはHost経由(host.docker.internal)でPrometheusの
# 公開ポート(127.0.0.1:9095)へアクセスする(grafana/docker-compose.ymlの
# extra_hosts参照)。accessは既定のproxy(Grafanaバックエンド経由)のまま。
resource "grafana_data_source" "prometheus" {
  type = "prometheus"
  name = "Prometheus"
  url  = "http://host.docker.internal:9095"

  json_data_encoded = jsonencode({
    httpMethod = "POST"
  })

  depends_on = [
    null_resource.grafana_compose_up,
    null_resource.prometheus_compose_up,
  ]
}
