##-----------------------------------------------------------------------------
# Keepalive Lambda Function for Redshift Serverless
# Prevents the cluster from scaling to zero by executing SELECT 1 periodically
##-----------------------------------------------------------------------------

locals {
  keepalive_enabled = var.keepalive != null ? var.keepalive.enabled : false
}

##-----------------------------------------------------------------------------
# Lambda Function Code
data "archive_file" "keepalive" {
  count       = local.keepalive_enabled ? 1 : 0
  type        = "zip"
  output_path = "${path.module}/.terraform/tmp/keepalive_lambda.zip"

  source {
    content  = <<-PYTHON
import json
import boto3
import os

def handler(event, context):
    client = boto3.client('redshift-data')

    workgroup_name = os.environ['WORKGROUP_NAME']
    database = os.environ['DATABASE_NAME']

    response = client.execute_statement(
        WorkgroupName=workgroup_name,
        Database=database,
        Sql='SELECT 1'
    )

    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Keepalive query executed',
            'queryId': response['Id']
        })
    }
PYTHON
    filename = "index.py"
  }
}

##-----------------------------------------------------------------------------
# IAM Role for Lambda
resource "aws_iam_role" "keepalive" {
  count = local.keepalive_enabled ? 1 : 0

  name               = "rs-${var.name}-keepalive"
  description        = "${local.scope.name} - ${local.purpose.name} [${local.environment.name}] (${local.aws.region.name}): Redshift Keepalive Lambda - ${var.name}"
  assume_role_policy = data.aws_iam_policy_document.keepalive_assume_role[0].json
  tags               = local.tags
}

data "aws_iam_policy_document" "keepalive_assume_role" {
  count = local.keepalive_enabled ? 1 : 0

  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "keepalive" {
  count = local.keepalive_enabled ? 1 : 0

  name   = "redshift-data-api"
  role   = aws_iam_role.keepalive[0].id
  policy = data.aws_iam_policy_document.keepalive_policy[0].json
}

data "aws_iam_policy_document" "keepalive_policy" {
  count = local.keepalive_enabled ? 1 : 0

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

resource "aws_iam_role_policy_attachment" "keepalive_basic_execution" {
  count = local.keepalive_enabled ? 1 : 0

  role       = aws_iam_role.keepalive[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "keepalive_vpc_access" {
  count = local.keepalive_enabled ? 1 : 0

  role       = aws_iam_role.keepalive[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

##-----------------------------------------------------------------------------
# Lambda Function
resource "aws_lambda_function" "keepalive" {
  count = local.keepalive_enabled ? 1 : 0

  function_name    = "rs-${var.name}-keepalive"
  description      = "Keepalive function to prevent Redshift Serverless ${var.name} from scaling to zero"
  role             = aws_iam_role.keepalive[0].arn
  handler          = "index.handler"
  runtime          = "python3.12"
  timeout          = 30
  filename         = data.archive_file.keepalive[0].output_path
  source_code_hash = data.archive_file.keepalive[0].output_base64sha256

  environment {
    variables = {
      WORKGROUP_NAME = var.name
      DATABASE_NAME  = var.db_name != "" ? var.db_name : "dev"
    }
  }

  tags = local.tags
}

##-----------------------------------------------------------------------------
# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "keepalive" {
  count = local.keepalive_enabled ? 1 : 0

  name              = "/aws/lambda/rs-${var.name}-keepalive"
  retention_in_days = var.log_retention_in_days
  tags              = local.tags
}

##-----------------------------------------------------------------------------
# EventBridge Rule
resource "aws_cloudwatch_event_rule" "keepalive" {
  count = local.keepalive_enabled ? 1 : 0

  name                = "rs-${var.name}-keepalive"
  description         = "Trigger keepalive Lambda for Redshift Serverless ${var.name}"
  schedule_expression = "rate(${try(var.keepalive.schedule_interval, 1)} minute${try(var.keepalive.schedule_interval, 1) > 1 ? "s" : ""})"
  tags                = local.tags
}

resource "aws_cloudwatch_event_target" "keepalive" {
  count = local.keepalive_enabled ? 1 : 0

  rule      = aws_cloudwatch_event_rule.keepalive[0].name
  target_id = "keepalive-lambda"
  arn       = aws_lambda_function.keepalive[0].arn
}

resource "aws_lambda_permission" "keepalive" {
  count = local.keepalive_enabled ? 1 : 0

  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.keepalive[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.keepalive[0].arn
}
