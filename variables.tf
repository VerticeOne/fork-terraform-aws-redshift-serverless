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
