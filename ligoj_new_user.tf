resource "aws_secretsmanager_secret" "ligoj_lambda" {
  name                    = "${local.name}-sign_up"
  recovery_window_in_days = 0
  tags                    = local.tags
}

resource "aws_secretsmanager_secret_version" "ligoj_lambda" {
  secret_id      = aws_secretsmanager_secret.ligoj_lambda.id
  secret_string  = jsonencode({ username = local.ligoj_lambda_api_user, key = local.ligoj_lambda_api_token })
  version_stages = ["AWSCURRENT"]
}

# Signup user role assumed by a lambda
resource "random_id" "ligoj_lambda_api_token_name" {
  keepers = {
    id = aws_cognito_user_pool.main.name
  }
  byte_length = 6
}
resource "random_password" "ligoj_lambda_api_token" {
  length      = 32
  special     = false
  min_numeric = 1
  min_upper   = 1
}
data "external" "ligoj_lambda" {
  program = ["bash", "${path.root}/ligoj_new_user.sh"]
  query = {
    rds_arn        = aws_rds_cluster.main[0].arn
    rds_secret_arn = aws_secretsmanager_secret.rds_master.arn
    rds_secret_64  = base64encode(aws_secretsmanager_secret_version.rds_master.secret_string)
    function_name  = local.lambda_data_api_name
    profile        = var.profile
    region         = var.region
    username       = local.ligoj_lambda_api_user
    user_pool      = aws_cognito_user_pool.main.id
    database       = "ligoj"
    api_token_name = "init_${random_id.ligoj_lambda_api_token_name.hex}"
    api_token      = "_plain_${random_password.ligoj_lambda_api_token.result}"
  }
}

# Admin user
resource "random_id" "ligoj_admin_api_token_name" {
  keepers = {
    id = aws_cognito_user_pool.main.name
  }
  byte_length = 6
}
resource "random_password" "ligoj_admin_api_token" {
  length  = 32
  special = false
}
data "external" "ligoj_admin" {
  program = ["bash", "${path.root}/ligoj_new_user.sh"]
  query = {
    rds_arn        = aws_rds_cluster.main[0].arn
    rds_secret_arn = aws_secretsmanager_secret.rds_master.arn
    rds_secret_64  = base64encode(aws_secretsmanager_secret_version.rds_master.secret_string)
    function_name  = local.lambda_data_api_name
    profile        = var.profile
    region         = var.region
    username       = local.cognito_admin_sub
    user_pool      = aws_cognito_user_pool.main.id
    database       = "ligoj"
    api_token_name = "init_${random_id.ligoj_admin_api_token_name.hex}"
    api_token      = "_plain_${random_password.ligoj_admin_api_token.result}"
  }
  depends_on = [data.external.ligoj_lambda]
}

locals {
  ligoj_lambda_secret_arn = aws_secretsmanager_secret.ligoj_lambda.arn
  ligoj_lambda_api_user   = "cognito_sign_up"
  ligoj_lambda_api_token  = data.external.ligoj_lambda.result.api_token
  ligoj_admin_api_token   = data.external.ligoj_admin.result.api_token
}
