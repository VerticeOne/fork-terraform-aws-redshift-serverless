resource "aws_cloudwatch_log_group" "this" {
  count = var.log_retention_in_days > 0 ? 1 : 0

  name              = "/aws/redshift/${var.name}/"
  retention_in_days = var.log_retention_in_days

  tags = local.tags
}
