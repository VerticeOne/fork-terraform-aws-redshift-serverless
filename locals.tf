locals {
  kms_key_id = try(var.encryption.enabled, true) ? try(var.encryption.kms_key_id, "alias/aws/redshift") : null

  subnet = {
    ids = try(var.subnet.network_tag, "") != "" ? distinct(compact(concat(tolist(data.aws_subnets.this[0].ids), try(var.subnet.ids, [])))) : var.subnet.ids
  }

  master_password = try(var.credentials.master.password, null) != null ? var.credentials.master.password : random_password.master_password.result
}
