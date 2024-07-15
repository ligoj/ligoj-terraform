output db_secret_master_arn {
  value = aws_secretsmanager_secret.rds_master.arn
}
output db_secret_tdp_arn {
  value = aws_secretsmanager_secret.rds_tdp.arn
}
output db_arn {
  value = aws_rds_cluster.main[0].arn
}
output cognito_client_id {
  value = aws_cognito_user_pool_client.main.id
}
output cognito_pool_id {
  value = aws_cognito_user_pool.main.id
}
output cognito_client_secret {
  sensitive = true
  value = aws_cognito_user_pool_client.main.client_secret
}
output cognito_ligoj_admin_id {
  value = local.cognito_admin_sub
}
output ligoj_admin {
  value = var.cognito_admin
}
output ligoj_admin_api_token {
  value = local.ligoj_admin_api_token
}
output ligoj_url {
  value = local.dns
}