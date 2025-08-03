resource "aws_iam_role" "this" {
  name               = "rs-${var.name}"
  description        = "${local.scope.name} - ${local.purpose.name} [${local.environment.name}] (${local.aws.region.name}): Redshift - ${var.name}"
  assume_role_policy = data.aws_iam_policy_document.iam_role-redshift-assume_role_policy.json
  tags               = local.tags
}

data "aws_iam_policy_document" "iam_role-redshift-assume_role_policy" {
  statement {
    effect = "Allow"
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type = "Service"
      identifiers = [
        "redshift.amazonaws.com"
      ]
    }
  }
}

resource "aws_iam_role_policy_attachment" "redshift" {
  role       = aws_iam_role.this.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonRedshiftAllCommandsFullAccess"
}

resource "aws_iam_role_policy_attachment" "athena" {
  count      = try(var.permissions.athena.enabled, false) ? 1 : 0
  role       = aws_iam_role.this.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonAthenaFullAccess"
}

resource "aws_iam_role_policy_attachment" "s3_read_all" {
  count      = try(var.permissions.s3.read.all, false) ? 1 : 0
  role       = aws_iam_role.this.id
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

resource "aws_iam_role_policy" "s3_read" {
  count    = try(length(var.permissions.s3.read.bucket_arns), 0) > 0 ? 1 : 0
  name     = "S3_Access_Read"
  role     = aws_iam_role.this.id
  policy   = data.aws_iam_policy_document.iam_role_policy-redshift-s3_read[0].json
}

data "aws_iam_policy_document" "iam_role_policy-redshift-s3_read" {
  count     = try(length(var.permissions.s3.read.bucket_arns), 0) > 0 ? 1 : 0
  policy_id = "s3-access-read"
  statement {
    effect = "Allow"
    actions = [
      "s3:List*"
    ]
    resources = var.permissions.s3.read.bucket_arns
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:Get*"
    ]
    resources = formatlist("%s/*", var.permissions.s3.read.bucket_arns)
  }
}

resource "aws_iam_role_policy" "s3_write" {
  count    = try(length(var.permissions.s3.write.bucket_arns), 0) > 0 ? 1 : 0
  name     = "S3_Access_Write"
  role     = aws_iam_role.this.id
  policy   = data.aws_iam_policy_document.iam_role_policy-redshift-s3_write[0].json
}

data "aws_iam_policy_document" "iam_role_policy-redshift-s3_write" {
  count     = try(length(var.permissions.s3.write.bucket_arns), 0) > 0 ? 1 : 0
  policy_id = "s3-access-write"
  statement {
    effect = "Allow"
    actions = [
      "s3:List*"
    ]
    resources = var.permissions.s3.write.bucket_arns
  }

  statement {
    effect = "Allow"
    actions = [
      "s3:Get*",
      "s3:Put*",
      "s3:Delete*"
    ]
    resources = formatlist("%s/*", var.permissions.s3.write.bucket_arns)
  }
}
