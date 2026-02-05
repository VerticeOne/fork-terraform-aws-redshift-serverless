variable "base_capacity" {
  description = "Base Capacity"
  type        = number
  default     = 8
}

variable "credentials" {
  description = "Credentials"
  type        = any
  default     = null
}

variable "db_name" {
  description = "Database Name"
  type        = string
  default     = ""
}

variable "log_exports" {
  description = "Log Exports"
  type        = list(string)
  default     = ["userlog", "connectionlog", "useractivitylog"]
}

variable "log_retention_in_days" {
  description = "Log Retention In Days"
  type        = number
  default     = 365
  validation {
    condition = contains([
      0, 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2192, 2557, 2922, 3288, 3653
    ], var.log_retention_in_days)
    error_message = "Log retention must be one of the following valid values: 0 (indefinite), 1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 2192, 2557, 2922, 3288, 3653 days."
  }
}

variable "encryption" {
  description = "Encryption"
  type        = any
  default     = null
}

variable "enhanced_vpc_routing" {
  description = "Enhanced VPC Routing"
  type        = bool
  default     = true
}

variable "name" {
  description = "Name"
  type        = string
  default     = ""
}

variable "permissions" {
  description = "Permissions"
  type        = any
  default     = null
}

variable "port" {
  description = "Port"
  type        = number
  default     = 5439
}

variable "publicly_accessible" {
  description = "Publicly Accessible"
  type        = bool
  default     = false
}

variable "security_group_rules" {
  description = "Security Group Rules"
  type        = any
  default     = null
}

variable "subnet" {
  description = "Subnet Info"
  type        = any
  default     = null
  # - network_tag
  # - ids
}

variable "vpc_id" {
  description = "VPC: ID"
  type        = string
  default     = ""
  validation {
    condition     = var.vpc_id != ""
    error_message = "VPC ID not Specified."
  }
}

variable "max_capacity" {
  description = "Maximum RPU capacity for the workgroup (4-1024 RPUs)"
  type        = number
  default     = null
  validation {
    condition = var.max_capacity == null || (
      var.max_capacity == 4 ||
      (var.max_capacity >= 8 && var.max_capacity <= 512 && var.max_capacity % 8 == 0) ||
      (var.max_capacity > 512 && var.max_capacity <= 1024 && var.max_capacity % 32 == 0)
    )
    error_message = "Max capacity must be 4, or in units of 8 from 8-512, or in units of 32 from 512-1024 RPUs."
  }
}

variable "usage_limits" {
  description = "Usage limits configuration for RPU consumption"
  type = list(object({
    amount        = number
    period        = string
    usage_type    = optional(string, "serverless-compute")
    breach_action = optional(string, "log")
  }))
  default = []
  validation {
    condition = alltrue([
      for limit in var.usage_limits : contains(["daily", "weekly", "monthly"], limit.period)
    ])
    error_message = "Period must be one of: daily, weekly, monthly."
  }
  validation {
    condition = alltrue([
      for limit in var.usage_limits : contains(["serverless-compute", "cross-region-datasharing"], limit.usage_type)
    ])
    error_message = "Usage type must be one of: serverless-compute, cross-region-datasharing."
  }
  validation {
    condition = alltrue([
      for limit in var.usage_limits : contains(["log", "emit-metric", "deactivate"], limit.breach_action)
    ])
    error_message = "Breach action must be one of: log, emit-metric, deactivate."
  }
  validation {
    condition     = length(var.usage_limits) <= 4
    error_message = "Maximum of 4 usage limits can be configured."
  }
}

variable "monitoring" {
  description = "Monitoring configuration for CloudWatch dashboard, alarms, and log queries"
  type = object({
    enabled = optional(bool, true)

    sns_topic_arn = optional(string, null)

    dashboard = optional(object({
      enabled = optional(bool, true)
    }), {})

    query_definitions = optional(object({
      enabled = optional(bool, true)
    }), {})

    cost_monitoring = optional(object({
      enabled                        = optional(bool, false)
      anomaly_monitor_arn            = optional(string, null)
      anomaly_threshold_percentage   = optional(number, 25)
      anomaly_notification_frequency = optional(string, "IMMEDIATE")
    }), {})

    alarms = optional(object({
      compute_capacity_high = optional(object({
        enabled            = optional(bool, true)
        warning_threshold  = optional(number, 70)
        critical_threshold = optional(number, 90)
        evaluation_periods = optional(number, 3)
        period             = optional(number, 300)
      }), {})

      compute_seconds_high = optional(object({
        enabled            = optional(bool, true)
        warning_threshold  = optional(number, 7500)
        critical_threshold = optional(number, 10000)
        evaluation_periods = optional(number, 3)
        period             = optional(number, 300)
      }), {})

      database_connections_high = optional(object({
        enabled            = optional(bool, true)
        warning_threshold  = optional(number, 300)
        critical_threshold = optional(number, 400)
        evaluation_periods = optional(number, 2)
        period             = optional(number, 300)
      }), {})

      queries_failed = optional(object({
        enabled            = optional(bool, true)
        threshold          = optional(number, 5)
        evaluation_periods = optional(number, 1)
        period             = optional(number, 300)
      }), {})

      data_storage_high = optional(object({
        enabled            = optional(bool, true)
        warning_threshold  = optional(number, 60)
        critical_threshold = optional(number, 80)
        evaluation_periods = optional(number, 1)
        period             = optional(number, 3600)
      }), {})

      queries_queued_high = optional(object({
        enabled            = optional(bool, true)
        threshold          = optional(number, 10)
        evaluation_periods = optional(number, 2)
        period             = optional(number, 60)
      }), {})

      query_runtime_exceeded = optional(object({
        enabled            = optional(bool, true)
        threshold_seconds  = optional(number, 60)
        evaluation_periods = optional(number, 1)
        period             = optional(number, 60)
      }), {})
    }), {})
  })
  default = {}
}
