# Variables
variable "application" {
  description = "Application name for tags and prefix resource naming"
  default     = "ligoj"
}
variable "environment" {
  description = "The name of the service. Used to compute the resource naming"
  default     = "prod"
}
variable "region" {
  default = "eu-west-1"
}
variable "profile" {
  type    = string
  default = null
}

variable "account" {
  type = string
}

variable "expiration" {
  default = 14
}

variable "container_protocol" {
  default = "HTTP"
}
variable "dns" {
  type = string
}
variable "dns_zone" {
  type = string
}
variable "cognito_dns" {
  type = string
}
variable "desired_count" {
  default = 1
}
variable "cpu" {
  default = 2
}
variable "ram" {
  default = 8192
}
variable "container_route_private" {
  default = {
    "ligoj-ui" = "*"
  }
}
variable "container_route_public" {
  default = {
    "ligoj-ui" = ["/themes/*", "/logout.html", "/favicon.ico"]
  }
}
variable "container_port" {
  default = {
    "ligoj-ui" = 8080
  }
}
variable "container_health" {
  default = {
    "ligoj-ui" = "/favicon.ico"
  }
}
variable "container_route_query" {
  default = {
    "ligoj-ui" = "api-key:*"
  }
}
variable "container_route_header" {
  default = {
    "ligoj-ui" = "x-api-key:*"
  }
}

variable "context_path" {
  default = ""
}
variable "cidr" {
  default = "10.0.0.0/16"
}
variable "nb_subnets" {
  default = 3
}
variable "cidr_newbits" {
  default = 8
}

variable "cognito_email_verification_subject" {
  default = "[LIGOJ] Verification code"
}
variable "cognito_email_verification_message" {
  default = "Your verification code is {####}"
}
variable "cognito_reply" {
  default = ""
}
variable "cognito_source_arn" {
  type = string
}
variable "cognito_from" {
  default = ""
}
variable "cognito_admin" {
  default = ""
}
variable "cognito_dns_prefix" {
  default = "login"
}
variable "ligoj_plugins" {
  default = "plugin-id,plugin-id-cognito"
}
variable "ligoj_sign_up_role" {
  default = "USER"
}
variable "ligoj_sign_up_project" {
  default = "true"
}
variable "engine_version" {
  # select AURORA_VERSION();
  # aws rds describe-db-clusters --db-cluster-identifier ligoj-prod
  # aws rds describe-orderable-db-instance-options --engine aurora-mysql --db-instance-class db.serverless \
  #     --region eu-west-3 --query 'OrderableDBInstanceOptions[].[EngineVersion]' --output text --profile kloudy-website
  default = "8.0.mysql_aurora.3.02.0" # Serverless v2
  #default = "5.7.mysql_aurora.2.07.1" # Serverless v1
  #default = "5.7" # RDS
}

variable "ligoj_version" {
  default = "3.2.3"
}
variable "enabled" {
  default = true
}
variable "db_user" {
  default = "ligoj"
}
variable "db_master_user" {
  default = "admin"
}
variable "storage_encrypted" {
  default = true
}

variable "cognito_email_filter" {
  default = "(.*@kloudy.io)"
}

variable "cognito_email_filter_message" {
  default = "You are not allowed to use this service"
}

variable "ligoj_sign_up_subscription" {
  default = [{ node = "service:prov:aws:sandbox", mode = "create", parameters = [] }]
}

variable "aurora_min_capacity" {
  default = 0.5
}
variable "aurora_max_capacity" {
  default = 128
}
variable "docker_repository" {
  default = ""
}
