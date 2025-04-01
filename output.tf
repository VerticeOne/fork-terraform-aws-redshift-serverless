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
      workgroup = try(aws_redshiftserverless_workgroup.this, null)
    }

    security_group = try(aws_security_group.this, null)
  }
}
