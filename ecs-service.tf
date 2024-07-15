/*
data aws_iam_role main {
  name = "AWSServiceRoleForECS"
}

resource aws_iam_service_linked_role "ecs" {
  aws_service_name = "ecs.amazonaws.com"
}
*/

resource "aws_ecs_service" "main" {
  name             = local.name
  cluster          = aws_ecs_cluster.main.id
  task_definition  = aws_ecs_task_definition.main.arn
  desired_count    = var.desired_count
  launch_type      = "FARGATE"
  platform_version = "1.4.0"
  tags             = local.tags
  network_configuration {
    security_groups  = [aws_security_group.ecs.id]
    subnets          = aws_subnet.main.*.id
    assign_public_ip = true
  }

  dynamic "load_balancer" {
    iterator = container
    for_each = keys(var.container_port)
    content {
      target_group_arn = aws_lb_target_group.main[container.key].arn
      container_name   = container.value
      container_port   = aws_lb_target_group.main[container.key].port
    }
  }
}

resource "aws_cloudwatch_log_group" "app_ui" {
  name = "/ecs/ligoj-ui-${var.environment}"
  tags = local.tags
}
resource "aws_cloudwatch_log_group" "app_api" {
  name = "/ecs/ligoj-api-${var.environment}"
  tags = local.tags
}
