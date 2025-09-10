resource "aws_redshiftserverless_usage_limit" "this" {
  count = length(var.usage_limits)

  resource_arn    = aws_redshiftserverless_workgroup.this.arn
  usage_type      = var.usage_limits[count.index].usage_type
  amount          = var.usage_limits[count.index].amount
  period          = var.usage_limits[count.index].period
  breach_action   = var.usage_limits[count.index].breach_action

  tags = local.tags
}