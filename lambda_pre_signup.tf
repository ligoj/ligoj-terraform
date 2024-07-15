resource aws_lambda_function pre_sign_up {
  filename         = "lambda_pre_signup.zip"
  function_name    = local.lambda_pre_sign_up_name
  role             = aws_iam_role.pre_sign_up.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.pre_sign_up.output_base64sha256
  tags             = local.tags
  runtime          = "nodejs20.x"
  environment {
    variables = {
      ACCEPTED_MAIL       = local.cognito_email_filter
      REJECT_MAIL_MESSAGE = var.cognito_email_filter_message
    }
  }
}

data archive_file pre_sign_up {
  type        = "zip"
  output_path = "lambda_pre_signup.zip"
  source {
    content  = templatefile("lambda_pre_signup.js", local.tags)
    filename = "index.js"
  }
}

resource aws_iam_role pre_sign_up {
  name               = local.lambda_pre_sign_up_name
  assume_role_policy = data.aws_iam_policy_document.pre_sign_up.json
  tags               = local.tags
}

data aws_iam_policy_document pre_sign_up {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource aws_iam_role_policy_attachment pre_sign_up {
  role       = aws_iam_role.pre_sign_up.name
  policy_arn = aws_iam_policy.pre_sign_up.arn
}

resource aws_iam_policy pre_sign_up {
  name        = local.lambda_pre_sign_up_name
  path        = "/"
  description = "Ligoj Cognito pre-auth check"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:${var.region}:*:log-group:/aws/lambda/${local.lambda_pre_sign_up_name}:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource aws_cloudwatch_log_group pre_sign_up {
  name              = "/aws/lambda/${local.lambda_pre_sign_up_name}"
  retention_in_days = 14
  tags              = local.tags
}

locals {
  lambda_pre_sign_up_name = "${local.name}-pre_sign_up"
}
