resource "aws_redshiftserverless_workgroup" "this" {
  namespace_name = aws_redshiftserverless_namespace.this.namespace_name
  workgroup_name = var.name

  base_capacity        = var.base_capacity
  max_capacity         = var.max_capacity
  enhanced_vpc_routing = var.enhanced_vpc_routing
  publicly_accessible  = var.publicly_accessible

  security_group_ids = [aws_security_group.this.id]
  subnet_ids         = local.subnet.ids

  tags = local.tags
}
