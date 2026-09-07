# LANGFUSE_INIT_*(headless initialization)で作成する組織/プロジェクト/
# ユーザーの識別子・表示名。秘密情報ではないためコミット対象のデフォルト値で問題ない。
# https://langfuse.com/self-hosting/administration/headless-initialization

variable "init_org_id" {
  type    = string
  default = "claude-code"
}

variable "init_org_name" {
  type    = string
  default = "Claude Code (local)"
}

variable "init_project_id" {
  type    = string
  default = "claude-code"
}

variable "init_project_name" {
  type    = string
  default = "Claude Code"
}

variable "init_user_email" {
  type    = string
  default = "admin@langfuse.local"
}

variable "init_user_name" {
  type    = string
  default = "admin"
}
