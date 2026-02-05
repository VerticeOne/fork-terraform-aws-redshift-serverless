output "metadata" {
  description = "Metadata"
  value = {
    details = {
      scope = {
        name    = local.scope.name
        abbr    = local.scope.abbr
        machine = local.scope.machine
      }
      purpose = {
        name    = local.purpose.name
        abbr    = local.purpose.abbr
        machine = local.purpose.machine
      }
      environment = {
        name    = local.environment.name
        abbr    = local.environment.abbr
        machine = local.environment.machine
      }
      tags = local.tags
    }

    aws = {
      account = {
        id = local.aws.account.id
      }
      region = {
        name        = local.aws.region.name
        abbr        = local.aws.region.abbr
        description = local.aws.region.description
      }
    }

    iam = {
      role = try(aws_iam_role.this, null)
    }

    redshift_serverless = {
      cloudwatch_log_group = try(aws_cloudwatch_log_group.this, null)
      namespace = {
        arn                  = try(aws_redshiftserverless_namespace.this.arn, null)
        db_name              = try(aws_redshiftserverless_namespace.this.db_name, null)
        default_iam_role_arn = try(aws_redshiftserverless_namespace.this.default_iam_role_arn, null)
        iam_roles            = try(aws_redshiftserverless_namespace.this.iam_roles, null)
        id                   = try(aws_redshiftserverless_namespace.this.id, null)
        kms_key_id           = try(aws_redshiftserverless_namespace.this.kms_key_id, null)
        log_exports          = try(aws_redshiftserverless_namespace.this.log_exports, null)
        namespace_id         = try(aws_redshiftserverless_namespace.this.namespace_id, null)
        namespace_name       = try(aws_redshiftserverless_namespace.this.namespace_name, null)
        tags                 = try(aws_redshiftserverless_namespace.this.tags, null)
      }
      workgroup    = try(aws_redshiftserverless_workgroup.this, null)
      usage_limits = try(aws_redshiftserverless_usage_limit.this, [])
    }

    security_group = try(aws_security_group.this, null)

    monitoring = {
      enabled = local.monitoring_enabled
      dashboard = {
        name = try(aws_cloudwatch_dashboard.this[0].dashboard_name, null)
        arn  = try(aws_cloudwatch_dashboard.this[0].dashboard_arn, null)
      }
      alarms = {
        compute_capacity_warning      = try(aws_cloudwatch_metric_alarm.compute_capacity_warning[0].arn, null)
        compute_capacity_critical     = try(aws_cloudwatch_metric_alarm.compute_capacity_critical[0].arn, null)
        compute_seconds_warning       = try(aws_cloudwatch_metric_alarm.compute_seconds_warning[0].arn, null)
        compute_seconds_critical      = try(aws_cloudwatch_metric_alarm.compute_seconds_critical[0].arn, null)
        database_connections_warning  = try(aws_cloudwatch_metric_alarm.database_connections_warning[0].arn, null)
        database_connections_critical = try(aws_cloudwatch_metric_alarm.database_connections_critical[0].arn, null)
        queries_failed                = try(aws_cloudwatch_metric_alarm.queries_failed[0].arn, null)
        data_storage_warning          = try(aws_cloudwatch_metric_alarm.data_storage_warning[0].arn, null)
        data_storage_critical         = try(aws_cloudwatch_metric_alarm.data_storage_critical[0].arn, null)
        queries_queued                = try(aws_cloudwatch_metric_alarm.queries_queued[0].arn, null)
        query_runtime_exceeded        = try(aws_cloudwatch_metric_alarm.query_runtime_exceeded[0].arn, null)
      }
      query_definitions = {
        error_logs           = try(aws_cloudwatch_query_definition.error_logs[0].query_definition_id, null)
        failed_connections   = try(aws_cloudwatch_query_definition.failed_connections[0].query_definition_id, null)
        user_activity        = try(aws_cloudwatch_query_definition.user_activity_summary[0].query_definition_id, null)
        long_running_queries = try(aws_cloudwatch_query_definition.long_running_queries[0].query_definition_id, null)
      }
      cost_monitoring = {
        enabled                  = local.cost_monitoring_enabled
        anomaly_monitor_arn      = try(var.monitoring.cost_monitoring.anomaly_monitor_arn, null)
        anomaly_subscription_arn = try(aws_ce_anomaly_subscription.redshift_serverless[0].arn, null)
      }
    }
  }
}
