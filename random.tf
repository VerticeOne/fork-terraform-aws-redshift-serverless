resource "random_password" "master_password" {
  length      = 14
  special     = false
  min_upper   = 1
  min_numeric = 1
}

resource "random_id" "snapshot_identifier" {
  keepers = {
    id = var.name
  }
  byte_length = 4
}
