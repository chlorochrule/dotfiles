# Grafanaのadmin初期ログインユーザー名。秘密情報ではないため
# コミット対象のデフォルト値で問題ない(パスワードはrandom_password.grafana_adminで生成)。

variable "grafana_admin_user" {
  type    = string
  default = "admin"
}
