##-----------------------------------------------------------------------------
# CloudWatch Monitoring for Redshift Serverless
# - Dashboard with metrics overview and log widget
# - Metric alarms with configurable thresholds
# - CloudWatch Logs Insights query definitions
##-----------------------------------------------------------------------------

##-----------------------------------------------------------------------------
# Locals
locals {
  monitoring_enabled        = try(var.monitoring.enabled, true)
  dashboard_enabled         = local.monitoring_enabled && try(var.monitoring.dashboard.enabled, true)
  query_definitions_enabled = local.monitoring_enabled && try(var.monitoring.query_definitions.enabled, true)
  sns_topic_arn             = try(var.monitoring.sns_topic_arn, null)
  alarm_actions             = local.sns_topic_arn != null ? [local.sns_topic_arn] : []
  ok_actions                = local.sns_topic_arn != null ? [local.sns_topic_arn] : []

  # Alarm configurations with defaults
  alarm_compute_capacity     = try(var.monitoring.alarms.compute_capacity_high, {})
  alarm_compute_seconds      = try(var.monitoring.alarms.compute_seconds_high, {})
  alarm_database_connections = try(var.monitoring.alarms.database_connections_high, {})
  alarm_queries_failed       = try(var.monitoring.alarms.queries_failed, {})
  alarm_data_storage         = try(var.monitoring.alarms.data_storage_high, {})
  alarm_queries_queued       = try(var.monitoring.alarms.queries_queued_high, {})

  # Capacity reference for percentage-based thresholds
  capacity_reference = coalesce(var.max_capacity, var.base_capacity)

  # CloudWatch metric dimensions
  workgroup_dimension = {
    Workgroup = var.name
  }
  namespace_dimension = {
    Namespace = var.name
  }
}

