variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "List of CIDR blocks for private app subnets"
  type        = list(string)
}

variable "private_data_subnet_cidrs" {
  description = "List of CIDR blocks for private database subnets"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of Availability Zones to spread resources across"
  type        = list(string)
}
