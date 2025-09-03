resource "aws_redshiftserverless_namespace" "this" {
  namespace_name = var.name
  db_name        = var.db_name

  kms_key_id = try(data.aws_kms_key.this[0].arn, null)

  admin_username      = try(var.credentials.master.username, null)
  admin_user_password = local.master_password

  iam_roles            = [aws_iam_role.this.arn]
  default_iam_role_arn = aws_iam_role.this.arn

  log_exports = var.log_exports

  tags = local.tags
}
