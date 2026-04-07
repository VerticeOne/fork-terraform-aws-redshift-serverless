##-----------------------------------------------------------------------------
# Query Planning Monitor Lambda Function for Redshift Serverless
# Monitors query planning times and alerts when threshold is exceeded
##-----------------------------------------------------------------------------

locals {
  query_planning_monitor_enabled = local.monitoring_enabled && try(var.monitoring.query_planning_monitor.enabled, false)
  query_planning_threshold       = try(var.monitoring.query_planning_monitor.threshold_seconds, 300)
  query_planning_interval        = try(var.monitoring.query_planning_monitor.check_interval_minutes, 5)
  query_planning_lookback        = try(var.monitoring.query_planning_monitor.lookback_minutes, 10)
}

##-----------------------------------------------------------------------------
# Lambda Function Code
data "archive_file" "query_planning_monitor" {
  count       = local.query_planning_monitor_enabled ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/.terraform/tmp/query_planning_monitor_lambda.zip"

  source {
    content  = <<-PYTHON
import boto3
import json
import os
import time
import logging

logger = logging.getLogger()
logger.setLevel(logging.INFO)

WORKGROUP = os.environ['WORKGROUP_NAME']
DATABASE = os.environ['DATABASE_NAME']
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN', '')
PLANNING_THRESHOLD_SEC = int(os.environ['PLANNING_THRESHOLD_SEC'])
LOOKBACK_MINUTES = int(os.environ['LOOKBACK_MINUTES'])
METRIC_NAMESPACE = os.environ['METRIC_NAMESPACE']

PLANNING_THRESHOLD_US = PLANNING_THRESHOLD_SEC * 1_000_000

redshift_data = boto3.client('redshift-data')
cloudwatch = boto3.client('cloudwatch')
sns = boto3.client('sns') if SNS_TOPIC_ARN else None


def handler(event, context):
    query = f"""
        SELECT
            query_id,
            user_id,
            TRIM(query_text) as query_text,
            start_time,
            end_time,
            elapsed_time,
            planning_time,
            execution_time,
            queue_time
        FROM sys_query_history
        WHERE start_time > DATEADD(minute, -{LOOKBACK_MINUTES}, GETDATE())
          AND status = 'success'
        ORDER BY planning_time DESC
        LIMIT 50
    """

    try:
        response = redshift_data.execute_statement(
            WorkgroupName=WORKGROUP,
            Database=DATABASE,
            Sql=query
        )
        statement_id = response['Id']

        result = wait_for_query(statement_id)

        max_planning_time_sec = 0
        all_records = []
        alert_records = []

        if result.get('HasResultSet', False) and result.get('ResultRows', 0) > 0:
            all_records = get_query_results(statement_id)
            if all_records:
                max_planning_time_sec = max(r['planning_time'] for r in all_records) / 1_000_000
                alert_records = [r for r in all_records if r['planning_time'] > PLANNING_THRESHOLD_US][:10]

        publish_metric(max_planning_time_sec)

        if alert_records:
            if SNS_TOPIC_ARN:
                send_alert(alert_records)
                logger.info(f"Alert sent for {len(alert_records)} queries exceeding planning threshold")
            else:
                logger.warning(
                    f"SNS topic not configured, skipping alert notification. "
                    f"Found {len(alert_records)} queries exceeding {PLANNING_THRESHOLD_SEC}s planning threshold."
                )
        else:
            logger.info(f"No queries exceeded planning time threshold. Max planning time: {max_planning_time_sec:.2f}s")

        return {
            'statusCode': 200,
            'body': json.dumps({
                'queries_found': len(alert_records),
                'threshold_seconds': PLANNING_THRESHOLD_SEC,
                'max_planning_time_seconds': max_planning_time_sec
            })
        }

    except Exception as e:
        logger.error(f"Error checking query planning times: {str(e)}")
        raise


def wait_for_query(statement_id, max_wait_seconds=30):
    start = time.time()
    while time.time() - start < max_wait_seconds:
        response = redshift_data.describe_statement(Id=statement_id)
        status = response['Status']

        if status == 'FINISHED':
            return response
        elif status in ('FAILED', 'ABORTED'):
            raise Exception(f"Query failed: {response.get('Error', 'Unknown error')}")

        time.sleep(0.5)

    raise TimeoutError(f"Query did not complete within {max_wait_seconds} seconds")


def get_query_results(statement_id):
    response = redshift_data.get_statement_result(Id=statement_id)

    columns = [col['name'] for col in response['ColumnMetadata']]
    records = []

    for row in response['Records']:
        record = {}
        for i, col in enumerate(columns):
            cell = row[i]
            if 'longValue' in cell:
                record[col] = cell['longValue']
            elif 'stringValue' in cell:
                record[col] = cell['stringValue']
            elif 'doubleValue' in cell:
                record[col] = cell['doubleValue']
            elif 'booleanValue' in cell:
                record[col] = cell['booleanValue']
            else:
                record[col] = None
        records.append(record)

    return records


def publish_metric(max_planning_time_sec):
    cloudwatch.put_metric_data(
        Namespace=METRIC_NAMESPACE,
        MetricData=[
            {
                'MetricName': 'QueryPlanningTimeMax',
                'Value': max_planning_time_sec,
                'Unit': 'Seconds',
                'Dimensions': [
                    {
                        'Name': 'Workgroup',
                        'Value': WORKGROUP
                    }
                ]
            }
        ]
    )
    logger.info(f"Published metric QueryPlanningTimeMax: {max_planning_time_sec}s")


def send_alert(records):
    message_lines = [
        f"Redshift Query Planning Alert",
        "",
        f"Workgroup: {WORKGROUP}",
        f"Database: {DATABASE}",
        f"Threshold: {PLANNING_THRESHOLD_SEC} seconds",
        f"Queries detected: {len(records)}",
        "",
        "=" * 50
    ]

    for i, record in enumerate(records, 1):
        planning_sec = record['planning_time'] / 1_000_000
        elapsed_sec = record['elapsed_time'] / 1_000_000
        query_preview = record['query_text'][:200] + '...' if len(str(record['query_text'])) > 200 else record['query_text']

        message_lines.extend([
            "",
            f"Query #{i}",
            f"  Query ID: {record['query_id']}",
            f"  User ID: {record['user_id']}",
            f"  Planning Time: {planning_sec:.2f} seconds",
            f"  Total Elapsed: {elapsed_sec:.2f} seconds",
            f"  Start Time: {record['start_time']}",
            f"  Query: {query_preview}",
        ])

    subject = f"Redshift Query Planning Alert - {WORKGROUP}"

    sns.publish(
        TopicArn=SNS_TOPIC_ARN,
        Subject=subject[:100],
        Message='\n'.join(message_lines)
    )
PYTHON
    filename = "index.py"
  }
}