##-----------------------------------------------------------------------------
# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "this" {
  count = local.dashboard_enabled ? 1 : 0

  dashboard_name = "rs-${var.name}"

  dashboard_body = jsonencode({
    widgets = [
      # Row 1: Title
      {
        type   = "text"
        x      = 0
        y      = 0
        width  = 24
        height = 1
        properties = {
          markdown = "# Redshift Serverless: ${var.name}\n**Namespace:** ${var.name} | **Region:** ${data.aws_region.this.name} | **Base Capacity:** ${var.base_capacity} RPUs"
        }
      },
      # Row 2: Compute Capacity and Compute Seconds
      {
        type   = "metric"
        x      = 0
        y      = 1
        width  = 12
        height = 6
        properties = {
          title  = "Compute Capacity (RPUs)"
          region = data.aws_region.this.name
          metrics = [
            ["AWS/Redshift-Serverless", "ComputeCapacity", "Workgroup", var.name, { stat = "Average", label = "Average Capacity" }],
            ["...", { stat = "Maximum", label = "Max Capacity" }]
          ]
          period = 60
          view   = "timeSeries"
          yAxis = {
            left = {
              min   = 0
              label = "RPUs"
            }
          }
          annotations = {
            horizontal = var.max_capacity != null ? [
              {
                value = var.max_capacity
                label = "Max Capacity Limit"
                color = "#ff7f0e"
              }
            ] : []
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 1
        width  = 12
        height = 6
        properties = {
          title  = "Compute Usage (RPU-Seconds)"
          region = data.aws_region.this.name
          metrics = [
            ["AWS/Redshift-Serverless", "ComputeSeconds", "Workgroup", var.name, { stat = "Sum", label = "Total RPU-Seconds" }]
          ]
          period = 300
          view   = "timeSeries"
          yAxis = {
            left = {
              min   = 0
              label = "RPU-Seconds"
            }
          }
        }
      },
      # Row 3: Database Connections and Query Performance
      {
        type   = "metric"
        x      = 0
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "Database Connections"
          region = data.aws_region.this.name
          metrics = [
            ["AWS/Redshift-Serverless", "DatabaseConnections", "Workgroup", var.name, { stat = "Average", label = "Connections" }]
          ]
          period = 60
          view   = "timeSeries"
          yAxis = {
            left = {
              min   = 0
              label = "Connections"
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 7
        width  = 12
        height = 6
        properties = {
          title  = "Query Performance"
          region = data.aws_region.this.name
          metrics = [
            ["AWS/Redshift-Serverless", "QueriesSucceeded", "Workgroup", var.name, { stat = "Sum", label = "Succeeded", color = "#2ca02c" }],
            [".", "QueriesFailed", ".", ".", { stat = "Sum", label = "Failed", color = "#d62728" }]
          ]
          period  = 300
          view    = "timeSeries"
          stacked = false
          yAxis = {
            left = {
              min   = 0
              label = "Queries"
            }
          }
        }
      },
      # Row 4: Running/Queued Queries and Data Storage
      {
        type   = "metric"
        x      = 0
        y      = 13
        width  = 12
        height = 6
        properties = {
          title  = "Running & Queued Queries"
          region = data.aws_region.this.name
          metrics = [
            ["AWS/Redshift-Serverless", "QueriesRunning", "Workgroup", var.name, { stat = "Average", label = "Running", color = "#1f77b4" }],
            [".", "QueriesQueued", ".", ".", { stat = "Average", label = "Queued", color = "#ff7f0e" }]
          ]
          period = 60
          view   = "timeSeries"
          yAxis = {
            left = {
              min   = 0
              label = "Queries"
            }
          }
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 13
        width  = 12
        height = 6
        properties = {
          title  = "Data Storage"
          region = data.aws_region.this.name
          metrics = [
            ["AWS/Redshift-Serverless", "DataStorage", "Namespace", var.name, { stat = "Average", label = "Storage (Bytes)" }]
          ]
          period = 3600
          view   = "timeSeries"
          yAxis = {
            left = {
              min   = 0
              label = "Bytes"
            }
          }
        }
      },
      # Row 5: Recent Logs (CloudWatch Logs Insights)
      {
        type   = "log"
        x      = 0
        y      = 19
        width  = 24
        height = 8
        properties = {
          title  = "Recent Database Logs"
          region = data.aws_region.this.name
          query  = "SOURCE '/aws/redshift/${var.name}/' | fields @timestamp, @message, @logStream | filter @message like /(?i)(error|fail|denied|warning|timeout)/ | sort @timestamp desc | limit 100"
          view   = "table"
        }
      }
    ]
  })
}

##-----------------------------------------------------------------------------
# CloudWatch Metric Alarms - Compute Capacity (Warning + Critical)
resource "aws_cloudwatch_metric_alarm" "compute_capacity_warning" {
  count = local.monitoring_enabled && try(local.alarm_compute_capacity.enabled, true) ? 1 : 0

  alarm_name          = "rs-${var.name}-compute-capacity-warning"
  alarm_description   = "Warning: Redshift Serverless compute capacity for ${var.name} exceeds ${try(local.alarm_compute_capacity.warning_threshold, 70)}% of capacity limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = try(local.alarm_compute_capacity.evaluation_periods, 3)
  metric_name         = "ComputeCapacity"
  namespace           = "AWS/Redshift-Serverless"
  period              = try(local.alarm_compute_capacity.period, 300)
  statistic           = "Average"
  threshold           = local.capacity_reference * (try(local.alarm_compute_capacity.warning_threshold, 70) / 100)
  treat_missing_data  = "notBreaching"

  dimensions = local.workgroup_dimension

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "compute_capacity_critical" {
  count = local.monitoring_enabled && try(local.alarm_compute_capacity.enabled, true) ? 1 : 0

  alarm_name          = "rs-${var.name}-compute-capacity-critical"
  alarm_description   = "Critical: Redshift Serverless compute capacity for ${var.name} exceeds ${try(local.alarm_compute_capacity.critical_threshold, 90)}% of capacity limit"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = try(local.alarm_compute_capacity.evaluation_periods, 3)
  metric_name         = "ComputeCapacity"
  namespace           = "AWS/Redshift-Serverless"
  period              = try(local.alarm_compute_capacity.period, 300)
  statistic           = "Average"
  threshold           = local.capacity_reference * (try(local.alarm_compute_capacity.critical_threshold, 90) / 100)
  treat_missing_data  = "notBreaching"

  dimensions = local.workgroup_dimension

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

##-----------------------------------------------------------------------------
# CloudWatch Metric Alarms - Compute Seconds (Warning + Critical)
resource "aws_cloudwatch_metric_alarm" "compute_seconds_warning" {
  count = local.monitoring_enabled && try(local.alarm_compute_seconds.enabled, true) ? 1 : 0

  alarm_name          = "rs-${var.name}-compute-seconds-warning"
  alarm_description   = "Warning: Redshift Serverless compute usage for ${var.name} exceeds ${try(local.alarm_compute_seconds.warning_threshold, 7500)} RPU-seconds per period"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = try(local.alarm_compute_seconds.evaluation_periods, 3)
  metric_name         = "ComputeSeconds"
  namespace           = "AWS/Redshift-Serverless"
  period              = try(local.alarm_compute_seconds.period, 300)
  statistic           = "Sum"
  threshold           = try(local.alarm_compute_seconds.warning_threshold, 7500)
  treat_missing_data  = "notBreaching"

  dimensions = local.workgroup_dimension

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "compute_seconds_critical" {
  count = local.monitoring_enabled && try(local.alarm_compute_seconds.enabled, true) ? 1 : 0

  alarm_name          = "rs-${var.name}-compute-seconds-critical"
  alarm_description   = "Critical: Redshift Serverless compute usage for ${var.name} exceeds ${try(local.alarm_compute_seconds.critical_threshold, 10000)} RPU-seconds per period"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = try(local.alarm_compute_seconds.evaluation_periods, 3)
  metric_name         = "ComputeSeconds"
  namespace           = "AWS/Redshift-Serverless"
  period              = try(local.alarm_compute_seconds.period, 300)
  statistic           = "Sum"
  threshold           = try(local.alarm_compute_seconds.critical_threshold, 10000)
  treat_missing_data  = "notBreaching"

  dimensions = local.workgroup_dimension

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions

  tags = local.tags
}

##-----------------------------------------------------------------------------
# CloudWatch Metric Alarms - Database Connections (Warning + Critical)
resource "aws_cloudwatch_metric_alarm" "database_connections_warning" {
  count = local.monitoring_enabled && try(local.alarm_database_connections.enabled, true) ? 1 : 0

  alarm_name          = "rs-${var.name}-connections-warning"
  alarm_description   = "Warning: Redshift Serverless database connections for ${var.name} exceed ${try(local.alarm_database_connections.warning_threshold, 300)}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = try(local.alarm_database_connections.evaluation_periods, 2)
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/Redshift-Serverless"
  period              = try(local.alarm_database_connections.period, 300)
  statistic           = "Average"
  threshold           = try(local.alarm_database_connections.warning_threshold, 300)
  treat_missing_data  = "notBreaching"

  dimensions = local.workgroup_dimension

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "database_connections_critical" {
  count = local.monitoring_enabled && try(local.alarm_database_connections.enabled, true) ? 1 : 0

  alarm_name          = "rs-${var.name}-connections-critical"
  alarm_description   = "Critical: Redshift Serverless database connections for ${var.name} exceed ${try(local.alarm_database_connections.critical_threshold, 400)}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = try(local.alarm_database_connections.evaluation_periods, 2)
  metric_name         = "DatabaseConnections"
  namespace           = "AWS/Redshift-Serverless"
  period              = try(local.alarm_database_connections.period, 300)
  statistic           = "Average"
  threshold           = try(local.alarm_database_connections.critical_threshold, 400)
  treat_missing_data  = "notBreaching"

  dimensions = local.workgroup_dimension

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

##-----------------------------------------------------------------------------
# CloudWatch Metric Alarms - Queries Failed (Single threshold)
resource "aws_cloudwatch_metric_alarm" "queries_failed" {
  count = local.monitoring_enabled && try(local.alarm_queries_failed.enabled, true) ? 1 : 0

  alarm_name          = "rs-${var.name}-queries-failed"
  alarm_description   = "Redshift Serverless queries failed for ${var.name} exceeds ${try(local.alarm_queries_failed.threshold, 5)} per period"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = try(local.alarm_queries_failed.evaluation_periods, 1)
  metric_name         = "QueriesFailed"
  namespace           = "AWS/Redshift-Serverless"
  period              = try(local.alarm_queries_failed.period, 300)
  statistic           = "Sum"
  threshold           = try(local.alarm_queries_failed.threshold, 5)
  treat_missing_data  = "notBreaching"

  dimensions = local.workgroup_dimension

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

##-----------------------------------------------------------------------------
# CloudWatch Metric Alarms - Data Storage (Warning + Critical)
resource "aws_cloudwatch_metric_alarm" "data_storage_warning" {
  count = local.monitoring_enabled && try(local.alarm_data_storage.enabled, true) ? 1 : 0

  alarm_name          = "rs-${var.name}-storage-warning"
  alarm_description   = "Warning: Redshift Serverless data storage for ${var.name} exceeds ${try(local.alarm_data_storage.warning_threshold, 60)} GB"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = try(local.alarm_data_storage.evaluation_periods, 1)
  metric_name         = "DataStorage"
  namespace           = "AWS/Redshift-Serverless"
  period              = try(local.alarm_data_storage.period, 3600)
  statistic           = "Average"
  # Convert GB to bytes (DataStorage metric is in bytes)
  threshold          = try(local.alarm_data_storage.warning_threshold, 60) * 1024 * 1024 * 1024
  treat_missing_data = "notBreaching"

  dimensions = local.namespace_dimension

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

resource "aws_cloudwatch_metric_alarm" "data_storage_critical" {
  count = local.monitoring_enabled && try(local.alarm_data_storage.enabled, true) ? 1 : 0

  alarm_name          = "rs-${var.name}-storage-critical"
  alarm_description   = "Critical: Redshift Serverless data storage for ${var.name} exceeds ${try(local.alarm_data_storage.critical_threshold, 80)} GB"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = try(local.alarm_data_storage.evaluation_periods, 1)
  metric_name         = "DataStorage"
  namespace           = "AWS/Redshift-Serverless"
  period              = try(local.alarm_data_storage.period, 3600)
  statistic           = "Average"
  # Convert GB to bytes (DataStorage metric is in bytes)
  threshold          = try(local.alarm_data_storage.critical_threshold, 80) * 1024 * 1024 * 1024
  treat_missing_data = "notBreaching"

  dimensions = local.namespace_dimension

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

##-----------------------------------------------------------------------------
# CloudWatch Metric Alarms - Queries Queued (Single threshold)
resource "aws_cloudwatch_metric_alarm" "queries_queued" {
  count = local.monitoring_enabled && try(local.alarm_queries_queued.enabled, true) ? 1 : 0

  alarm_name          = "rs-${var.name}-queries-queued"
  alarm_description   = "Redshift Serverless queued queries for ${var.name} exceeds ${try(local.alarm_queries_queued.threshold, 10)}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = try(local.alarm_queries_queued.evaluation_periods, 2)
  metric_name         = "QueriesQueued"
  namespace           = "AWS/Redshift-Serverless"
  period              = try(local.alarm_queries_queued.period, 60)
  statistic           = "Average"
  threshold           = try(local.alarm_queries_queued.threshold, 10)
  treat_missing_data  = "notBreaching"

  dimensions = local.workgroup_dimension

  alarm_actions = local.alarm_actions
  ok_actions    = local.ok_actions
}

##-----------------------------------------------------------------------------
# CloudWatch Logs Insights Query Definitions
resource "aws_cloudwatch_query_definition" "error_logs" {
  count = local.query_definitions_enabled ? 1 : 0

  name = "Redshift-Serverless/${var.name}/Error-Logs"

  log_group_names = [
    aws_cloudwatch_log_group.this.name
  ]

  query_string = <<-EOF
    fields @timestamp, @message, @logStream
    | filter @message like /(?i)(error|exception|fail|denied|refused|timeout|critical)/
    | sort @timestamp desc
    | limit 200
  EOF
}

resource "aws_cloudwatch_query_definition" "failed_connections" {
  count = local.query_definitions_enabled ? 1 : 0

  name = "Redshift-Serverless/${var.name}/Failed-Connections"

  log_group_names = [
    aws_cloudwatch_log_group.this.name
  ]

  query_string = <<-EOF
    fields @timestamp, @message, @logStream
    | filter @logStream like /connectionlog/
    | filter @message like /(?i)(authentication failed|connection refused|access denied|invalid|rejected)/
    | sort @timestamp desc
    | limit 100
  EOF
}

resource "aws_cloudwatch_query_definition" "user_activity_summary" {
  count = local.query_definitions_enabled ? 1 : 0

  name = "Redshift-Serverless/${var.name}/User-Activity-Summary"

  log_group_names = [
    aws_cloudwatch_log_group.this.name
  ]

  query_string = <<-EOF
    fields @timestamp, @message, @logStream
    | filter @logStream like /useractivitylog/
    | parse @message /user=(?<user>\S+)/
    | stats count(*) as activity_count by user
    | sort activity_count desc
    | limit 50
  EOF
}

resource "aws_cloudwatch_query_definition" "long_running_queries" {
  count = local.query_definitions_enabled ? 1 : 0

  name = "Redshift-Serverless/${var.name}/Long-Running-Queries"

  log_group_names = [
    aws_cloudwatch_log_group.this.name
  ]

  query_string = <<-EOF
    fields @timestamp, @message, @logStream
    | filter @logStream like /useractivitylog/
    | filter @message like /(?i)(select|insert|update|delete|copy|unload)/
    | parse @message /duration[=:\s]*(?<duration_ms>\d+)/
    | filter duration_ms > 60000
    | sort duration_ms desc
    | limit 100
  EOF
}
