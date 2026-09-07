# docker-compose.ymlのCHANGEME項目を乱数で生成する。
# random_id.*.hexは`openssl rand -hex <byte_length>`と同じ16進文字列を返す
# (ENCRYPTION_KEYはAES-256鍵として32byte/64文字が必須)。

locals {
  # docker-compose.yml/.envの実体は../../langfuse(このディレクトリではない)に置く
  langfuse_dir = "${path.module}/../../langfuse"
}

resource "random_id" "salt" {
  byte_length = 32
}

resource "random_id" "encryption_key" {
  byte_length = 32
}

resource "random_id" "nextauth_secret" {
  byte_length = 32
}

# special=falseは.env(dotenv形式)への書き出しやdocker-compose.ymlの
# シェルコマンド展開(redisのcommand:等)で問題になる記号(#, ' 等)を避けるため
resource "random_password" "postgres" {
  length  = 32
  special = false
}

resource "random_password" "clickhouse" {
  length  = 32
  special = false
}

resource "random_password" "redis" {
  length  = 32
  special = false
}

# minio root password / S3アップロード用シークレットは同一のminioインスタンスに
# 対する認証情報なので、docker-compose.yml側の複数の環境変数に同じ値を配る
resource "random_password" "minio" {
  length  = 32
  special = false
}

resource "random_id" "project_public_key" {
  byte_length = 16
}

resource "random_id" "project_secret_key" {
  byte_length = 16
}

resource "random_password" "init_user" {
  length  = 32
  special = false
}

resource "local_sensitive_file" "env" {
  filename        = "${local.langfuse_dir}/.env"
  file_permission = "0600"

  content = <<-EOT
    SALT=${random_id.salt.hex}
    ENCRYPTION_KEY=${random_id.encryption_key.hex}
    NEXTAUTH_SECRET=${random_id.nextauth_secret.hex}
    POSTGRES_PASSWORD=${random_password.postgres.result}
    DATABASE_URL=postgresql://postgres:${random_password.postgres.result}@postgres:5432/postgres
    CLICKHOUSE_PASSWORD=${random_password.clickhouse.result}
    REDIS_AUTH=${random_password.redis.result}
    MINIO_ROOT_PASSWORD=${random_password.minio.result}
    LANGFUSE_S3_EVENT_UPLOAD_SECRET_ACCESS_KEY=${random_password.minio.result}
    LANGFUSE_S3_MEDIA_UPLOAD_SECRET_ACCESS_KEY=${random_password.minio.result}
    LANGFUSE_S3_BATCH_EXPORT_SECRET_ACCESS_KEY=${random_password.minio.result}
    LANGFUSE_INIT_ORG_ID=${var.init_org_id}
    LANGFUSE_INIT_ORG_NAME=${var.init_org_name}
    LANGFUSE_INIT_PROJECT_ID=${var.init_project_id}
    LANGFUSE_INIT_PROJECT_NAME=${var.init_project_name}
    LANGFUSE_INIT_PROJECT_PUBLIC_KEY=pk-lf-${random_id.project_public_key.hex}
    LANGFUSE_INIT_PROJECT_SECRET_KEY=sk-lf-${random_id.project_secret_key.hex}
    LANGFUSE_INIT_USER_EMAIL=${var.init_user_email}
    LANGFUSE_INIT_USER_NAME=${var.init_user_name}
    LANGFUSE_INIT_USER_PASSWORD=${random_password.init_user.result}
  EOT
}

# docker-compose.ymlの実体はTerraform化せず(healthcheck/depends_on込みで
# 上流のdocker-compose.ymlをそのまま追従させたいため)、.env生成後に
# `docker compose up`を呼ぶだけのnull_resourceにする
resource "null_resource" "compose_up" {
  triggers = {
    env_sha256     = local_sensitive_file.env.content_sha256
    compose_sha256 = filesha256("${local.langfuse_dir}/docker-compose.yml")
    # destroy時のprovisionerはself経由でしか値を参照できないためtriggers経由で渡す
    langfuse_dir = local.langfuse_dir
  }

  provisioner "local-exec" {
    working_dir = local.langfuse_dir
    command     = "docker compose up -d --wait"
  }

  provisioner "local-exec" {
    when        = destroy
    working_dir = self.triggers.langfuse_dir
    command     = "docker compose down"
  }

  depends_on = [local_sensitive_file.env]
}
