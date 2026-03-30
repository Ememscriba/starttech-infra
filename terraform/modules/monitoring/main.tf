# Log Group for the backend application
# This is where your Go app will send its logs
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/${var.project_name}/backend"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-backend-logs"
    Environment = var.environment
  }
}

# Log Group for the frontend
resource "aws_cloudwatch_log_group" "frontend" {
  name              = "/${var.project_name}/frontend"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-frontend-logs"
    Environment = var.environment
  }
}

# Log Group for the load balancer
resource "aws_cloudwatch_log_group" "alb" {
  name              = "/${var.project_name}/alb"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-alb-logs"
    Environment = var.environment
  }
}

# Alarm — triggers when CPU is too high
# If CPU goes above 80% for 2 checks in a row, something is wrong
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU usage is above 80%"

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  tags = {
    Name        = "${var.project_name}-high-cpu-alarm"
    Environment = var.environment
  }
}

# Alarm — triggers when CPU is low
# If CPU drops below 20% we can scale down to save money
resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 20
  alarm_description   = "CPU usage is below 20%"

  dimensions = {
    AutoScalingGroupName = var.asg_name
  }

  tags = {
    Name        = "${var.project_name}-low-cpu-alarm"
    Environment = var.environment
  }
}

# Alarm — triggers when the load balancer gets too many errors
# If more than 10 requests fail in 5 minutes something is broken
resource "aws_cloudwatch_metric_alarm" "alb_errors" {
  alarm_name          = "${var.project_name}-alb-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 300
  statistic           = "Sum"
  threshold           = 10
  alarm_description   = "Too many 5XX errors from the load balancer"

  dimensions = {
    LoadBalancer = var.alb_arn
  }

  tags = {
    Name        = "${var.project_name}-alb-errors-alarm"
    Environment = var.environment
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "CPU Utilization"
          region  = "us-east-1"
          stat    = "Average"
          period  = 300
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", var.asg_name]
          ]
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          title   = "ALB Request Count"
          region  = "us-east-1"
          stat    = "Sum"
          period  = 300
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", var.alb_arn]
          ]
          view    = "timeSeries"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          title   = "ALB 5XX Errors"
          region  = "us-east-1"
          stat    = "Sum"
          period  = 300
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", var.alb_arn]
          ]
          view    = "timeSeries"
        }
      }
    ]
  })
}
