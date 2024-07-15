locals {
  name                 = "${var.application}-${var.environment}"
  cognito_dns          = "${var.cognito_dns_prefix}.${local.dns}"
  dns                  = var.dns == "" ? "${var.application}.${var.dns_zone}" : var.dns
  cognito_reply        = var.cognito_reply == "" ? "NO_REPLY<no-reply@${local.dns}>" : var.cognito_reply
  cognito_from         = var.cognito_from == "" ? "${title(var.application)} <${var.application}@${local.dns}>" : var.cognito_from
  cognito_email_filter = var.cognito_email_filter == "" ? ".*@${local.dns}" : var.cognito_email_filter
  cognito_admin        = var.cognito_admin == "" ? "admin@${local.dns}" : var.cognito_admin
  cognito_source_arn   = var.cognito_source_arn == "" ? "arn:aws:ses:${var.region}:${data.aws_caller_identity.current.account_id}:identity/${local.cognito_admin}" : var.cognito_source_arn

  tags = {
    "Name" : local.name
    "APPLICATION" : var.application
    "ENVIRONMENT" : var.environment
    "MANAGED_BY" : "terraform"
  }
  container_definition = {
    ligoj_version  = var.ligoj_version
    cognito_dns    = var.cognito_dns
    dns            = local.dns
    cognito_client = aws_cognito_user_pool_client.main.id
    repository     = var.docker_repository
    region         = var.region
    environment    = var.environment
  }
}

data "aws_caller_identity" "current" {}
