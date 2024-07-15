resource "aws_lambda_function" "data_api" {
  filename         = ".terraform/lambda_data_api.zip"
  function_name    = local.lambda_data_api_name
  role             = aws_iam_role.data_api.arn
  handler          = "index.handler"
  source_code_hash = data.archive_file.data_api.output_base64sha256
  tags             = local.tags
  runtime          = "nodejs14.x"
  timeout          = 60
  memory_size      = 256
  environment {
    variables = {
      DB_HOST     = aws_rds_cluster.main[0].endpoint
      DB_DATABASE = "ligoj"
    }
  }

  vpc_config {
    subnet_ids         = aws_subnet.main.*.id
    security_group_ids = [aws_security_group.data_api.id]
  }
}

resource "aws_security_group" "data_api" {
  name        = local.lambda_data_api_name
  description = "Ligoj data API to RDS"
  vpc_id      = aws_vpc.main.id
  tags        = merge(local.tags, { Name = local.lambda_data_api_name })
}

resource "aws_security_group_rule" "data_api_to_aurora" {
  type                     = "egress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  source_security_group_id = aws_security_group.aurora.id
  security_group_id        = aws_security_group.data_api.id
}

data "archive_file" "data_api" {
  type        = "zip"
  source_dir  = "${path.module}/lambda_data_api"
  output_path = ".terraform/lambda_data_api.zip"
  excludes    = ["package-lock.json", "package.json"]
  depends_on  = [null_resource.lambda_data_api]
}

resource "null_resource" "lambda_data_api" {
  provisioner "local-exec" {
    working_dir = "${path.module}/lambda_data_api"
    command     = <<EOF
        npm install
    EOF
  }

  triggers = {
    rerun_every_time = uuid()
  }
}

resource "aws_iam_role" "data_api" {
  name               = local.lambda_data_api_name
  assume_role_policy = data.aws_iam_policy_document.data_api.json
  tags               = local.tags
}

data "aws_iam_policy_document" "data_api" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "data_api" {
  role       = aws_iam_role.data_api.name
  policy_arn = aws_iam_policy.data_api.arn
}

resource "aws_iam_policy" "data_api" {
  name        = local.lambda_data_api_name
  path        = "/"
  description = "Ligoj data API"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:${var.region}:*:log-group:/aws/lambda/${local.lambda_data_api_name}:*",
      "Effect": "Allow"
    }, {
        "Effect": "Allow",
        "Action": [
          "ec2:DescribeAvailabilityZones",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
      ],
      "Resource": [
          "*"
      ]
    }
  ]
}
EOF
}

resource "aws_cloudwatch_log_group" "data_api" {
  name              = "/aws/lambda/${local.lambda_data_api_name}"
  retention_in_days = 14
  tags              = local.tags
}

locals {
  lambda_data_api_name = "${local.name}-data_api"
}
