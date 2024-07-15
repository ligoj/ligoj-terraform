resource aws_lambda_function post_confirmation {
  filename         = ".terraform/lambda_post_confirmation.zip"
  function_name    = local.lambda_post_confirmation_name
  role             = aws_iam_role.post_confirmation.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.post_confirmation.output_base64sha256
  tags             = local.tags
  runtime          = "nodejs20.x"
  timeout          = 30
  environment {
    variables = {
      SECRET_ARN          = aws_secretsmanager_secret.ligoj_lambda.arn
      API_ENDPOINT        = "https://${local.dns}${var.context_path}/rest"
      GRANT_ROLE          = var.ligoj_sign_up_role
      CREATE_PROJECT      = var.ligoj_sign_up_project
      CREATE_SUBSCRIPTION = jsonencode(var.ligoj_sign_up_subscription)
    }
  }
}

data archive_file post_confirmation {
  type        = "zip"
  output_path = ".terraform/lambda_post_confirmation.zip"
  source {
    content  = file("lambda_post_confirmation.js")
    filename = "index.js"
  }
}

resource aws_iam_role post_confirmation {
  name               = local.lambda_post_confirmation_name
  assume_role_policy = data.aws_iam_policy_document.post_confirmation.json
  tags               = local.tags
}

data aws_iam_policy_document post_confirmation {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource aws_iam_role_policy_attachment post_confirmation {
  role       = aws_iam_role.post_confirmation.name
  policy_arn = aws_iam_policy.post_confirmation.arn
}

resource aws_iam_policy post_confirmation {
  name        = local.lambda_post_confirmation_name
  path        = "/"
  description = "Ligoj Cognito post-confirmation check"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:${var.region}:*:log-group:/aws/lambda/${local.lambda_post_confirmation_name}:*",
      "Effect": "Allow"
    },{
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
          "${local.ligoj_lambda_secret_arn}"
      ]
    },{
      "Effect": "Allow",
      "Action": [
        "ec2:CreateNetworkInterface",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeNetworkInterfaces"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource aws_cloudwatch_log_group post_confirmation {
  name              = "/aws/lambda/${local.lambda_post_confirmation_name}"
  retention_in_days = var.expiration
  tags              = local.tags
}

locals {
  lambda_post_confirmation_name = "${local.name}-post_confirmation"
}

