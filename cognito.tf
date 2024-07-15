resource "aws_cognito_user_pool" "main" {
  name                       = local.name
  auto_verified_attributes   = ["email"]
  username_attributes        = ["email"]
  mfa_configuration          = "OPTIONAL"
  email_verification_subject = var.cognito_email_verification_subject
  email_verification_message = var.cognito_email_verification_message

  email_configuration {
    from_email_address     = local.cognito_from
    reply_to_email_address = local.cognito_reply
    source_arn             = var.cognito_source_arn
    email_sending_account  = "DEVELOPER"
  }
  software_token_mfa_configuration {
    enabled = true
  }
  lambda_config {
    pre_sign_up       = aws_lambda_function.pre_sign_up.arn
    post_confirmation = aws_lambda_function.post_confirmation.arn
  }
  tags = local.tags
}

resource "aws_lambda_permission" "post_confirmation" {
  statement_id  = "AllowExecutionFromCognito-post_confirmation"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.post_confirmation.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
}
resource "aws_lambda_permission" "pre_sign_up" {
  statement_id  = "AllowExecutionFromCognito-pre_sign_up"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.pre_sign_up.function_name
  principal     = "cognito-idp.amazonaws.com"
  source_arn    = aws_cognito_user_pool.main.arn
  depends_on = [
    aws_lambda_permission.post_confirmation
  ]
}

resource "random_password" "cognito_admin" {
  length           = 12
  special          = true
  override_special = "_+.-"
  min_numeric      = 1
  min_special      = 1
  min_upper        = 1
}

resource "aws_cognito_user_pool_domain" "main" {
  domain          = var.cognito_dns
  certificate_arn = aws_acm_certificate_validation.cognito.certificate_arn
  user_pool_id    = aws_cognito_user_pool.main.id
  depends_on      = [aws_route53_record.alb]
}

resource "aws_cognito_user_pool_client" "main" {
  name                                 = local.name
  generate_secret                      = true
  supported_identity_providers         = ["COGNITO"]
  user_pool_id                         = aws_cognito_user_pool.main.id
  explicit_auth_flows                  = ["ALLOW_ADMIN_USER_PASSWORD_AUTH", "ALLOW_USER_PASSWORD_AUTH", "ALLOW_USER_SRP_AUTH", "ALLOW_REFRESH_TOKEN_AUTH"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_scopes                 = ["openid", "aws.cognito.signin.user.admin"]
  logout_urls                          = ["https://${local.dns}${var.context_path}/logout.html", "https://${local.dns}/", "https://${local.dns}/logout.html"]
  callback_urls                        = ["https://${local.dns}/oauth2/idpresponse"]
  default_redirect_uri                 = "https://${local.dns}/oauth2/idpresponse"
  read_attributes                      = ["name", "email"]
  write_attributes                     = ["name", "email"]
}


resource "null_resource" "admin_create_user" {
  provisioner "local-exec" {
    command = "aws cognito-idp admin-create-user --region ${var.region} --profile ${var.profile} --user-pool-id ${aws_cognito_user_pool.main.id} --username ${var.cognito_admin} --user-attributes Name=email,Value=${var.cognito_admin} Name=email_verified,Value=true --temporary-password \"${random_password.cognito_admin.result}\""
  }

  triggers = {
    rerun_every_time = aws_cognito_user_pool.main.id
  }
}

data "external" "coognito_user" {
  depends_on = [null_resource.admin_create_user]
  program    = ["bash", "${path.root}/cognito_admin-get-user.sh"]
  query = {
    user_pool = aws_cognito_user_pool.main.id
    profile   = var.profile
    username  = var.cognito_admin
  }
}

locals {
  cognito_admin_sub = data.external.coognito_user.result.username
}
