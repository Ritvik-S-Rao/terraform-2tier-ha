variable "private_data_subnet_ids" {
  description = "List of private data subnet IDs for the RDS database"
  type        = list(string)
}

variable "db_security_group_id" {
  description = "Security group ID for the RDS database"
  type        = string
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Master password for the database"
  type        = string
  sensitive   = true
}
