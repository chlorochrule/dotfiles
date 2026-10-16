# Generates docker-compose.yml's CHANGEME values.

locals {
  langfuse_dir = "${path.module}/../../services/langfuse"
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

# special=false: symbols break .env parsing and shell interpolation.
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
    TELEMETRY_ENABLED=false
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

resource "terraform_data" "compose_up" {
  triggers_replace = {
    env_sha256     = local_sensitive_file.env.content_sha256
    compose_sha256 = filesha256("${local.langfuse_dir}/docker-compose.yml")
    # A changed users.d file needs a container restart.
    clickhouse_users_xml_sha256 = local_sensitive_file.clickhouse_grafana_ro_users_xml.content_sha256
    # destroy-time provisioners can only read `self`, not top-level locals.
    langfuse_dir = local.langfuse_dir
  }

  provisioner "local-exec" {
    working_dir = local.langfuse_dir
    command     = "docker compose up -d --wait"
  }

  provisioner "local-exec" {
    when        = destroy
    working_dir = self.triggers_replace.langfuse_dir
    command     = "docker compose down"
  }

  depends_on = [
    local_sensitive_file.env,
    local_sensitive_file.clickhouse_grafana_ro_users_xml,
  ]
}
