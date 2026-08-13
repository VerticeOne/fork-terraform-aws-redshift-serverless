resource "aws_redshiftserverless_workgroup" "this" {
  namespace_name = aws_redshiftserverless_namespace.this.namespace_name
  workgroup_name = var.name

  base_capacity        = var.base_capacity
  max_capacity         = var.max_capacity
  enhanced_vpc_routing = var.enhanced_vpc_routing
  publicly_accessible  = var.publicly_accessible

  security_group_ids = [aws_security_group.this.id]
  subnet_ids         = local.subnet.ids

  config_parameter {
    parameter_key   = "auto_mv"
    parameter_value = "true"
  }

  config_parameter {
    parameter_key   = "datestyle"
    parameter_value = "ISO, MDY"
  }

  config_parameter {
    parameter_key   = "enable_case_sensitive_identifier"
    parameter_value = "false"
  }

  config_parameter {
    parameter_key   = "enable_user_activity_logging"
    parameter_value = "true"
  }

  config_parameter {
    parameter_key   = "max_query_execution_time"
    parameter_value = "14400"
  }

  config_parameter {
    parameter_key   = "query_group"
    parameter_value = "default"
  }

  config_parameter {
    parameter_key   = "require_ssl"
    parameter_value = "true"
  }

  config_parameter {
    parameter_key   = "search_path"
    parameter_value = "$user, public"
  }

  config_parameter {
    parameter_key   = "use_fips_ssl"
    parameter_value = "false"
  }

  tags = local.tags
}
