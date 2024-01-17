##############################################################################
# Variables File
#
# Here is where we store the default values for all the variables used in our
# Terraform code. If you create a variable with no default, the user will be
# prompted to enter it (or define it via config file or command line flags.)

variable "prefix" {
  description = "This prefix will be included in the name of most resources."
  default     = "masa"
}

variable "region" {
  description = "The region where the resources are created."
  # default     = "ap-northeast-3" # Osaka
  # default = "us-east-2" # Ohio
  default = "ap-northeast-1" # Tokyo
}

variable "vpc_name" {
  default = "masa-vpc"
}

variable "instance_type" {
  description = "Specifies the AWS instance type."
  default     = "t3.micro"
}
