variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR Range"
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "Public Subnet CIDR values"
  default     = ["10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "Private Subnet CIDR values"
  default     = ["10.0.4.0/24"]
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
  default     = ["ap-south-1a"]
}


variable "sg_peram" {
  type = list(map(string))
  default = [{
    fromport   = 80
    toport     = 80
    protocol   = "tcp"
    cidr_block = "10.0.0.0/16"
    },
    {
      fromport   = 443
      toport     = 443
      protocol   = "tcp"
      cidr_block = "10.0.0.0/16"
  }]
}

variable "configuration" {
  description = "The total configuration, List of Objects/Dictionary"
  default     = [{}]
}