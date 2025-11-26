
resource "aws_cloudwatch_log_group" "ecs_node_app" {
  name              = "/ecs/node-app"
  retention_in_days = 14
}

resource "aws_cloudwatch_dashboard" "ecs_dashboard" {
  dashboard_name = "ECS-Fargate-Monitoring"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric",
        properties = {
          metrics = [
            [ "ECS/ContainerInsights", "CpuUtilized", "ClusterName", aws_ecs_cluster.app_cluster.name ],
            [ ".", "MemoryUtilized", ".", "." ]
          ],
          view   = "timeSeries",
          stacked = false,
          region = "eu-west-1",
          title  = "ECS Cluster CPU and Memory Usage"
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "HighCPUUsage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CpuUtilized"
  namespace           = "ECS/ContainerInsights"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "ECS CPU usage too high"
  dimensions = {
    ClusterName = aws_ecs_cluster.app_cluster.name
  }
}