##-----------------------------------------------------------------------------
# IAM Role for Lambda
resource "aws_iam_role" "query_planning_monitor" {
  count = local.query_planning_monitor_enabled ? 1 : 0

  name               = "rs-${var.name}-query-plan-monitor"
  description        = "${local.scope.name} - ${local.purpose.name} [${local.environment.name}] (${local.aws.region.name}): Redshift Query Planning Monitor - ${var.name}"
  assume_role_policy = data.aws_iam_policy_document.query_planning_monitor_assume_role[0].json
  tags               = local.tags
}

data "aws_iam_policy_document" "query_planning_monitor_assume_role" {
  count = local.query_planning_monitor_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "query_planning_monitor_redshift" {
  count = local.query_planning_monitor_enabled ? 1 : 0

  name   = "redshift-data-api"
  role   = aws_iam_role.query_planning_monitor[0].id
  policy = data.aws_iam_policy_document.query_planning_monitor_redshift[0].json
}

data "aws_iam_policy_document" "query_planning_monitor_redshift" {
  count = local.query_planning_monitor_enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "redshift-data:ExecuteStatement",
      "redshift-data:DescribeStatement",
      "redshift-data:GetStatementResult"
    ]
    resources = ["*"]
  }

  statement {
    effect = "Allow"
    actions = [
      "redshift-serverless:GetCredentials"
    ]
    resources = [aws_redshiftserverless_workgroup.this.arn]
  }
}

