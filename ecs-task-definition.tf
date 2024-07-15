resource "aws_ecs_task_definition" "main" {
  family                   = var.application
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.cpu * 1024
  memory                   = var.ram
  execution_role_arn       = aws_iam_role.task.arn
  container_definitions    = <<EOF
  [
    ${templatefile("task-definition/ligoj-ui.json", merge(local.tags, local.container_definition, { context_path = var.context_path }))},
    ${templatefile("task-definition/ligoj-api.json", merge(local.tags, local.container_definition, { cpu = var.cpu * 1024, nb_cpu = var.cpu, db_tdp_arn = local.db_tdp_arn, db_user = local.db_user, db_password_arn = local.db_password_arn, db_host = local.db_host, ligoj_plugins = var.ligoj_plugins }))}
  ]
  EOF
  volume {
    name = "efs"
    efs_volume_configuration {
      file_system_id = aws_efs_file_system.main.id
      root_directory = "/"
    }
  }
}

resource "aws_iam_role" "task" {
  name               = "${local.name}-ecs-task"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
  tags               = local.tags
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "task" {
  role       = aws_iam_role.task.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "task_secret" {
  name        = "${local.name}-ecs-secret"
  description = "Ligoj ECS Task policy"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "secretsmanager:GetSecretValue"
      ],
      "Resource": [
          "${local.db_password_arn}",
          "${local.db_tdp_arn}"
      ]
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "task_secret" {
  role       = aws_iam_role.task.name
  policy_arn = aws_iam_policy.task_secret.arn
}
