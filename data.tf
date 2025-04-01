data "aws_kms_key" "this" {
  count    = try(local.kms_key_id, null) != null ? 1 : 0
  key_id   = local.kms_key_id
  provider = aws.this
}

data "aws_vpc" "this" {
  id       = var.vpc_id
  provider = aws.this
}

data "aws_subnets" "this" {
  count = try(var.subnet.network_tag, null) != null ? 1 : 0
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.this.id]
  }
  filter {
    name   = "tag:Network"
    values = [try(var.subnet.network_tag, "")]
  }
  provider = aws.this
}

