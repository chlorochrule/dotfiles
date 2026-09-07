output "langfuse_url" {
  value = "http://localhost:3000"
}

output "login_email" {
  value = var.init_user_email
}

output "login_password" {
  value     = random_password.init_user.result
  sensitive = true
}

output "public_key" {
  value = "pk-lf-${random_id.project_public_key.hex}"
}

output "secret_key" {
  value     = "sk-lf-${random_id.project_secret_key.hex}"
  sensitive = true
}
