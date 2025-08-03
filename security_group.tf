resource "aws_security_group" "this" {
  name                   = "rs-${var.name}"
  description            = "${local.scope.name} - ${local.purpose.name} [${local.environment.name}] (${local.aws.region.name}): Redshift - ${var.name}"
  vpc_id                 = data.aws_vpc.this.id
  revoke_rules_on_delete = true
  tags = merge(
    local.tags,
    tomap({
      "Name" = "rs-${var.name}"
    })
  )
}
