resource "aws_security_group_rule" "ingress" {
  for_each                 = { for idx, item in var.security_group_rules : idx => item }
  security_group_id        = aws_security_group.this.id
  type                     = "ingress"
  protocol                 = "tcp"
  from_port                = var.port
  to_port                  = var.port
  cidr_blocks              = (can(cidrnetmask(each.value["source"])) ? [each.value["source"]] : null)
  source_security_group_id = (can(cidrnetmask(each.value["source"])) ? null : each.value["source"])
  description              = try(each.value["description"], null)
}

resource "aws_security_group_rule" "egress" {
  security_group_id = aws_security_group.this.id
  type              = "egress"
  protocol          = "-1"
  from_port         = 0
  to_port           = 0
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow All"
}
