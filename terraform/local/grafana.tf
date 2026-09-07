# Grafanaのdocker-compose.yml/.envの実体は../../grafana(このディレクトリでは
# ない)に置く。admin初期パスワードを乱数で生成し.envへ書き出す方針はlangfuse.tfと同じ。

locals {
  grafana_dir = "${path.module}/../../grafana"
  grafana_url = "http://localhost:3001"
}

resource "random_password" "grafana_admin" {
  length  = 32
  special = false
}

resource "local_sensitive_file" "grafana_env" {
  filename        = "${local.grafana_dir}/.env"
  file_permission = "0600"

  content = <<-EOT
    GF_SECURITY_ADMIN_USER=${var.grafana_admin_user}
    GF_SECURITY_ADMIN_PASSWORD=${random_password.grafana_admin.result}
  EOT
}

# docker-compose.ymlの実体はTerraform化せず、.env生成後に`docker compose up`を
# 呼ぶだけのnull_resourceにする(langfuse側と同じ方針)。`--wait`がhealthcheck
# 通過(GrafanaのREST APIが応答可能になるまで)を待つため、これ以降のgrafana
# providerリソースはAPIに安全にアクセスできる。
resource "null_resource" "grafana_compose_up" {
  triggers = {
    env_sha256     = local_sensitive_file.grafana_env.content_sha256
    compose_sha256 = filesha256("${local.grafana_dir}/docker-compose.yml")
    # destroy時のprovisionerはself経由でしか値を参照できないためtriggers経由で渡す
    grafana_dir = local.grafana_dir
  }

  provisioner "local-exec" {
    working_dir = local.grafana_dir
    command     = "docker compose up -d --wait"
  }

  provisioner "local-exec" {
    when        = destroy
    working_dir = self.triggers.grafana_dir
    command     = "docker compose down"
  }

  depends_on = [local_sensitive_file.grafana_env]
}

# authはbasic認証(admin:生成済みパスワード)。grafana_userリソース(組織を
# 跨いだユーザー管理)はAPIキー/サービスアカウントトークンでは動作せず
# basic認証必須のため、この方式に統一している。
provider "grafana" {
  url  = local.grafana_url
  auth = "${var.grafana_admin_user}:${random_password.grafana_admin.result}"
}

resource "grafana_folder" "local" {
  title = "Local"

  depends_on = [null_resource.grafana_compose_up]
}

# Grafana組み込みのTestDataデータソース。terraform管理のサンプルとして
# welcomeダッシュボードから参照している(実データはprometheus.tfの
# grafana_data_source.prometheus参照)。
resource "grafana_data_source" "testdata" {
  type = "grafana-testdata-datasource"
  name = "TestData"

  depends_on = [null_resource.grafana_compose_up]
}

# grafana_data_source/grafana_folder同様、terraform管理下にあることを示す
# サンプルダッシュボード。TestDataソースのrandom_walkシナリオを表示するだけ。
resource "grafana_dashboard" "welcome" {
  folder = grafana_folder.local.uid

  config_json = jsonencode({
    title         = "Welcome"
    uid           = "local-welcome"
    schemaVersion = 39
    panels = [
      {
        id    = 1
        title = "Random Walk (TestData)"
        type  = "timeseries"
        datasource = {
          type = "grafana-testdata-datasource"
          uid  = grafana_data_source.testdata.uid
        }
        targets = [
          {
            scenarioId = "random_walk"
            refId      = "A"
          }
        ]
        gridPos = { h = 8, w = 24, x = 0, y = 0 }
      }
    ]
  })

  depends_on = [null_resource.grafana_compose_up]
}