resource "aws_iam_role_policy" "query_planning_monitor_cloudwatch" {
  count = local.query_planning_monitor_enabled ? 1 : 0

  name   = "cloudwatch-metrics"
  role   = aws_iam_role.query_planning_monitor[0].id
  policy = data.aws_iam_policy_document.query_planning_monitor_cloudwatch[0].json
}

data "aws_iam_policy_document" "query_planning_monitor_cloudwatch" {
  count = local.query_planning_monitor_enabled ? 1 : 0

  statement {
    effect = "Allow"
    actions = [
      "cloudwatch:PutMetricData"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "cloudwatch:namespace"
      values   = ["Redshift-Serverless/${var.name}"]
    }
  }
}

resource "aws_iam_role_policy" "query_planning_monitor_sns" {
  count = local.query_planning_monitor_enabled && local.sns_topic_arn != null ? 1 : 0

  name   = "sns-publish"
  role   = aws_iam_role.query_planning_monitor[0].id
  policy = data.aws_iam_policy_document.query_planning_monitor_sns[0].json
}

data "aws_iam_policy_document" "query_planning_monitor_sns" {
  count = local.query_planning_monitor_enabled && local.sns_topic_arn != null ? 1 : 0

  statement {
    effect    = "Allow"
    actions   = ["sns:Publish"]
    resources = [local.sns_topic_arn]
  }
}

resource "aws_iam_role_policy_attachment" "query_planning_monitor_basic_execution" {
  count = local.query_planning_monitor_enabled ? 1 : 0

  role       = aws_iam_role.query_planning_monitor[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

##-----------------------------------------------------------------------------
# Lambda Function
resource "aws_lambda_function" "query_planning_monitor" {
  count = local.query_planning_monitor_enabled ? 1 : 0

  function_name    = "rs-${var.name}-query-plan-monitor"
  description      = "Query planning monitor for Redshift Serverless ${var.name}"
  role             = aws_iam_role.query_planning_monitor[0].arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256
  filename         = data.archive_file.query_planning_monitor[0].output_path
  source_code_hash = data.archive_file.query_planning_monitor[0].output_base64sha256

  environment {
    variables = {
      WORKGROUP_NAME         = var.name
      DATABASE_NAME          = var.db_name != "" ? var.db_name : "dev"
      SNS_TOPIC_ARN          = local.sns_topic_arn != null ? local.sns_topic_arn : ""
      PLANNING_THRESHOLD_SEC = tostring(local.query_planning_threshold)
      LOOKBACK_MINUTES       = tostring(local.query_planning_lookback)
      METRIC_NAMESPACE       = "Redshift-Serverless/${var.name}"
    }
  }

  tags = local.tags
}

##-----------------------------------------------------------------------------
# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "query_planning_monitor" {
  count = local.query_planning_monitor_enabled ? 1 : 0

  name              = "/aws/lambda/rs-${var.name}-query-plan-monitor"
  retention_in_days = var.log_retention_in_days
  tags              = local.tags
}

##-----------------------------------------------------------------------------
# EventBridge Rule
resource "aws_cloudwatch_event_rule" "query_planning_monitor" {
  count = local.query_planning_monitor_enabled ? 1 : 0

  name                = "rs-${var.name}-query-plan-monitor"
  description         = "Trigger query planning monitor Lambda for Redshift Serverless ${var.name}"
  schedule_expression = "rate(${local.query_planning_interval} minute${local.query_planning_interval > 1 ? "s" : ""})"
  tags                = local.tags
}

resource "aws_cloudwatch_event_target" "query_planning_monitor" {
  count = local.query_planning_monitor_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.query_planning_monitor[0].name
  target_id = "query-planning-monitor-lambda"
  arn       = aws_lambda_function.query_planning_monitor[0].arn
}

resource "aws_lambda_permission" "query_planning_monitor" {
  count = local.query_planning_monitor_enabled ? 1 : 0

  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.query_planning_monitor[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.query_planning_monitor[0].arn
}
